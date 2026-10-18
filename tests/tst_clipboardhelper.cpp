#include <QTest>
#include <QSignalSpy>
#include <QGuiApplication>
#include <QClipboard>
#include <QImage>
#include <QFile>
#include <QUrl>
#include <QFileInfo>
#include <QColor>
#include "clipboardhelper.h"

class TestClipboardHelper : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void cleanupTestCase();
    void init();
    void cleanup();

    void testGenerateTempFilePath();
    void testPasteImageWhenClipboardEmpty();
    void testCopyAndPasteImage();
    void testWatchClipboardSignal();
};

void TestClipboardHelper::initTestCase()
{
    QVERIFY(QGuiApplication::clipboard() != nullptr);
}

void TestClipboardHelper::cleanupTestCase()
{
}

void TestClipboardHelper::init()
{
    QGuiApplication::clipboard()->clear();
    QTest::qWait(50);
}

void TestClipboardHelper::cleanup()
{
    QGuiApplication::clipboard()->clear();
    QTest::qWait(50);
}

void TestClipboardHelper::testGenerateTempFilePath()
{
    ClipboardHelper helper;
    QString path1 = helper.generateTempFilePath();
    QString path2 = helper.generateTempFilePath();

    QVERIFY(!path1.isEmpty());
    QVERIFY(!path2.isEmpty());
    QVERIFY(path1 != path2);

    QUrl url1(path1);
    QVERIFY(url1.isLocalFile());
    QVERIFY(url1.toLocalFile().endsWith(".png"));
    QVERIFY(url1.fileName().startsWith("capture_"));
}

void TestClipboardHelper::testPasteImageWhenClipboardEmpty()
{
    ClipboardHelper helper;
    QCOMPARE(helper.hasImage(), false);

    QString result = helper.pasteImageToTempFile();
    QCOMPARE(result, QString(""));
}

void TestClipboardHelper::testCopyAndPasteImage()
{
    ClipboardHelper helper;

    // 1. テスト用の画像を一時ファイルに保存
    QString tempPath = helper.generateTempFilePath();
    QUrl tempUrl(tempPath);
    QString localFile = tempUrl.toLocalFile();

    QImage sampleImg(64, 64, QImage::Format_ARGB32);
    sampleImg.fill(Qt::red);
    QVERIFY(sampleImg.save(localFile));

    // 2. copyImageFromTempFile でクリップボードにコピー
    helper.copyImageFromTempFile(tempPath);
    QTest::qWait(100);

    // 3. hasImage() が true になることを確認
    QVERIFY(helper.hasImage());

    // 4. pasteImageToTempFile() でクリップボードから画像を取得
    QString pastedUrlStr = helper.pasteImageToTempFile();
    QVERIFY(!pastedUrlStr.isEmpty());
    QUrl pastedUrl(pastedUrlStr);
    QVERIFY(pastedUrl.isLocalFile());
    QVERIFY(QFile::exists(pastedUrl.toLocalFile()));

    // 5. 保存された画像を検証
    QImage loadedImg(pastedUrl.toLocalFile());
    QCOMPARE(loadedImg.size(), sampleImg.size());
    QCOMPARE(loadedImg.pixelColor(0, 0), sampleImg.pixelColor(0, 0));
}

void TestClipboardHelper::testWatchClipboardSignal()
{
    ClipboardHelper helper;
    QSignalSpy spy(&helper, &ClipboardHelper::clipboardChanged);
    QVERIFY(spy.isValid());

    helper.watchClipboard();

    // クリップボードに画像をセット
    QImage sampleImg(32, 32, QImage::Format_ARGB32);
    sampleImg.fill(Qt::blue);
    QGuiApplication::clipboard()->setImage(sampleImg);

    // clipboardChanged シグナルの発火を待機
    QVERIFY(spy.wait(2000));
    QCOMPARE(spy.count(), 1);

    helper.unwatchClipboard();
}

QTEST_MAIN(TestClipboardHelper)
#include "tst_clipboardhelper.moc"
