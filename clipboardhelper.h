#pragma once
#include <QObject>
#include <QString>
#include <QDir>

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

private:
    void setupTempDirectory();
    void cleanupTempDirectory();
    
    QString m_tempDirPath;
};
