#pragma once
#include <QObject>
#include <QString>
#include <QDir>

#include <QTimer>

class ClipboardHelper : public QObject
{
    Q_OBJECT
public:
    explicit ClipboardHelper(QObject *parent = nullptr);
    ~ClipboardHelper() override;

    Q_INVOKABLE bool hasImage() const;
    Q_INVOKABLE QString pasteImageToTempFile();
    Q_INVOKABLE QString generateTempFilePath();
    Q_INVOKABLE void copyImageFromTempFile(const QString &fileUrl);
    Q_INVOKABLE void watchClipboard();
    Q_INVOKABLE void unwatchClipboard();

signals:
    void clipboardChanged();
    void captureCanceled();

private slots:
    void onClipboardDataChanged();
    void checkClippingWindow();

private:
    void setupTempDirectory();
    void cleanupTempDirectory();
    
    QString m_tempDirPath;
    QTimer *m_cancelWatchTimer = nullptr;
    bool m_clippingWindowAppeared = false;
    bool m_isWatching = false;
};
