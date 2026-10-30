import QtQuick
import QtTest

TestCase {
    name: "MainLogicTests"

    property var mainWindow: null

    // =========================================================================
    // テストライフサイクル
    // =========================================================================

    // テストスイート開始時に1度だけ実行: Main.qml のインスタンスを生成
    function initTestCase() {
        var component = Qt.createComponent("../Main.qml");
        compare(component.status, Component.Ready, "Component error: " + component.errorString());
        mainWindow = component.createObject(null, { visible: false });
        verify(mainWindow !== null, "Failed to create Main.qml instance");
    }

    // テスト終了時に1度だけ実行: インスタンスの破棄
    function cleanupTestCase() {
        if (mainWindow) {
            mainWindow.destroy();
            mainWindow = null;
        }
    }

    // 各テスト関数の実行直前に毎回実行: 図形データや選択状態をリセット
    function init() {
        if (mainWindow) {
            mainWindow.shapeModel.clear();
            mainWindow.history = [];
            mainWindow.historyIndex = -1;
            mainWindow.selectedIndex = -1;
            mainWindow.selectedIndexes = [];
            mainWindow.isSaved = true;
        }
    }

    // =========================================================================
    // 基本機能テスト（単一操作）
    // =========================================================================

    // -------------------------------------------------------------------------
    // [テスト] 初期状態の検証
    // [概要]   起動直後のデフォルトツール、図形数、保存フラグなどの初期値を確認する
    // -------------------------------------------------------------------------
    function test_initialState() {
        verify(mainWindow !== null);
        compare(mainWindow.currentTool, "rect");
        compare(mainWindow.shapeModel.count, 0);
        compare(mainWindow.isSaved, true);
    }

    // -------------------------------------------------------------------------
    // [テスト] 図形追加と履歴保存の検証
    // [概要]   図形を追加して saveState() を呼んだ際、履歴が正しく記録されるか確認する
    // -------------------------------------------------------------------------
    function test_addShapeAndSaveState() {
        // 1. 図形を追加
        mainWindow.shapeModel.append({
            type: "rect",
            color: "#ff0000",
            thickness: 5,
            x: 10,
            y: 20,
            w: 100,
            h: 50,
            textStr: "",
            filled: false,
            flipX: false,
            flipY: false
        });
        compare(mainWindow.shapeModel.count, 1);

        // 2. 状態を保存し、履歴インデックスが更新されることを確認
        mainWindow.saveState();
        compare(mainWindow.history.length, 1);
        compare(mainWindow.historyIndex, 0);
    }

    // -------------------------------------------------------------------------
    // [テスト] Undo / Redo（元に戻す・やり直し）機能の検証
    // [概要]   図形追加後の Undo で状態が戻り、Redo で復元されることを確認する
    // -------------------------------------------------------------------------
    function test_undoRedo() {
        // 1. 1つ目の図形（rect）を追加して保存
        mainWindow.shapeModel.append({
            type: "rect", color: "#ff0000", thickness: 5,
            x: 10, y: 10, w: 50, h: 50, textStr: "",
            filled: false, flipX: false, flipY: false
        });
        mainWindow.saveState();

        // 2. 2つ目の図形（circle）を追加して保存
        mainWindow.shapeModel.append({
            type: "circle", color: "#00ff00", thickness: 3,
            x: 100, y: 100, w: 40, h: 40, textStr: "",
            filled: true, flipX: false, flipY: false
        });
        mainWindow.saveState();

        compare(mainWindow.shapeModel.count, 2);
        compare(mainWindow.historyIndex, 1);

        // 3. Undo 実行 (2個 -> 1個に戻る)
        mainWindow.undoShape();
        compare(mainWindow.shapeModel.count, 1);
        compare(mainWindow.shapeModel.get(0).type, "rect");
        compare(mainWindow.historyIndex, 0);

        // 4. Redo 実行 (1個 -> 2個に復元される)
        mainWindow.redoShape();
        compare(mainWindow.shapeModel.count, 2);
        compare(mainWindow.shapeModel.get(1).type, "circle");
        compare(mainWindow.historyIndex, 1);

        // 5. 2回連続で Undo を実行して空にする
        mainWindow.undoShape();
        compare(mainWindow.shapeModel.count, 1);
        mainWindow.undoShape();
        compare(mainWindow.shapeModel.count, 0);
        compare(mainWindow.historyIndex, -1);
    }

    // -------------------------------------------------------------------------
    // [テスト] 図形複製（リピート）機能の検証
    // [概要]   選択中の図形が +10px オフセットされた位置に複製されることを確認する
    // -------------------------------------------------------------------------
    function test_repeatShape() {
        // 1. 図形を追加して選択
        mainWindow.shapeModel.append({
            type: "arrow", color: "#0000ff", thickness: 4,
            x: 50, y: 50, w: 60, h: 60, textStr: "",
            filled: false, flipX: false, flipY: false
        });
        mainWindow.saveState();
        mainWindow.selectedIndex = 0;

        // 2. 選択中の図形を複製
        mainWindow.repeatShape();
        compare(mainWindow.shapeModel.count, 2);
        compare(mainWindow.selectedIndex, 1);

        // 3. 複製された図形の座標が元の図形から +10px されていることを確認
        var cloned = mainWindow.shapeModel.get(1);
        compare(cloned.type, "arrow");
        compare(cloned.x, 60); // 50 + 10
        compare(cloned.y, 60); // 50 + 10
    }

    // -------------------------------------------------------------------------
    // [テスト] 単一図形の削除機能の検証
    // [概要]   単一選択された図形が deleteSelectedShape() で削除されることを確認する
    // -------------------------------------------------------------------------
    function test_deleteSelectedShape() {
        // 1. 図形を追加して選択
        mainWindow.shapeModel.append({
            type: "rect", color: "#ff0000", thickness: 2,
            x: 0, y: 0, w: 10, h: 10, textStr: "",
            filled: false, flipX: false, flipY: false
        });
        mainWindow.saveState();
        compare(mainWindow.shapeModel.count, 1);

        // 2. 図形を選択して削除
        mainWindow.selectedIndex = 0;
        mainWindow.deleteSelectedShape();
        compare(mainWindow.shapeModel.count, 0);
    }

    // -------------------------------------------------------------------------
    // [テスト] 図形の微小移動（Nudge）機能の検証
    // [概要]   nudgeShape(dx, dy) で指定量だけ図形の座標が移動することを確認する
    // -------------------------------------------------------------------------
    function test_nudgeShape() {
        // 1. 図形を追加して選択
        mainWindow.shapeModel.append({
            type: "rect", color: "#ff0000", thickness: 2,
            x: 20, y: 30, w: 10, h: 10, textStr: "",
            filled: false, flipX: false, flipY: false
        });
        mainWindow.saveState();
        mainWindow.selectedIndex = 0;

        // 2. 右に +5px、上に -3px 移動
        mainWindow.nudgeShape(5, -3);
        compare(mainWindow.shapeModel.get(0).x, 25);
        compare(mainWindow.shapeModel.get(0).y, 27);
    }

    // -------------------------------------------------------------------------
    // [テスト] テキスト図形の追加検証
    // [概要]   type: "text" の図形がモデルに正しく追加されることを確認する
    // -------------------------------------------------------------------------
    function test_addText() {
        mainWindow.shapeModel.append({
            type: "text", color: "#ff0000", thickness: 2,
            x: 0, y: 0, w: 10, h: 10, textStr: "",
            filled: false, flipX: false, flipY: false
        });
        mainWindow.saveState();
        compare(mainWindow.shapeModel.count, 1);
    }

    // =========================================================================
    // 複数選択機能テスト（一括操作）
    // =========================================================================

    // -------------------------------------------------------------------------
    // [テスト] 複数図形の一括マウス移動（ドラッグ）検証
    // [概要]   複数選択された図形が、マウスドラッグ移動で連動して移動することを確認する
    // -------------------------------------------------------------------------
    function test_multipleSelection_mouseDrag() {
        // 1. ウィンドウと描画領域の初期化
        mainWindow.show();
        mainWindow.requestActivate();
        tryVerify(function() { return mainWindow.active; }, 1000);
        waitForRendering(mainWindow.contentItem);

        mainWindow.currentTool = "none";

        // 2. ダミー画像を読み込んで drawArea (キャンバス) を有効化（500x500）
        mainWindow.loadImage("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='500' height='500'></svg>", true);
        tryVerify(function() { return mainWindow.drawArea.width >= 500; }, 1000);
        waitForRendering(mainWindow.drawArea);

        // 3. テスト用図形を2つ作成
        mainWindow.shapeModel.append({
            type: "rect", color: "#ff0000", thickness: 2,
            x: 50, y: 50, w: 80, h: 80, textStr: "",
            filled: true, flipX: false, flipY: false
        });
        mainWindow.shapeModel.append({
            type: "circle", color: "#00ff00", thickness: 2,
            x: 150, y: 150, w: 80, h: 80, textStr: "",
            filled: true, flipX: false, flipY: false
        });
        mainWindow.saveState();
        
        // 4. 2つの図形を選択状態にする
        mainWindow.selectedIndex = 0;
        mainWindow.selectedIndexes = [0, 1];

        // 5. ハンドルを避け、図形0の中央付近 (90, 90) を掴んで (+30px, +20px) ドラッグ
        mousePress(mainWindow.drawArea, 90, 90, Qt.LeftButton);
        mouseMove(mainWindow.drawArea, 120, 110, 50, Qt.LeftButton);
        mouseRelease(mainWindow.drawArea, 120, 110, Qt.LeftButton);

        // 6. 検証: 両方の図形が (+30px, +20px) 移動したことを確認
        // 図形0: (50 + 30, 50 + 20) -> (80, 70)
        compare(mainWindow.shapeModel.get(0).x, 80);
        compare(mainWindow.shapeModel.get(0).y, 70);

        // 図形1: (150 + 30, 150 + 20) -> (180, 170)
        compare(mainWindow.shapeModel.get(1).x, 180);
        compare(mainWindow.shapeModel.get(1).y, 170);
    }

    // -------------------------------------------------------------------------
    // [テスト] 複数図形の一括マウスリサイズ検証
    // [概要]   複数選択時にハンドルのドラッグ操作で両方のサイズが一括変更されることを確認する
    // -------------------------------------------------------------------------
    function test_multipleSelection_mouseResize() {
        // 1. ウィンドウと描画領域の初期化
        mainWindow.show();
        mainWindow.requestActivate();
        tryVerify(function() { return mainWindow.active; }, 1000);
        waitForRendering(mainWindow.contentItem);

        mainWindow.currentTool = "none";

        // 2. ダミー画像を読み込んで drawArea (キャンバス) を有効化（500x500）
        mainWindow.loadImage("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='500' height='500'></svg>", true);
        tryVerify(function() { return mainWindow.drawArea.width >= 500; }, 1000);
        waitForRendering(mainWindow.drawArea);

        // 3. テスト用図形を2つ作成 (w: 80, h: 80)
        mainWindow.shapeModel.append({
            type: "rect", color: "#ff0000", thickness: 2,
            x: 50, y: 50, w: 80, h: 80, textStr: "",
            filled: true, flipX: false, flipY: false
        });
        mainWindow.shapeModel.append({
            type: "circle", color: "#00ff00", thickness: 2,
            x: 150, y: 150, w: 80, h: 80, textStr: "",
            filled: true, flipX: false, flipY: false
        });
        mainWindow.saveState();

        // 4. 2つの図形を選択状態にする
        mainWindow.selectedIndex = 0;
        mainWindow.selectedIndexes = [0, 1];

        // 5. 左上のハンドル (50, 50) を掴んで外側 (30, 30) へドラッグ (+20px 拡大)
        mousePress(mainWindow.drawArea, 50, 50, Qt.LeftButton);
        mouseMove(mainWindow.drawArea, 30, 30, 50, Qt.LeftButton);
        mouseRelease(mainWindow.drawArea, 30, 30, Qt.LeftButton);

        // 6. 検証: 両方の図形サイズが一括で拡大 (80 -> 100) されたことを確認
        // 図形0 (80 + 20 = 100)
        compare(mainWindow.shapeModel.get(0).w, 100);
        compare(mainWindow.shapeModel.get(0).h, 100);

        // 図形1 (80 + 20 = 100)
        compare(mainWindow.shapeModel.get(1).w, 100);
        compare(mainWindow.shapeModel.get(1).h, 100);
    }

    // -------------------------------------------------------------------------
    // [テスト] 複数図形の一括削除機能の検証
    // [概要]   複数選択された図形が deleteSelectedShape() で一括削除されることを確認する
    // -------------------------------------------------------------------------
    function test_multipleSelection_Delete() {
        // 1. テスト用図形を2つ作成
        mainWindow.shapeModel.append({
            type: "rect", color: "#ff0000", thickness: 2,
            x: 50, y: 50, w: 80, h: 80, textStr: "",
            filled: true, flipX: false, flipY: false
        });
        mainWindow.shapeModel.append({
            type: "circle", color: "#00ff00", thickness: 2,
            x: 150, y: 150, w: 80, h: 80, textStr: "",
            filled: true, flipX: false, flipY: false
        });
        mainWindow.saveState();
        compare(mainWindow.shapeModel.count, 2);
        
        // 2. 2つの図形を選択状態にする
        mainWindow.selectedIndex = 0;
        mainWindow.selectedIndexes = [0, 1];

        // 3. 一括削除を実行
        mainWindow.deleteSelectedShape();

        // 4. 検証: 図形数が 0 になったことを確認
        tryVerify(function() { return mainWindow.shapeModel.count === 0; }, 1000);
    }

    // -------------------------------------------------------------------------
    // [テスト] 複数図形の一括色変更の検証
    // [概要]   複数選択された図形に対して applyColor() で一括して色が変更されることを確認する
    // -------------------------------------------------------------------------
    function test_multipleSelection_ColorChange() {
        // 1. テスト用図形を2つ作成（赤と緑）
        mainWindow.shapeModel.append({
            type: "rect", color: "#ff0000", thickness: 2,
            x: 50, y: 50, w: 80, h: 80, textStr: "",
            filled: true, flipX: false, flipY: false
        });
        mainWindow.shapeModel.append({
            type: "circle", color: "#00ff00", thickness: 2,
            x: 150, y: 150, w: 80, h: 80, textStr: "",
            filled: true, flipX: false, flipY: false
        });
        mainWindow.saveState();
        compare(mainWindow.shapeModel.count, 2);
        
        // 2. 2つの図形を選択状態にする
        mainWindow.selectedIndex = 0;
        mainWindow.selectedIndexes = [0, 1];

        // 3. 黒色 (#000000) を適用
        mainWindow.applyColor("#000000");

        // 4. 検証: 両方の図形の色が黒に更新されたことを確認
        tryVerify(function() { return mainWindow.shapeModel.get(0).color === "#000000"; }, 1000);
        tryVerify(function() { return mainWindow.shapeModel.get(1).color === "#000000"; }, 1000);
    }

    // -------------------------------------------------------------------------
    // [テスト] 複数図形の一括塗りつぶし検証
    // [概要]   複数選択された図形に対して applyFillColor() で一括して塗りつぶしが適用されることを確認する
    // -------------------------------------------------------------------------
    function test_multipleSelection_Fill() {
        // 1. テスト用図形を2つ作成（未塗りつぶし: filled = false）
        mainWindow.shapeModel.append({
            type: "rect", color: "#ff0000", thickness: 2,
            x: 50, y: 50, w: 80, h: 80, textStr: "",
            filled: false, flipX: false, flipY: false
        });
        mainWindow.shapeModel.append({
            type: "circle", color: "#00ff00", thickness: 2,
            x: 150, y: 150, w: 80, h: 80, textStr: "",
            filled: false, flipX: false, flipY: false
        });
        mainWindow.saveState();
        compare(mainWindow.shapeModel.count, 2);
        
        // 2. 2つの図形を選択状態にする
        mainWindow.selectedIndex = 0;
        mainWindow.selectedIndexes = [0, 1];

        // 3. 塗りつぶしを実行
        mainWindow.applyFillColor();

        // 4. 検証: 両方の図形が塗りつぶしON (filled = true) になったことを確認
        tryVerify(function() { return mainWindow.shapeModel.get(0).filled === true; }, 1000);
        tryVerify(function() { return mainWindow.shapeModel.get(1).filled === true; }, 1000);
    }

    // -------------------------------------------------------------------------
    // [テスト] 複数図形の一括線幅変更の検証
    // [概要]   複数選択された図形に対して applyThickness() で一括して線の太さが変更されることを確認する
    // -------------------------------------------------------------------------
    function test_multipleSelection_Thickness() {
        // 1. テスト用図形を2つ作成（太さ 2）
        mainWindow.shapeModel.append({
            type: "rect", color: "#ff0000", thickness: 2,
            x: 50, y: 50, w: 80, h: 80, textStr: "",
            filled: false, flipX: false, flipY: false
        });
        mainWindow.shapeModel.append({
            type: "circle", color: "#00ff00", thickness: 2,
            x: 150, y: 150, w: 80, h: 80, textStr: "",
            filled: false, flipX: false, flipY: false
        });
        mainWindow.saveState();
        compare(mainWindow.shapeModel.count, 2);
        
        // 2. 2つの図形を選択状態にする
        mainWindow.selectedIndex = 0;
        mainWindow.selectedIndexes = [0, 1];

        // 3. 線の太さを 10 に変更
        mainWindow.applyThickness(10);

        // 4. 検証: 両方の図形の線の太さが 10 に更新されたことを確認
        tryVerify(function() { return mainWindow.shapeModel.get(0).thickness === 10; }, 1000);
        tryVerify(function() { return mainWindow.shapeModel.get(1).thickness === 10; }, 1000);
    }
}
