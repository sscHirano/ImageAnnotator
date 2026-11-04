#include "clipboardhelper.h"
#include <QGuiApplication>
#include <QClipboard>
#include <QImage>
#include <QUuid>
#include <QUrl>
#include <QFileInfo>
#include <QDebug>

#ifdef Q_OS_WIN
#include <windows.h>
#include <vector>

namespace {
// EnumWindowsから呼び出され、表示中のウィンドウの所有プロセスがSnipping Toolかを調べる。
BOOL CALLBACK findSnippingToolWindow(HWND hwnd, LPARAM userData) {
    if (!IsWindowVisible(hwnd)) {
        return TRUE;
    }

    DWORD processId = 0;
    GetWindowThreadProcessId(hwnd, &processId);

    HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, processId);
    if (process == nullptr) {
        return TRUE;
    }

    std::vector<wchar_t> path(32768);

    DWORD pathLength = static_cast<DWORD>(path.size());

    // 実行ファイル名で判定し、別プロセスのウィンドウを誤検出しないようにする。
    const bool isSnippingTool =
        QueryFullProcessImageNameW(process, 0, path.data(), &pathLength) &&
        QFileInfo(QString::fromWCharArray(path.data(), pathLength))
                .fileName().compare(QStringLiteral("SnippingTool.exe"), Qt::CaseInsensitive) == 0;
    
    CloseHandle(process);

    if (isSnippingTool) {
        // 見つかった時点で列挙を止め、呼び出し元へ検出結果を返す。
        *reinterpret_cast<bool *>(userData) = true;
        return FALSE;
    }
    return TRUE;
}
}
#endif

ClipboardHelper::ClipboardHelper(QObject *parent) : QObject(parent) {
    setupTempDirectory();

    m_cancelWatchTimer = new QTimer(this);
    m_cancelWatchTimer->setInterval(150);
    connect(m_cancelWatchTimer, &QTimer::timeout, this, &ClipboardHelper::checkClippingWindow);
}

ClipboardHelper::~ClipboardHelper() {
    cleanupTempDirectory();
}

void ClipboardHelper::setupTempDirectory() {
    if (m_tempDir.isValid()) {
        // QTemporaryDirが管理するため、Helper破棄時に一時ディレクトリも削除される。
        m_tempDirPath = m_tempDir.path();
    } else {
        qWarning() << "Failed to create temporary directory.";
    }
}

void ClipboardHelper::cleanupTempDirectory() {
    m_tempDir.remove();
}

bool ClipboardHelper::hasImage() const {
    return !QGuiApplication::clipboard()->image().isNull();
}

QString ClipboardHelper::generateTempFilePath() {
    // キャプチャ出力先を先に払い出す。実ファイルは呼び出し側が保存する。
    QString fileName = "capture_" + QUuid::createUuid().toString(QUuid::WithoutBraces) + ".png";
    return QUrl::fromLocalFile(m_tempDir.filePath(fileName)).toString();
}

QString ClipboardHelper::pasteImageToTempFile() {
    QImage img = QGuiApplication::clipboard()->image();
    if (img.isNull()) return "";

    // クリップボード画像を一時ファイル化し、QMLのImage.sourceで読み込めるURLを返す。
    QString fileName = "paste_" + QUuid::createUuid().toString(QUuid::WithoutBraces) + ".png";
    QString filePath = m_tempDir.filePath(fileName);

    if (img.save(filePath)) {
        return QUrl::fromLocalFile(filePath).toString();
    }
    return "";
}

void ClipboardHelper::copyImageFromTempFile(const QString &fileUrl) {
    QUrl url(fileUrl);
    QString filePath = url.isLocalFile() ? url.toLocalFile() : fileUrl;
    QImage img(filePath);
    if (!img.isNull()) {
        QGuiApplication::clipboard()->setImage(img);
    } else {
        qWarning() << "Failed to load image from" << filePath << "to copy to clipboard.";
    }
}

// クリップボードを監視
void ClipboardHelper::watchClipboard() {
    m_isWatching = true;
    // 前回の検出状態を引き継がず、このキャプチャ操作でのウィンドウ出現を待つ。
    m_snippingToolWindowWasVisible = false;

    const QClipboard *clipboard = QGuiApplication::clipboard();
    connect(clipboard, &QClipboard::dataChanged, this, &ClipboardHelper::onClipboardDataChanged, Qt::UniqueConnection);

    m_cancelWatchTimer->start();
}

// クリップボード更新を検知
void ClipboardHelper::onClipboardDataChanged() {
    // テキストなど別形式の更新ではキャプチャ完了とみなさず、画像が届いた時だけ通知する。
    if (hasImage()) {
        unwatchClipboard();
        emit clipboardChanged();
    }
}

// クリップボード監視終了
void ClipboardHelper::unwatchClipboard() {
    if (!m_isWatching) {
        return;
    }
    m_isWatching = false;

    // 多重接続を残さないよう監視シグナルとキャンセル判定タイマーを両方停止する。
    const QClipboard *clipboard = QGuiApplication::clipboard();
    disconnect(clipboard, &QClipboard::dataChanged, this, &ClipboardHelper::onClipboardDataChanged);
    m_cancelWatchTimer->stop();
    m_snippingToolWindowWasVisible = false;
}

// キャンセル判定
void ClipboardHelper::checkClippingWindow() {
#ifdef Q_OS_WIN
    // クリップボードが変わらないまま切り取りツールが閉じた場合も、キャンセルとして検出する。
    bool isSnippingToolWindowVisible = false;
    EnumWindows(findSnippingToolWindow, reinterpret_cast<LPARAM>(&isSnippingToolWindowVisible));

    updateCaptureWindowState(isSnippingToolWindowVisible);
#endif
}

void ClipboardHelper::updateCaptureWindowState(bool isVisible) {
    if (isVisible) {
       // snippingToolウィンドウが一度表示された後に閉じた場合に限り、キャンセルとする。
       m_snippingToolWindowWasVisible = true;
    } else if (m_snippingToolWindowWasVisible) {
        m_cancelWatchTimer->stop();
        m_snippingToolWindowWasVisible = false;

        // snippingToolウィンドウが閉じた後に画像が遅れて届く場合に備え、200ms待ってからキャンセルを確定する。
        QTimer::singleShot(200, this, [this]() {
            if (m_isWatching) {
                unwatchClipboard();
                emit captureCanceled();
            }
        });
    }
}
