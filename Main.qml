pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import Qt.labs.folderlistmodel
import QtQuick.Dialogs

Window {
    id: mainWindow
    width: 1050
    height: 600
    visible: true
    title: qsTr("Image Annotator") + (isSaved ? "" : " *")
    color: "#2b2b2b"

    property string currentTool: "rect"
    property string currentColor: "#ff0000"
    property int currentThickness: 5
    property bool isPastedImage: false
    property int selectedIndex: -1
    property var selectedIndexes: []
    property bool isSaved: true
    property alias shapeModel: shapeModel
    property alias drawArea: drawArea 
    property var clipboardHelper: null

    property var history: []
    property int historyIndex: -1
    property bool isApplyingHistory: false

    // 現在の図形一覧をUndo/Redo用の履歴に保存する
    function saveState() {
        if (isApplyingHistory) return;
        var state = [];
        for (var i = 0; i < shapeModel.count; i++) {
            var item = shapeModel.get(i);
            state.push({
                type: item.type,
                color: item.color,
                thickness: item.thickness,
                x: item.x,
                y: item.y,
                w: item.w,
                h: item.h,
                textStr: item.textStr,
                filled: item.filled === true,
                flipX: item.flipX !== undefined ? item.flipX : false,
                flipY: item.flipY !== undefined ? item.flipY : false
            });
        }
        
        // Undo後に別の編集を始めた場合は、分岐した先のRedo履歴を破棄する
        if (historyIndex < history.length - 1) {
            history = history.slice(0, historyIndex + 1);
        }
        var newHistory = history.slice();
        newHistory.push(state);
        history = newHistory;
        historyIndex = history.length - 1;
    }

    // 履歴の状態を図形モデルへ反映する
    function applyState(state) {
        isApplyingHistory = true;
        shapeModel.clear();
        for (var i = 0; i < state.length; i++) {
            shapeModel.append(state[i]);
        }
        isApplyingHistory = false;
    }

    // 選択中の図形を少しずらした位置に複製する
    function repeatShape() {
        if (selectedIndex < 0 || selectedIndex >= shapeModel.count) {
            return;
        }
        var item = shapeModel.get(selectedIndex);
        var copyShape = {
            type: item.type,
            color: item.color,
            thickness: item.thickness,
            x: item.x + 10,
            y: item.y + 10,
            w: item.w,
            h: item.h,
            textStr: item.textStr,
            filled: item.filled === true,
            flipX: item.flipX !== undefined ? item.flipX : false,
            flipY: item.flipY !== undefined ? item.flipY : false
        };
        shapeModel.append(copyShape);
        selectedIndex = shapeModel.count -1;
        isSaved = false;
        mainWindow.saveState();
    }


    // ひとつ前の図形状態へ戻す
    function undoShape() {
        if (historyIndex > 0) {
            historyIndex--;
            applyState(history[historyIndex]);
            selectedIndex = -1;
            selectedIndexes = [];
            isSaved = false;
        } else if (historyIndex === 0) {
            historyIndex = -1;
            applyState([]);
            selectedIndex = -1;
            selectedIndexes = [];
            isSaved = false;
        }
    }

    // Undoで戻した図形状態をひとつ先へ進める
    function redoShape() {
        if (historyIndex < history.length - 1) {
            historyIndex++;
            applyState(history[historyIndex]);
            selectedIndex = -1;
            isSaved = false;
        }
    }

    // 選択中の図形をモデルから削除する
    function deleteSelectedShape() {
        if (selectedIndexes.length > 1) {
            // 後ろのインデックスから削除して、未処理の選択インデックスがずれないようにする
            var indexesToDelete = selectedIndexes.slice().sort(function(a, b) {
                return b - a;
            });
            for (var i = 0; i < indexesToDelete.length; i++) {
                shapeModel.remove(indexesToDelete[i]);
            }
        } else if (selectedIndex >= 0 && selectedIndex < shapeModel.count) {
            shapeModel.remove(selectedIndex);
        }
            selectedIndex = -1;
        selectedIndexes = [];
            isSaved = false;
            mainWindow.saveState();
    }
    

    // 選択中の図形（複数選択時は全図形）を指定量だけ移動する
    function nudgeShape(dx, dy) {
        if (selectedIndexes.length > 1) {
            for (var i = 0; i < selectedIndexes.length; i++) {
                var item = shapeModel.get(selectedIndexes[i]);
                shapeModel.setProperty(selectedIndexes[i], "x", item.x + dx);
                shapeModel.setProperty(selectedIndexes[i], "y", item.y + dy);
            }
            isSaved = false;
        } else if (selectedIndex >= 0 && selectedIndex < shapeModel.count) {
            var item = shapeModel.get(selectedIndex);
            shapeModel.setProperty(selectedIndex, "x", item.x + dx);
            shapeModel.setProperty(selectedIndex, "y", item.y + dy);
            isSaved = false;
        }
    }

    FolderListModel {
        id: folderModel
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.bmp", "*.gif", "*.webp", "*.PNG", "*.JPG", "*.JPEG"]
        showDirs: false
        sortField: FolderListModel.Name
    }

    ListModel {
        id: shapeModel
    }

    MessageDialog {
        id: discardDialog
        title: "確認"
        text: "保存されていない変更が破棄されます。続行しますか？"
        buttons: MessageDialog.Yes | MessageDialog.No
        property int pendingDirection: 0
        property string pendingImageUrl: ""
        property bool pendingImageIsPasted: false
        onAccepted: {
            shapeModel.clear();
            mainWindow.history = [];
            mainWindow.historyIndex = -1;
            mainWindow.isSaved = true;
            if (pendingImageUrl !== "") {
                mainWindow.loadImage(pendingImageUrl, pendingImageIsPasted);
                pendingImageUrl = "";
                pendingImageIsPasted = false;
            } else {
                mainWindow.performSwitch(pendingDirection);
            }
        }
    }

    MessageDialog {
        id: exitDialog
        title: "確認"
        text: "保存されていない変更があります。保存せずに終了しますか？"
        buttons: MessageDialog.Yes | MessageDialog.No
        onAccepted: {
            mainWindow.isSaved = true;
            Qt.quit();
        }
        onRejected: {
            mainWindow.flags = mainWindow.flags & ~Qt.WindowStaysOnTopHint;
        }
    }

    MessageDialog {
        id: clearConfirmDialog
        title: "確認"
        text: "本当にすべての図形を削除しますか？"
        buttons: MessageDialog.Yes | MessageDialog.No
        onAccepted: {
            shapeModel.clear();
            mainWindow.selectedIndex = -1;
            mainWindow.isSaved = false;
            mainWindow.saveState();
        }
    }

    MessageDialog {
        id: helpDialog
        title: "ヘルプ"
        text: `ショートカットキー
        V: 選択ツール
        C: 円ツール
        S: 四角形ツール
        T: テキストツール
        A: 矢印ツール
        F: 選択中の円・四角形の塗りつぶしを切り替え
        R: 選択図形のリピート
        Ctrl+Z / Ctrl+Y: Undo / Redo
        Delete: 選択図形を削除
        Ctrl+S: 名前を付けて保存
        Ctrl+C / Ctrl+V: 注釈画像のコピー / 画像の貼り付け`
        buttons: MessageDialog.Close
    }

    MessageDialog {
        id: imageErrorDialog
        title: "読み込みエラー"
        text: "画像を読み込めませんでした。対応している画像ファイルかご確認ください"
        buttons: MessageDialog.Close
    }

    FileDialog {
        id: saveDialog
        title: "Save Image"
        fileMode: FileDialog.SaveFile
        nameFilters: ["Images (*.png *.jpg)"]
        onAccepted: {
            var urlStr = selectedFile.toString();
            var path = urlStr;
            if (path.startsWith("file:///")) path = path.substring(8);
            else if (path.startsWith("file://")) path = path.substring(7);

            var oldSelected = mainWindow.selectedIndex;
            var oldSelectedIndexes = mainWindow.selectedIndexes.slice();
            // 選択枠やハンドルを出力に含めず、キャプチャ完了後に選択状態を戻す
            mainWindow.selectedIndex = -1;
            mainWindow.selectedIndexes = [];
            captureArea.grabToImage(function(result) {
                if (result.saveToFile(path)) {
                    mainWindow.isSaved = true;
                }
                mainWindow.selectedIndex = oldSelected;
                mainWindow.selectedIndexes = oldSelectedIndexes;
            });
        }
    }

    // 現在時刻を初期ファイル名にして保存ダイアログを開く
    function openSaveDialog() {
        var now = new Date();
        var timestamp = now.getFullYear()
                + padDatePart(now.getMonth() + 1)
                + padDatePart(now.getDate()) + "_"
                + padDatePart(now.getHours())
                + padDatePart(now.getMinutes())
                + padDatePart(now.getSeconds());

        saveDialog.currentFile = timestamp;
        saveDialog.open();
    }

    // 日時の各要素を2桁の文字列に整える
    function padDatePart(value) {
        return value < 10 ? "0" + value : String(value);
    }

    onClosing: (close_event) => {
        if (!isSaved && shapeModel.count > 0) {
            close_event.accepted = false;

            if (mainWindow.visibility === Window.Minimized) {
                mainWindow.showNormal();
                mainWindow.raise();
                mainWindow.requestActivate();
                mainWindow.flags = mainWindow.flags | Qt.WindowStaysOnTopHint;
            }

            Qt.callLater(() => {
                exitDialog.open();
            });
        }
    }

    Shortcut { sequence: "Ctrl+S"; onActivated: mainWindow.openSaveDialog(); context: Qt.ApplicationShortcut }

    Shortcut {
        sequence: "V"
        context: Qt.ApplicationShortcut
        enabled: !drawArea.textEditorActive
        onActivated: mainWindow.currentTool = "none"
    }
    Shortcut {
        sequence: "C"
        context: Qt.ApplicationShortcut
        enabled: !drawArea.textEditorActive
        onActivated: { mainWindow.currentTool = "circle"; mainWindow.selectedIndex = -1; }
    }
    Shortcut {
        sequence: "S"
        context: Qt.ApplicationShortcut
        enabled: !drawArea.textEditorActive
        onActivated: { mainWindow.currentTool = "rect"; mainWindow.selectedIndex = -1; }
    }
    Shortcut {
        sequence: "T"
        context: Qt.ApplicationShortcut
        enabled: !drawArea.textEditorActive
        onActivated: { mainWindow.currentTool = "text"; mainWindow.selectedIndex = -1; }
    }
    Shortcut {
        sequence: "A"
        context: Qt.ApplicationShortcut
        enabled: !drawArea.textEditorActive
        onActivated: { mainWindow.currentTool = "arrow"; mainWindow.selectedIndex = -1; }
    }
    Shortcut {
        sequence: "F"
        context: Qt.ApplicationShortcut
        enabled: !drawArea.textEditorActive && mainWindow.selectedIndex >= 0 && mainWindow.selectedIndex < shapeModel.count &&
                 (shapeModel.get(mainWindow.selectedIndex).type === "rect" || shapeModel.get(mainWindow.selectedIndex).type === "circle")
        onActivated: {
            var selectedShape = shapeModel.get(mainWindow.selectedIndex);
            shapeModel.setProperty(mainWindow.selectedIndex, "filled", selectedShape.filled !== true);
            mainWindow.isSaved = false;
            mainWindow.saveState();
        }
    }

    Shortcut {
        sequence: "R"
        context: Qt.ApplicationShortcut
        enabled: !drawArea.textEditorActive
        onActivated: {
            mainWindow.repeatShape();
        }
    }

    Shortcut {
        sequences: [StandardKey.Paste]
        context: Qt.ApplicationShortcut
        onActivated: {
            if (drawArea.textEditorActive) textInput.paste();
            else mainWindow.pasteImage();
        }
    }
    Shortcut {
        sequences: [StandardKey.Copy]
        context: Qt.ApplicationShortcut
        onActivated: {
            if (drawArea.textEditorActive) textInput.copy();
            else mainWindow.copyAnnotatedImage();
        }
    }
    Shortcut {
        sequence: "Ctrl+Z"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (drawArea.textEditorActive) textInput.undo();
            else mainWindow.undoShape();
        }
    }
    Shortcut {
        sequence: "Ctrl+Y"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (drawArea.textEditorActive) textInput.redo();
            else mainWindow.redoShape();
        }
    }
    Shortcut {
        sequences: [StandardKey.Delete]
        context: Qt.ApplicationShortcut
        onActivated: {
            if (!drawArea.textEditorActive) mainWindow.deleteSelectedShape();
        }
    }

    Shortcut {
        sequence: "Esc"
        context: Qt.ApplicationShortcut
        enabled: drawArea.textEditorActive
        onActivated: {
            mainWindow.currentTool = "none"
            contentArea.forceActiveFocus();
        }
    }

    // フォルダ内の画像切り替え
    function switchImage(direction) {
        // 貼り付け画像にはフォルダ内の前後関係がないため、切り替え対象にしない
        if (isPastedImage) return;
        if (folderModel.count <= 1 || String(mainImage.source) === "") return;
        
        if (!isSaved) {
            discardDialog.pendingImageUrl = "";
            discardDialog.pendingImageIsPasted = false;
            discardDialog.pendingDirection = direction;
            discardDialog.open();
        } else {
            performSwitch(direction);
        }
    }

    // 現在画像の位置から前後の画像を読み込む
    function performSwitch(direction) {
        var urlString = String(mainImage.source);
        var currentIndex = folderModel.indexOf(urlString);
        if (currentIndex !== -1) {
            var newIndex = currentIndex + direction;
            if (newIndex < 0) newIndex = folderModel.count - 1;
            if (newIndex >= folderModel.count) newIndex = 0;
            
            loadImage(folderModel.get(newIndex, "fileUrl"), false);
        }
    }

    // 画像を読み込み、図形・履歴・選択状態を初期化する
    function loadImage(urlStr, isPasted) {
        shapeModel.clear();
        history = [];
        historyIndex = -1;
        selectedIndex = -1;
        isSaved = true;
        mainImage.source = urlStr;
        isPastedImage = isPasted;
        
        if (!isPasted) {
            var urlString = String(urlStr);
            var lastSlash = urlString.lastIndexOf("/");
            var folderPath = urlString.substring(0, lastSlash + 1);
            folderModel.folder = folderPath;
        }
    }

    // クリップボード画像を一時フォルダ経由で読み込む
    function pasteImage() {
        if (mainWindow.clipboardHelper.hasImage()) {
            var url = mainWindow.clipboardHelper.pasteImageToTempFile();
            if (url !== "") {
                if (!isSaved) {
                    discardDialog.pendingImageUrl = url;
                    discardDialog.pendingImageIsPasted = true;
                    discardDialog.open();
                } else {
                    loadImage(url, true);
                }  
            }
        }
    }

    // 選択枠を除いた画像と図形をキャプチャしてクリップボードへコピーする
    function copyAnnotatedImage() {
        if (String(mainImage.source) === "") return;
        
        // 選択枠をコピー画像に含めず、キャプチャ後に選択状態を戻す
        var oldSelectedIndex = selectedIndex;
        var oldselectedIndexes = selectedIndexes;
        selectedIndex = -1;
        selectedIndexes = [];
        
        captureArea.grabToImage(function(result) {
            var tempUrl = mainWindow.clipboardHelper.generateTempFilePath();
            if (tempUrl !== "") {
                var localPath = tempUrl.replace("file:///", "");
                result.saveToFile(localPath);
                mainWindow.clipboardHelper.copyImageFromTempFile(tempUrl);
            }
            selectedIndex = oldSelectedIndex;
            selectedIndexes = oldselectedIndexes;
        });
    }

    // クリップボード更新およびキャンセルを検知してウィンドウを再表示する
    Connections {
        target: mainWindow.clipboardHelper
        // 画面切り取り画像が届いたら、最小化していたウィンドウを再表示する
        function onClipboardChanged() {
            mainWindow.showNormal();
            mainWindow.raise();
            mainWindow.requestActivate();
        }
        // 切り取りがキャンセルされた場合も、ウィンドウを再表示する
        function onCaptureCanceled() {
            mainWindow.showNormal();
            mainWindow.raise();
            mainWindow.requestActivate();
        }
    }

    // ウィンドウを最小化後、スクリーンショットを起動し、クリップボード監視を始める
    function createNewScreenshot() {
        // ウィンドウを最小化
        mainWindow.showMinimized();
        // スクリーンショット機能の起動
        Qt.openUrlExternally("ms-screenclip:");
        // クリップボードの監視開始
        mainWindow.clipboardHelper.watchClipboard();
    }

    // 色を適用
    function applyColor(color) {
        currentColor = color;
        if (selectedIndexes.length > 1) {
            for (var i = 0; i < selectedIndexes.length; i++) {    
                shapeModel.setProperty(selectedIndexes[i], "color", color);
            }
        } else if (selectedIndex >= 0) {
            shapeModel.setProperty(selectedIndex, "color", color);
        }
        isSaved = false;
        saveState();
        if (drawArea.textEditorvisible) {
            textInput.forceActiveFocus();
        }
    }

    // 塗りつぶしを適応
    function applyFillColor() {
        if (selectedIndexes.length > 1 && (shapeModel.get(selectedIndex).type === "rect" || shapeModel.get(selectedIndex).type === "circle")) {
            for (var i = 0; i < selectedIndexes.length; i++) {    
                var selectedShapes = shapeModel.get(selectedIndexes[i]);
                shapeModel.setProperty(selectedIndexes[i], "filled", selectedShapes.filled !== true);
            }
        } else if (selectedIndex >= 0 && selectedIndex < shapeModel.count &&
                (shapeModel.get(selectedIndex).type === "rect" || shapeModel.get(selectedIndex).type === "circle")) {
            var selectedShape = shapeModel.get(selectedIndex);
            shapeModel.setProperty(selectedIndex, "filled", selectedShape.filled !== true);
        }
        isSaved = false;
        saveState();
    }

    // 線の太さを適用
    function applyThickness(thickness) {
        currentThickness = thickness;
        if (selectedIndexes.length > 1) {
            for(var i = 0; i < selectedIndexes.length; i++) {                            
                shapeModel.setProperty(selectedIndexes[i], "thickness", thickness);
            }
        } else if (selectedIndex >= 0) {
            shapeModel.setProperty(selectedIndex, "thickness", thickness);
        }
        isSaved = false;
        saveState();
    }   

    Toolbar {
        id: toolbar
        width: parent.width
        height: 60
        color: "#d0d0d0"
        z: 10
    }

    Item {
        id: contentArea
        anchors.top: toolbar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        focus: true
        property bool nudged: false

        Keys.onPressed: (event) => {
            var step = (event.modifiers & Qt.ShiftModifier) ? 10 : 1;
            if (event.key === Qt.Key_Left) {
                if (mainWindow.selectedIndex >= 0 && mainWindow.currentTool === "none") { mainWindow.nudgeShape(-step, 0); nudged = true; }
                else mainWindow.switchImage(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                if (mainWindow.selectedIndex >= 0 && mainWindow.currentTool === "none") { mainWindow.nudgeShape(step, 0); nudged = true; }
                else mainWindow.switchImage(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up) {
                if (mainWindow.selectedIndex >= 0 && mainWindow.currentTool === "none") { mainWindow.nudgeShape(0, -step); nudged = true; }
                else if (mainWindow.selectedIndex < 0) mainWindow.currentThickness = Math.min(100, mainWindow.currentThickness + 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Down) {
                if (mainWindow.selectedIndex >= 0 && mainWindow.currentTool === "none") { mainWindow.nudgeShape(0, step); nudged = true; }
                else if (mainWindow.selectedIndex < 0) mainWindow.currentThickness = Math.max(1, mainWindow.currentThickness - 1);
                event.accepted = true;
            }
        }

        Keys.onReleased: (event) => {
            if (nudged && (event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
                mainWindow.saveState();
                nudged = false;
            }
        }

        Text {
            anchors.centerIn: parent
            text: qsTr("画像をここにドラッグ＆ドロップするか、Ctrl+Vで貼り付けてください\n（左右キーでフォルダ内の画像を切り替え）")
            color: "#888888"
            font.pixelSize: 20
            horizontalAlignment: Text.AlignHCenter
            visible: String(mainImage.source) === ""
        }

        // 画像の表示領域。contentAreaの端から20pxの余白を取り、画像が収まる範囲を定める
        Item {
            id: imageContainer
            anchors.fill: parent
            anchors.margins: 20
            visible: String(mainImage.source) !== ""

            // 元画像のピクセル寸法と表示倍率を持ち、背景・画像・図形を重ねるキャプチャ領域
            Item {
                id: captureArea
                width: mainImage.sourceSize.width > 0 ? mainImage.sourceSize.width : 1
                height: mainImage.sourceSize.height > 0 ? mainImage.sourceSize.height : 1
                anchors.centerIn: parent
                scale: Math.min(imageContainer.width / width, imageContainer.height / height)

                // 画像の透明部分を市松模様で見せる背景
                Image {
                    id: checkerboard
                    anchors.fill: parent
                    fillMode: Image.Tile
                    source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32'><rect width='32' height='32' fill='%232b2b2b'/><rect width='16' height='16' fill='%23444444'/><rect x='16' y='16' width='16' height='16' fill='%23444444'/></svg>"
                }

                // 読み込んだ元画像
                Image {
                    id: mainImage
                    anchors.fill: parent
                    asynchronous: true
                    fillMode: Image.Stretch
                    smooth: true
                    mipmap: true
                    onStatusChanged: {
                        if (status === Image.Error) {
                            imageErrorDialog.open();
                            source = ""
                        }
                    }
                }

                // 図形の表示・選択・編集を行う領域
                DrawArea {
                    id: drawArea
                    anchors.fill: parent
                }
            }
        }
    }

    // 画像ファイルのドラッグ＆ドロップを受け付ける
    DropArea {
        id: dropArea
        anchors.fill: contentArea

        onEntered: (drag) => {
            if (drag.hasUrls) {
                drag.accept()
            }
        }
        
        onDropped: (drop) => {
            mainWindow.requestActivate();
            if (drop.hasUrls && drop.urls.length > 0) {
                if (!mainWindow.isSaved) {
                    discardDialog.pendingImageUrl = String(drop.urls[0]);
                    discardDialog.pendingImageIsPasted = false;
                    discardDialog.open();
                } else {
                    mainWindow.loadImage(String(drop.urls[0]), false);
                }                 
            }
        }
    }
}
