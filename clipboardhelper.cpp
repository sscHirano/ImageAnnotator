#include "clipboardhelper.h"
#include <QGuiApplication>
#include <QClipboard>
#include <QImage>
#include <QDir>
#include <QUuid>
#include <QUrl>
#include <QFileInfo>
#include <QDebug>

#ifdef Q_OS_WIN
#include <windows.h>
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
    m_tempDirPath = QDir::temp().filePath("ImageAnnotator");
    QDir dir(m_tempDirPath);
    if (!dir.exists()) {
        dir.mkpath(".");
    }
}

void ClipboardHelper::cleanupTempDirectory() {
    QDir dir(m_tempDirPath);
    if (dir.exists()) {
        dir.removeRecursively();
    }
}

bool ClipboardHelper::hasImage() const {
    return !QGuiApplication::clipboard()->image().isNull();
}

QString ClipboardHelper::generateTempFilePath() {
    QString fileName = "capture_" + QUuid::createUuid().toString(QUuid::WithoutBraces) + ".png";
    return QUrl::fromLocalFile(QDir(m_tempDirPath).filePath(fileName)).toString();
}

QString ClipboardHelper::pasteImageToTempFile() {
    QImage img = QGuiApplication::clipboard()->image();
    if (img.isNull()) return "";

    QString fileName = "paste_" + QUuid::createUuid().toString(QUuid::WithoutBraces) + ".png";
    QString filePath = QDir(m_tempDirPath).filePath(fileName);

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
    m_clippingWindowAppeared = false;

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

    QClipboard *clipboard = QGuiApplication::clipboard();
    disconnect(clipboard, &QClipboard::dataChanged, this, &ClipboardHelper::onClipboardDataChanged);
    m_cancelWatchTimer->stop();
    m_clippingWindowAppeared = false;
}

// キャンセル判定
void ClipboardHelper::checkClippingWindow() {
#ifdef Q_OS_WIN
    HWND hwnd = FindWindowW(L"XamlWindow", L"Snipping Tool オーバーレイ");

    if (hwnd != 0x0) {
        m_clippingWindowAppeared = true;
    } else {
        if (m_clippingWindowAppeared) {
            m_cancelWatchTimer->stop();
            m_clippingWindowAppeared = false;

            QTimer::singleShot(200, this, [this]() {
                if (m_isWatching) {
                    unwatchClipboard();
                    emit captureCanceled();
                }
            });
        }
    }
#endif
}
