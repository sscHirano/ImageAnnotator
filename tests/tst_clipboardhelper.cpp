#include <QTest>
#include <QSignalSpy>
#include <QGuiApplication>
#include <QClipboard>
#include <QImage>
#include <QFile>
#include <QUrl>
#include <QFileInfo>
#include <QColor>
#ifdef Q_OS_WIN
#include <windows.h>
#endif

#include "clipboardhelper.h"

class TestClipboardHelper : public QObject
{
    Q_OBJECT

private slots:
    // =========================================================================
    // テストライフサイクル
    // =========================================================================
    void initTestCase();
    void cleanupTestCase();
    void init();
    void cleanup();

    // =========================================================================
    // クリップボードヘルパー機能テスト
    // =========================================================================
    void testGenerateTempFilePath();
    void testPasteImageWhenClipboardEmpty();
    void testCopyAndPasteImage();
    void testWatchClipboardSignal();
    void testCaptureCanceledSignal();
};

// -----------------------------------------------------------------------------
// [ライフサイクル] テストスイート全体の開始時に1度だけ実行
// [概要]           クリップボードインスタンスが取得可能であることを検証
// -----------------------------------------------------------------------------
void TestClipboardHelper::initTestCase()
{
    QVERIFY(QGuiApplication::clipboard() != nullptr);
}

// -----------------------------------------------------------------------------
// [ライフサイクル] テストスイート全体の終了時に1度だけ実行
// -----------------------------------------------------------------------------
void TestClipboardHelper::cleanupTestCase()
{
}

// -----------------------------------------------------------------------------
// [ライフサイクル] 各テストケースの実行直前に毎回実行
// [概要]           テスト間の影響を防ぐため、クリップボードの内容をクリア
// -----------------------------------------------------------------------------
void TestClipboardHelper::init()
{
    QGuiApplication::clipboard()->clear();
    QTest::qWait(50);
}

// -----------------------------------------------------------------------------
// [ライフサイクル] 各テストケースの実行直後に毎回実行
// [概要]           テストで使用したクリップボードの内容をクリア
// -----------------------------------------------------------------------------
void TestClipboardHelper::cleanup()
{
    QGuiApplication::clipboard()->clear();
    QTest::qWait(50);
}

// -----------------------------------------------------------------------------
// [テスト] 一時ファイルパス生成の検証
// [概要]   generateTempFilePath() が有効かつ一意なファイルURLを生成することを確認する
// -----------------------------------------------------------------------------
void TestClipboardHelper::testGenerateTempFilePath()
{
    ClipboardHelper helper;

    // 1. パスを2回連続で生成
    QString path1 = helper.generateTempFilePath();
    QString path2 = helper.generateTempFilePath();

    // 2. 空文字でなく、それぞれ固有のUUIDが付与され異なるパスであることを確認
    QVERIFY(!path1.isEmpty());
    QVERIFY(!path2.isEmpty());
    QVERIFY(path1 != path2);

    // 3. ローカルファイルURL形式（capture_*.png）であることを確認
    QUrl url1(path1);
    QVERIFY(url1.isLocalFile());
    QVERIFY(url1.toLocalFile().endsWith(".png"));
    QVERIFY(url1.fileName().startsWith("capture_"));
}

// -----------------------------------------------------------------------------
// [テスト] クリップボードが空の場合の貼り付け処理検証
// [概要]   画像が存在しないときに hasImage() が false、paste が空文字を返すことを確認する
// -----------------------------------------------------------------------------
void TestClipboardHelper::testPasteImageWhenClipboardEmpty()
{
    ClipboardHelper helper;

    // 1. クリップボードが空のとき、hasImage() が false を返すことを確認
    QCOMPARE(helper.hasImage(), false);

    // 2. 画像がない状態で pasteImageToTempFile() を呼ぶと空文字が返ることを確認
    QString result = helper.pasteImageToTempFile();
    QCOMPARE(result, QString(""));
}

