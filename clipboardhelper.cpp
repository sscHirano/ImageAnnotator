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
// Snipping Toolのウィンドウを検出するためのコールバック関数
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

    const bool isSnippingTool =
        QueryFullProcessImageNameW(process, 0, path.data(), &pathLength) &&
        QFileInfo(QString::fromWCharArray(path.data(), pathLength))
                .fileName().compare(QStringLiteral("SnippingTool.exe"), Qt::CaseInsensitive) == 0;
    
    CloseHandle(process);

    if (isSnippingTool) {
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
    QString fileName = "capture_" + QUuid::createUuid().toString(QUuid::WithoutBraces) + ".png";
    return QUrl::fromLocalFile(m_tempDir.filePath(fileName)).toString();
}

QString ClipboardHelper::pasteImageToTempFile() {
    QImage img = QGuiApplication::clipboard()->image();
    if (img.isNull()) return "";

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
    m_snippingToolWindowWasVisible = false;

    const QClipboard *clipboard = QGuiApplication::clipboard();
    connect(clipboard, &QClipboard::dataChanged, this, &ClipboardHelper::onClipboardDataChanged, Qt::UniqueConnection);

    m_cancelWatchTimer->start();
}

// クリップボード更新を検知
void ClipboardHelper::onClipboardDataChanged() {
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

    const QClipboard *clipboard = QGuiApplication::clipboard();
    disconnect(clipboard, &QClipboard::dataChanged, this, &ClipboardHelper::onClipboardDataChanged);
    m_cancelWatchTimer->stop();
    m_snippingToolWindowWasVisible = false;
}

// キャンセル判定
void ClipboardHelper::checkClippingWindow() {
#ifdef Q_OS_WIN
    bool isSnippingToolWindowVisible = false;
    EnumWindows(findSnippingToolWindow, reinterpret_cast<LPARAM>(&isSnippingToolWindowVisible));

    updateCaptureWindowState(isSnippingToolWindowVisible);
#endif
}

void ClipboardHelper::updateCaptureWindowState(bool isVisible) {
    if (isVisible) {
       m_snippingToolWindowWasVisible = true;
    } else if (m_snippingToolWindowWasVisible) {
        m_cancelWatchTimer->stop();
        m_snippingToolWindowWasVisible = false;

        QTimer::singleShot(200, this, [this]() {
            if (m_isWatching) {
                unwatchClipboard();
                emit captureCanceled();
            }
        });
    }
}
