import QtQuick
import QtTest

TestCase {
    name: "MainLogicTests"

    property var mainWindow: null

    function initTestCase() {
        var component = Qt.createComponent("../Main.qml");
        compare(component.status, Component.Ready, "Component error: " + component.errorString());
        mainWindow = component.createObject(null, { visible: false });
        verify(mainWindow !== null, "Failed to create Main.qml instance");
    }

    function cleanupTestCase() {
        if (mainWindow) {
            mainWindow.destroy();
            mainWindow = null;
        }
    }

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

    function test_initialState() {
        verify(mainWindow !== null);
        compare(mainWindow.currentTool, "rect");
        compare(mainWindow.shapeModel.count, 0);
        compare(mainWindow.isSaved, true);
    }

    function test_addShapeAndSaveState() {
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

        mainWindow.saveState();
        compare(mainWindow.history.length, 1);
        compare(mainWindow.historyIndex, 0);
    }

    function test_undoRedo() {
        // 1つ目の図形を追加
        mainWindow.shapeModel.append({
            type: "rect", color: "#ff0000", thickness: 5,
            x: 10, y: 10, w: 50, h: 50, textStr: "",
            filled: false, flipX: false, flipY: false
        });
        mainWindow.saveState();

        // 2つ目の図形を追加
        mainWindow.shapeModel.append({
            type: "circle", color: "#00ff00", thickness: 3,
            x: 100, y: 100, w: 40, h: 40, textStr: "",
            filled: true, flipX: false, flipY: false
        });
        mainWindow.saveState();

        compare(mainWindow.shapeModel.count, 2);
        compare(mainWindow.historyIndex, 1);

        // Undo 実行 (2個 -> 1個)
        mainWindow.undoShape();
        compare(mainWindow.shapeModel.count, 1);
        compare(mainWindow.shapeModel.get(0).type, "rect");
        compare(mainWindow.historyIndex, 0);

        // Redo 実行 (1個 -> 2個)
        mainWindow.redoShape();
        compare(mainWindow.shapeModel.count, 2);
        compare(mainWindow.shapeModel.get(1).type, "circle");
        compare(mainWindow.historyIndex, 1);

        // 2回 Undo して空にする
        mainWindow.undoShape();
        compare(mainWindow.shapeModel.count, 1);
        mainWindow.undoShape();
        compare(mainWindow.shapeModel.count, 0);
        compare(mainWindow.historyIndex, -1);
    }

    function test_repeatShape() {
        mainWindow.shapeModel.append({
            type: "arrow", color: "#0000ff", thickness: 4,
            x: 50, y: 50, w: 60, h: 60, textStr: "",
            filled: false, flipX: false, flipY: false
        });
        mainWindow.saveState();
        mainWindow.selectedIndex = 0;

        // 選択中の図形を複製
        mainWindow.repeatShape();
        compare(mainWindow.shapeModel.count, 2);
        compare(mainWindow.selectedIndex, 1);

        var cloned = mainWindow.shapeModel.get(1);
        compare(cloned.type, "arrow");
        compare(cloned.x, 60); // 元の x(50) + 10
        compare(cloned.y, 60); // 元の y(50) + 10
    }

    function test_deleteSelectedShape() {
        mainWindow.shapeModel.append({
            type: "rect", color: "#ff0000", thickness: 2,
            x: 0, y: 0, w: 10, h: 10, textStr: "",
            filled: false, flipX: false, flipY: false
        });
        mainWindow.saveState();
        compare(mainWindow.shapeModel.count, 1);

        mainWindow.selectedIndex = 0;
        mainWindow.deleteSelectedShape();
        compare(mainWindow.shapeModel.count, 0);
    }

    function test_nudgeShape() {
        mainWindow.shapeModel.append({
            type: "rect", color: "#ff0000", thickness: 2,
            x: 20, y: 30, w: 10, h: 10, textStr: "",
            filled: false, flipX: false, flipY: false
        });
        mainWindow.saveState();
        mainWindow.selectedIndex = 0;

        // 右に 5、上に 3 移動
        mainWindow.nudgeShape(5, -3);
        compare(mainWindow.shapeModel.get(0).x, 25);
        compare(mainWindow.shapeModel.get(0).y, 27);
    }

    // テキスト追加
    function test_addText() {
        mainWindow.shapeModel.append({
            type: "text", color: "#ff0000", thickness: 2,
            x: 0, y: 0, w: 10, h: 10, textStr: "",
            filled: false, flipX: false, flipY: false
        });
        mainWindow.saveState();
        compare(mainWindow.shapeModel.count, 1);
    }
}
