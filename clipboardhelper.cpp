#include "clipboardhelper.h"
#include <QGuiApplication>
#include <QClipboard>
#include <QImage>
#include <QDir>
#include <QUuid>
#include <QUrl>
#include <QFileInfo>
#include <QDebug>

ClipboardHelper::ClipboardHelper(QObject *parent) : QObject(parent) {
    setupTempDirectory();
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