// -----------------------------------------------------------------------------
// [テスト] 画像のコピーおよび貼り付け（ファイル保存）の検証
// [概要]   一時ファイルからのクリップボードコピーと、クリップボードからの画像復元を確認する
// -----------------------------------------------------------------------------
void TestClipboardHelper::testCopyAndPasteImage()
{
    ClipboardHelper helper;

    // 1. テスト用の画像（64x64, 赤色）を作成し一時ファイルに保存
    QString tempPath = helper.generateTempFilePath();
    QUrl tempUrl(tempPath);
    QString localFile = tempUrl.toLocalFile();

    QImage sampleImg(64, 64, QImage::Format_ARGB32);
    sampleImg.fill(Qt::red);
    QVERIFY(sampleImg.save(localFile));

    // 2. copyImageFromTempFile でファイルからクリップボードへ画像をコピー
    helper.copyImageFromTempFile(tempPath);
    QTest::qWait(100);

    // 3. hasImage() が true になることを確認
    QVERIFY(helper.hasImage());

    // 4. pasteImageToTempFile() でクリップボードから画像を取得・ファイル保存
    QString pastedUrlStr = helper.pasteImageToTempFile();
    QVERIFY(!pastedUrlStr.isEmpty());
    QUrl pastedUrl(pastedUrlStr);
    QVERIFY(pastedUrl.isLocalFile());
    QVERIFY(QFile::exists(pastedUrl.toLocalFile()));

    // 5. 保存された画像の内容（サイズ、ピクセル色）が元の画像と完全一致することを検証
    QImage loadedImg(pastedUrl.toLocalFile());
    QCOMPARE(loadedImg.size(), sampleImg.size());
    QCOMPARE(loadedImg.pixelColor(0, 0), sampleImg.pixelColor(0, 0));
}

// -----------------------------------------------------------------------------
// [テスト] クリップボード監視シグナル（clipboardChanged）の検証
// [概要]   watchClipboard() 実行中に画像がコピーされた際、正しくシグナルが発火することを確認する
// -----------------------------------------------------------------------------
void TestClipboardHelper::testWatchClipboardSignal()
{
    ClipboardHelper helper;

    // 1. clipboardChanged シグナルを監視するスパイを設定
    QSignalSpy spy(&helper, &ClipboardHelper::clipboardChanged);
    QVERIFY(spy.isValid());

    // 2. クリップボードの監視を開始
    helper.watchClipboard();

    // 3. クリップボードに画像をセット（キャプチャ完了をシミュレート）
    QImage sampleImg(32, 32, QImage::Format_ARGB32);
    sampleImg.fill(Qt::blue);
    QGuiApplication::clipboard()->setImage(sampleImg);

    // 4. clipboardChanged シグナルが 1 回発火したことを検証
    QVERIFY(spy.wait(2000));
    QCOMPARE(spy.count(), 1);

    // 5. 監視を終了
    helper.unwatchClipboard();
}

// -----------------------------------------------------------------------------
// [テスト] クリップボードキャンセルシグナル（captureCanceled）の検証
// [概要]   Snipping Tool オーバーレイが出現後、キャンセル（消滅）した際に
//          captureCanceled シグナルが発火することを確認する
// -----------------------------------------------------------------------------
void TestClipboardHelper::testCaptureCanceledSignal()
{
#ifdef Q_OS_WIN
    ClipboardHelper helper;
    // 1. captureCanceled シグナルを監視するスパイを設定
    QSignalSpy spy(&helper, &ClipboardHelper::captureCanceled);
    QVERIFY(spy.isValid());

    // 2. ダミーの「Snipping Tool オーバーレイ」ウィンドウクラスを登録
    WNDCLASSW wc = {};
    wc.lpfnWndProc = DefWindowProcW;
    wc.hInstance = GetModuleHandle(nullptr);
    wc.lpszClassName = L"XamlWindow";
    RegisterClassW(&wc); // 既に登録されている場合は無視される

    // 3. クリップボード監視を開始
    helper.watchClipboard();

    // 4. Snipping Tool オーバーレイが出現した状態をシミュレート（ウィンドウ生成）
    HWND hwnd = CreateWindowExW(
        0,
        L"XamlWindow",
        L"Snipping Tool オーバーレイ",
        WS_POPUP,
        0, 0, 100, 100,
        nullptr, nullptr, GetModuleHandle(nullptr), nullptr
    );
    QVERIFY(hwnd != nullptr);

    // 監視タイマー（150ms間隔）が「出現 (m_clippingWindowAppeared = true)」を検知するまで待機
    QTest::qWait(250);

    // 5. ウィンドウを破棄（ユーザーが Esc 等でオーバーレイを閉じた状態をシミュレート）
    DestroyWindow(hwnd);

    // 6. 消滅検知タイマー(150ms) + 内部遅延(200ms) の後、captureCanceled が発火することを検証
    QVERIFY(spy.wait(2000));
    QCOMPARE(spy.count(), 1);

    // 7. 監視を終了
    helper.unwatchClipboard();
#else
    QSKIP("This test is only supported on Windows.");
#endif
}

QTEST_MAIN(TestClipboardHelper)
#include "tst_clipboardhelper.moc"
