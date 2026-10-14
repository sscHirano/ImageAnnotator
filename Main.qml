import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
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

    property var history: []
    property int historyIndex: -1
    property bool isApplyingHistory: false

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
        
        if (historyIndex < history.length - 1) {
            history = history.slice(0, historyIndex + 1);
        }
        var newHistory = history.slice();
        newHistory.push(state);
        history = newHistory;
        historyIndex = history.length - 1;
    }

    function applyState(state) {
        isApplyingHistory = true;
        shapeModel.clear();
        for (var i = 0; i < state.length; i++) {
            shapeModel.append(state[i]);
        }
        isApplyingHistory = false;
    }

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
        saveState();
    }


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

    function redoShape() {
        if (historyIndex < history.length - 1) {
            historyIndex++;
            applyState(history[historyIndex]);
            selectedIndex = -1;
            isSaved = false;
        }
    }

    function deleteSelectedShape() {
        if (selectedIndexes.length > 1) {
            var indexesToDelete = selectedIndexes.slice().sort(function(a, b) {
                return b - a;
            });
            console.log("indexesToDelete:", JSON.stringify(indexesToDelete));
            for (var i = 0; i < indexesToDelete.length; i++) {
                shapeModel.remove(indexesToDelete[i]);
            }
        } else if (selectedIndex >= 0 && selectedIndex < shapeModel.count) {
            shapeModel.remove(selectedIndex);
        }
            selectedIndex = -1;
        selectedIndexes = [];
            isSaved = false;
            saveState();
    }
    

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
            history = [];
            historyIndex = -1;
            isSaved = true;
            if (pendingImageUrl !== "") {
                loadImage(pendingImageUrl, pendingImageIsPasted);
                pendingImageUrl = "";
                pendingImageIsPasted = false;
            } else {
                performSwitch(pendingDirection);
            }
        }
    }

    MessageDialog {
        id: exitDialog
        title: "確認"
        text: "保存されていない変更があります。保存せずに終了しますか？"
        buttons: MessageDialog.Yes | MessageDialog.No
        onAccepted: {
            isSaved = true;
            Qt.quit();
        }
    }

    MessageDialog {
        id: clearConfirmDialog
        title: "確認"
        text: "本当にすべての図形を削除しますか？"
        buttons: MessageDialog.Yes | MessageDialog.No
        onAccepted: {
            shapeModel.clear();
            selectedIndex = -1;
            isSaved = false;
            saveState();
        }
    }

    MessageDialog {
        id: helpDialog
        title: "ヘルプ"
        text: "ショートカットキー
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
        Ctrl+C / Ctrl+V: 注釈画像のコピー / 画像の貼り付け"
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

            var oldSelected = selectedIndex;
            selectedIndex = -1;
            captureArea.grabToImage(function(result) {
                result.saveToFile(path);
                selectedIndex = oldSelected;
                isSaved = true;
            });
        }
    }

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

    function padDatePart(value) {
        return value < 10 ? "0" + value : String(value);
    }

    onClosing: (close_event) => {
        if (!isSaved && shapeModel.count > 0) {
            close_event.accepted = false;
            exitDialog.open();
        }
    }

    Shortcut { sequence: "Ctrl+S"; onActivated: openSaveDialog(); context: Qt.ApplicationShortcut }

    Shortcut {
        sequence: "V"
        context: Qt.ApplicationShortcut
        enabled: !textInput.activeFocus
        onActivated: currentTool = "none"
    }
    Shortcut {
        sequence: "C"
        context: Qt.ApplicationShortcut
        enabled: !textInput.activeFocus
        onActivated: { currentTool = "circle"; selectedIndex = -1; }
    }
    Shortcut {
        sequence: "S"
        context: Qt.ApplicationShortcut
        enabled: !textInput.activeFocus
        onActivated: { currentTool = "rect"; selectedIndex = -1; }
    }
    Shortcut {
        sequence: "T"
        context: Qt.ApplicationShortcut
        enabled: !textInput.activeFocus
        onActivated: { currentTool = "text"; selectedIndex = -1; }
    }
    Shortcut {
        sequence: "A"
        context: Qt.ApplicationShortcut
        enabled: !textInput.activeFocus
        onActivated: { currentTool = "arrow"; selectedIndex = -1; }
    }
    Shortcut {
        sequence: "F"
        context: Qt.ApplicationShortcut
        enabled: !textInput.activeFocus && selectedIndex >= 0 && selectedIndex < shapeModel.count &&
                 (shapeModel.get(selectedIndex).type === "rect" || shapeModel.get(selectedIndex).type === "circle")
        onActivated: {
            var selectedShape = shapeModel.get(selectedIndex);
            shapeModel.setProperty(selectedIndex, "filled", selectedShape.filled !== true);
            isSaved = false;
            saveState();
        }
    }

    Shortcut {
        sequence: "R"
        context: Qt.ApplicationShortcut
        enabled: !textInput.activeFocus
        onActivated: {
            repeatShape();
        }
    }

    Shortcut {
        sequences: [StandardKey.Paste]
        context: Qt.ApplicationShortcut
        onActivated: {
            if (textInput.activeFocus) textInput.paste();
            else pasteImage();
        }
    }
    Shortcut {
        sequences: [StandardKey.Copy]
        context: Qt.ApplicationShortcut
        onActivated: {
            if (textInput.activeFocus) textInput.copy();
            else copyAnnotatedImage();
        }
    }
    Shortcut {
        sequence: "Ctrl+Z"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (textInput.activeFocus) textInput.undo();
            else undoShape();
        }
    }
    Shortcut {
        sequence: "Ctrl+Y"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (textInput.activeFocus) textInput.redo();
            else redoShape();
        }
    }
    Shortcut {
        sequences: [StandardKey.Delete]
        context: Qt.ApplicationShortcut
        onActivated: {
            if (!textInput.activeFocus) deleteSelectedShape();
        }
    }

    function switchImage(direction) {
        if (isPastedImage) return;
        if (folderModel.count <= 1 || mainImage.source == "") return;
        
        if (!isSaved) {
            discardDialog.pendingImageUrl = "";
            discardDialog.pendingImageIsPasted = false;
            discardDialog.pendingDirection = direction;
            discardDialog.open();
        } else {
            performSwitch(direction);
        }
    }

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

    function pasteImage() {
        if (ClipboardHelper.hasImage()) {
            var url = ClipboardHelper.pasteImageToTempFile();
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

    function copyAnnotatedImage() {
        if (mainImage.source == "") return;
        
        var oldSelected = selectedIndex;
        selectedIndex = -1;
        
        captureArea.grabToImage(function(result) {
            var tempUrl = ClipboardHelper.generateTempFilePath();
            if (tempUrl !== "") {
                var localPath = tempUrl.replace("file:///", "");
                result.saveToFile(localPath);
                ClipboardHelper.copyImageFromTempFile(tempUrl);
            }
            selectedIndex = oldSelected;
        });
    }

    // クリップボード更新およびキャンセルを検知してウィンドウを再表示する
    Connections {
        target: ClipboardHelper
        function onClipboardChanged() {
            mainWindow.showNormal();
            mainWindow.raise();
            mainWindow.requestActivate();
        }
        function onCaptureCanceled() {
            mainWindow.showNormal();
            mainWindow.raise();
            mainWindow.requestActivate();
        }
    }

    function createNewScreenshot() {
        // ウィンドウを最小化
        mainWindow.showMinimized();
        // スクリーンショット機能の起動
        Qt.openUrlExternally("ms-screenclip:");
        // クリップボードの監視開始
        ClipboardHelper.watchClipboard();
    }

    Rectangle {
        id: toolbar
        width: parent.width
        height: 60
        color: "#d0d0d0"
        z: 10
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 5
            spacing: 10

            RowLayout {
                spacing: 2
                ToolButton { 
                    text: "＋"
                    onClicked: createNewScreenshot();
                    ToolTip.visible: hovered; ToolTip.text: "新しいスクリーンショット"
                    Layout.preferredHeight: 40; Layout.preferredWidth: 40
                }
                ToolButton { 
                    icon.source: "icons/paste.svg"
                    onClicked: pasteImage()
                    ToolTip.visible: hovered; ToolTip.text: "Paste (Ctrl+V)"
                    Layout.preferredHeight: 40; Layout.preferredWidth: 40
                }
                ToolButton { 
                    icon.source: "icons/copy.svg"
                    onClicked: copyAnnotatedImage()
                    ToolTip.visible: hovered; ToolTip.text: "Copy (Ctrl+C)"
                    Layout.preferredHeight: 40; Layout.preferredWidth: 40
                }
                ToolButton { 
                    icon.source: "icons/save.svg"
                    onClicked: saveDialog.open()
                    ToolTip.visible: hovered; ToolTip.text: "Save As (Ctrl+S)"
                    Layout.preferredHeight: 40; Layout.preferredWidth: 40
                }
            }

            Rectangle { width: 2; height: parent.height - 10; color: "#999" }

            ButtonGroup { id: toolGroup }
            
            component ToolButtonIcon: Item {
                id: control
                property string toolName: ""
                property string text: ""
                property bool checked: currentTool === toolName
                
                width: 40
                height: parent.height - 10
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.fill: parent
                    color: control.checked ? "#aaa" : (mouseArea.containsMouse ? "#e0e0e0" : "transparent")
                    radius: 5
                }
                Text {
                    anchors.centerIn: parent
                    text: control.text
                    font.pixelSize: 20
                    font.bold: control.toolName === "text"
                }
                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        currentTool = control.toolName;
                        if (control.toolName !== "none") selectedIndex = -1;
                    }
                }
            }

            ToolButtonIcon { text: "👆"; toolName: "none" }
            ToolButtonIcon { text: "⭕"; toolName: "circle" }
            ToolButtonIcon { text: "⬜"; toolName: "rect" }
            ToolButtonIcon { text: "↗"; toolName: "arrow" }
            ToolButtonIcon { text: "A"; toolName: "text" }

            ToolButton {
                text: "🪣"
                font.pixelSize: 20
                onClicked: {
                    if (selectedIndexes.length > 1 && (shapeModel.get(selectedIndex).type === "rect" || shapeModel.get(selectedIndex).type === "circle")) {
                        console.log("selectedIndexes in");
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
                Layout.preferredHeight: 40
                Layout.preferredWidth: 40
            }

            Rectangle { width: 2; height: parent.height - 10; color: "#999" }

            GridLayout {
                columns: 6
                rowSpacing: 4
                columnSpacing: 4
                Repeater {
                    model: ["#ff0000", "#ff8800", "#ffff00", "#00ff00", "#0000ff", "#ff00ff",
                            "#000000", "#555555", "#aaaaaa", "#ffffff", "#800000", "#008080"]
                    Rectangle {
                        width: 20
                        height: 20
                        color: modelData
                        border.color: currentColor === modelData ? (modelData === "#ffffff" ? "#000" : "#fff") : "#222"
                        border.width: currentColor === modelData ? 2 : 1
                        radius: 10
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                currentColor = modelData;
                                if (selectedIndexes.length > 1) {
                                    for (var i = 0; i < selectedIndexes.length; i++) {    
                                    shapeModel.setProperty(selectedIndexes[i], "color", modelData);
                                    }
                                } else if (selectedIndex >= 0) {
                                    shapeModel.setProperty(selectedIndex, "color", modelData);
                                }
                                    isSaved = false;
                                    saveState();
                                if (textInput.visible) {
                                    textInput.forceActiveFocus();
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { width: 2; height: parent.height - 10; color: "#999" }

            Text { text: "Size:"; color: "black"; Layout.alignment: Qt.AlignVCenter }
            SpinBox {
                from: 1
                to: 100
                value: currentThickness
                onValueModified: {
                    currentThickness = value;
                    if (selectedIndexes.length > 1) {
                        for(var i = 0; i < selectedIndexes.length; i++) {                            
                            shapeModel.setProperty(selectedIndexes[i], "thickness", value);
                        }
                    } else if (selectedIndex >= 0) {
                        shapeModel.setProperty(selectedIndex, "thickness", value);
                    }
                        isSaved = false;
                        saveState();
                }
                Layout.preferredWidth: 100
            }

            Rectangle { width: 2; height: parent.height - 10; color: "#999" }

            RowLayout {
                spacing: 2
                ToolButton { 
                    icon.source: "icons/undo.svg"
                    onClicked: undoShape()
                    ToolTip.visible: hovered; ToolTip.text: "Undo (Ctrl+Z)"
                    Layout.preferredHeight: 40; Layout.preferredWidth: 40
                }
                ToolButton { 
                    icon.source: "icons/redo.svg"
                    onClicked: redoShape()
                    ToolTip.visible: hovered; ToolTip.text: "Redo (Ctrl+Y)"
                    Layout.preferredHeight: 40; Layout.preferredWidth: 40
                }
                Rectangle { width: 1; height: 30; color: "#999" }
                ToolButton { 
                    icon.source: "icons/delete.svg"
                    onClicked: deleteSelectedShape()
                    enabled: selectedIndex >= 0
                    ToolTip.visible: hovered; ToolTip.text: "Delete Selected (Del)"
                    Layout.preferredHeight: 40; Layout.preferredWidth: 40
                }
                ToolButton { 
                    icon.source: "icons/clear.svg"
                    onClicked: clearConfirmDialog.open()
                    ToolTip.visible: hovered; ToolTip.text: "Clear All Shapes"
                    Layout.preferredHeight: 40; Layout.preferredWidth: 40
                }

                ToolButton { 
                    text: "?"
                    font.pixelSize: 20
                    onClicked: helpDialog.open()
                    ToolTip.visible: hovered; ToolTip.text: "help"
                    Layout.preferredHeight: 40; Layout.preferredWidth: 40
                }
            }
            
            Item { Layout.fillWidth: true }
        }
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
                if (selectedIndex >= 0 && currentTool === "none") { nudgeShape(-step, 0); nudged = true; }
                else switchImage(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                if (selectedIndex >= 0 && currentTool === "none") { nudgeShape(step, 0); nudged = true; }
                else switchImage(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up) {
                if (selectedIndex >= 0 && currentTool === "none") { nudgeShape(0, -step); nudged = true; }
                else if (selectedIndex < 0) currentThickness = Math.min(100, currentThickness + 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Down) {
                if (selectedIndex >= 0 && currentTool === "none") { nudgeShape(0, step); nudged = true; }
                else if (selectedIndex < 0) currentThickness = Math.max(1, currentThickness - 1);
                event.accepted = true;
            }
        }

        Keys.onReleased: (event) => {
            if (nudged && (event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
                saveState();
                nudged = false;
            }
        }

        Text {
            anchors.centerIn: parent
            text: qsTr("画像をここにドラッグ＆ドロップするか、Ctrl+Vで貼り付けてください\n（左右キーでフォルダ内の画像を切り替え）")
            color: "#888888"
            font.pixelSize: 20
            horizontalAlignment: Text.AlignHCenter
            visible: mainImage.source == ""
        }

        Item {
            id: imageContainer
            anchors.fill: parent
            anchors.margins: 20
            visible: mainImage.source != ""

            Item {
                id: captureArea
                width: mainImage.sourceSize.width > 0 ? mainImage.sourceSize.width : 1
                height: mainImage.sourceSize.height > 0 ? mainImage.sourceSize.height : 1
                anchors.centerIn: parent
                scale: Math.min(imageContainer.width / width, imageContainer.height / height)

                Image {
                    id: checkerboard
                    anchors.fill: parent
                    fillMode: Image.Tile
                    source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32'><rect width='32' height='32' fill='%232b2b2b'/><rect width='16' height='16' fill='%23444444'/><rect x='16' y='16' width='16' height='16' fill='%23444444'/></svg>"
                }

                Image {
                    id: mainImage
                    anchors.fill: parent
                    asynchronous: true
                    fillMode: Image.Stretch
                    smooth: true
                    mipmap: true
                }

                MouseArea {
                    id: drawArea
                    anchors.fill: parent
                    hoverEnabled: true

                    property int startX: 0
                    property int startY: 0
                    property bool isDrawing: false

                    property bool isDraggingShape: false
                    property int dragStartX: 0
                    property int dragStartY: 0
                    property int shapeStartX: 0
                    property int shapeStartY: 0
                    property var selectedDragShape: []

                    
                    property string isDraggingHandle: ""

                    function hitTestHandle(mx, my, hx, hy) {
                        var tol = 15 / captureArea.scale;
                        return Math.abs(mx - hx) < tol && Math.abs(my - hy) < tol;
                    }

                    function hitTestRect(mx, my, x, y, w, h, thickness) {
                        var margin = Math.max(15 / captureArea.scale, thickness + 5 / captureArea.scale);
                        var outer = (mx >= x - margin && mx <= x + w + margin && my >= y - margin && my <= y + h + margin);
                        var inner = (mx > x + margin && mx < x + w - margin && my > y + margin && my < y + h - margin);
                        return outer && !inner;
                    }

                    function hitTestCircle(mx, my, x, y, w, h, thickness) {
                        var cx = x + w / 2;
                        var cy = y + h / 2;
                        var r = Math.min(w, h) / 2;
                        var dx = Math.abs(mx - cx) - (Math.abs(w) / 2 - r);
                        var dy = Math.abs(my - cy) - (Math.abs(h) / 2 - r);
                        var dist = 0;
                        if (dx > 0 && dy > 0) {
                            dist = Math.sqrt(dx * dx + dy * dy) - r;
                        } else if (dx > 0) {
                            dist = dx - r;
                        } else if (dy > 0) {
                            dist = dy - r;
                        } else {
                            dist = Math.max(dx, dy) - r;
                        }
                        var margin = thickness / 2 + 5 / captureArea.scale;
                        return Math.abs(dist) <= margin;
                    }

                    function hitTestFilledEllipse(mx, my, x, y, w, h) {
                        if (w <= 0 || h <= 0) return false;
                        var dx = (mx - (x + w / 2)) / (w / 2);
                        var dy = (my - (y + h / 2)) / (h / 2);
                        return dx * dx + dy * dy <= 1;
                    }

                    function hitTestFill(mx, my, x, y, w, h) {
                        var margin = 5 / captureArea.scale;
                        return (mx >= x - margin && mx <= x + w + margin && my >= y - margin && my <= y + h + margin);
                    }

                    function hitTestArrow(mx, my, x, y, w, h, thickness, flipX, flipY) {
                        var sx = flipX ? x + w : x;
                        var sy = flipY ? y + h : y;
                        var ex = flipX ? x : x + w;
                        var ey = flipY ? y : y + h;
                        
                        var l2 = (ex - sx) * (ex - sx) + (ey - sy) * (ey - sy);
                        if (l2 === 0) return hitTestFill(mx, my, sx - 2, sy - 2, 4, 4);
                        
                        var t = ((mx - sx) * (ex - sx) + (my - sy) * (ey - sy)) / l2;
                        t = Math.max(0, Math.min(1, t));
                        var projX = sx + t * (ex - sx);
                        var projY = sy + t * (ey - sy);
                        
                        var dist = Math.sqrt((mx - projX) * (mx - projX) + (my - projY) * (my - projY));
                        var margin = Math.max(15 / captureArea.scale, thickness + 5 / captureArea.scale);
                        return dist <= margin;
                    }

                    function editTextShape(index) {
                        var item = shapeModel.get(index);
                        selectedIndex = index;
                        currentColor = item.color;
                        currentThickness = item.thickness;
                        textInput.editingIndex = index;
                        textInput.x = item.x;
                        textInput.y = item.y;
                        textInput.width = Math.max(item.w, 1);
                        textInput.height = Math.max(item.h, 1);
                        textInput.text = item.textStr;
                        textInput.visible = true;
                        textInput.forceActiveFocus();
                        textInput.cursorPosition = textInput.text.length;
                    }

                    function saveSelectedDragShape() {
                        var state = [];
                        for (var j = 0; j < selectedIndexes.length; j++) {
                            var modelIndex = selectedIndexes[j];
                            var selectedItem = shapeModel.get(modelIndex);
                            state.push({
                                selectedIndex: modelIndex,
                                x: selectedItem.x,
                                y: selectedItem.y,
                                w: selectedItem.w,
                                h: selectedItem.h,
                                flipX: selectedItem.flipX,
                                flipY: selectedItem.flipY
                            });
                        }
                        selectedDragShape = state;
                    }

                    onPressed: (mouse) => {
                        contentArea.forceActiveFocus();
                        
                        if (textInput.visible && currentTool === "text") {
                            textInput.focus = false;
                            return;
                        }

                        if (currentTool === "none") {
                            for (var handleIndex = shapeModel.count - 1; handleIndex >= 0; handleIndex--) {
                                if (selectedIndexes.indexOf(handleIndex) === -1) {
                                    continue;
                                }
                                var selItem = shapeModel.get(handleIndex);
                                if (selItem.type === "arrow") {
                                    var sx = selItem.x + (selItem.flipX ? selItem.w : 0);
                                    var sy = selItem.y + (selItem.flipY ? selItem.h : 0);
                                    var ex = selItem.x + (selItem.flipX ? 0 : selItem.w);
                                    var ey = selItem.y + (selItem.flipY ? 0 : selItem.h);
                                    if (hitTestHandle(mouse.x, mouse.y, sx, sy)) {
                                        selectedIndex = handleIndex;
                                        isDraggingHandle = "start";
                                        saveSelectedDragShape();
                                        return;
                                    }
                                    if (hitTestHandle(mouse.x, mouse.y, ex, ey)) {
                                        selectedIndex = handleIndex;
                                        isDraggingHandle = "end";
                                        saveSelectedDragShape();
                                        return;
                                    }
                                } else if (selItem.type === "rect" || selItem.type === "circle") {
                                    var tx = selItem.x;
                                    var ty = selItem.y;
                                    var bx = selItem.x + selItem.w;
                                    var by = selItem.y + selItem.h;
                                    if (hitTestHandle(mouse.x, mouse.y, tx, ty)) {
                                        selectedIndex = handleIndex;
                                        isDraggingHandle = "tl";
                                        saveSelectedDragShape();
                                        return;
                                    }
                                    if (hitTestHandle(mouse.x, mouse.y, bx, ty)) {
                                        selectedIndex = handleIndex;
                                        isDraggingHandle = "tr";
                                        saveSelectedDragShape();
                                        return;
                                    }
                                    if (hitTestHandle(mouse.x, mouse.y, tx, by)) {
                                        selectedIndex = handleIndex;
                                        isDraggingHandle = "bl";
                                        saveSelectedDragShape();
                                        return;
                                    }
                                    if (hitTestHandle(mouse.x, mouse.y, bx, by)) {
                                        selectedIndex = handleIndex;
                                        isDraggingHandle = "br";
                                        saveSelectedDragShape();
                                        return;
                                    }
                                }
                            }
                            
                            for (var i = shapeModel.count - 1; i >= 0; i--) {
                                var item = shapeModel.get(i);
                                var hit = false;
                                if (item.type === "text") {
                                    hit = hitTestFill(mouse.x, mouse.y, item.x, item.y, item.w, item.h);
                                } else if (item.type === "circle") {
                                    hit = item.filled === true
                                        ? hitTestFilledEllipse(mouse.x, mouse.y, item.x, item.y, item.w, item.h)
                                        : hitTestCircle(mouse.x, mouse.y, item.x, item.y, item.w, item.h, item.thickness);
                                } else if (item.type === "rect" && item.filled === true) {
                                    hit = hitTestFill(mouse.x, mouse.y, item.x, item.y, item.w, item.h);
                                } else if (item.type === "arrow") {
                                    hit = hitTestArrow(mouse.x, mouse.y, item.x, item.y, item.w, item.h, item.thickness, item.flipX, item.flipY);
                                } else {
                                    hit = hitTestRect(mouse.x, mouse.y, item.x, item.y, item.w, item.h, item.thickness);
                                }
                                
                                if (hit) {
                                    selectedIndex = i;
                                    if (mouse.modifiers & Qt.ShiftModifier) {
                                        if (selectedIndexes.indexOf(i) === -1) {
                                            selectedIndexes = selectedIndexes.concat([i]);
                                            
                                        }
                                    } else {
                                        if (selectedIndexes.indexOf(selectedIndex) == -1) {
                                            selectedIndexes = [i];
                                            selectedDragShape = [];
                                        }
                                    }
                                    // 線の太さ
                                    currentThickness = item.thickness;
                                    currentColor = item.color;
                                    dragStartX = mouse.x;
                                    dragStartY = mouse.y;
                                    shapeStartX = item.x;
                                    shapeStartY = item.y;

                                    saveSelectedDragShape();
                                    // 図形を選択状態
                                    isDraggingShape = true;
                                    return;
                                }
                            }
                            selectedIndex = -1;
                            selectedIndexes = [];
                            selectedDragShape = [];
                            return;
                        }

                        if (currentTool === "text") {
                            textInput.x = mouse.x
                            textInput.y = mouse.y
                            textInput.text = ""
                            textInput.visible = true
                            textInput.forceActiveFocus()
                            return;
                        }

                        startX = mouse.x
                        startY = mouse.y
                        isDrawing = true
                        
                        shapeModel.append({
                            type: currentTool,
                            color: currentColor,
                            thickness: currentThickness,
                            x: startX,
                            y: startY,
                            w: 0,
                            h: 0,
                            textStr: "",
                            filled: false,
                            flipX: false,
                            flipY: false
                        })
                    }

                    onDoubleClicked: (mouse) => {
                        if (currentTool !== "none") return;

                        for (var i = shapeModel.count - 1; i >= 0; i--) {
                            var item = shapeModel.get(i);
                            if (item.type === "text" && hitTestFill(mouse.x, mouse.y, item.x, item.y, item.w, item.h)) {
                                editTextShape(i);
                                mouse.accepted = true;
                                return;
                            }
                        }
                    }

                    onPositionChanged: (mouse) => {
                        if (currentTool === "none" && isDraggingHandle !== "" && selectedIndex >= 0) {
                            var selItem = shapeModel.get(selectedIndex);
                            if (selItem.type === "arrow") {
                                var sx = selItem.x + (selItem.flipX ? selItem.w : 0);
                                var sy = selItem.y + (selItem.flipY ? selItem.h : 0);
                                var ex = selItem.x + (selItem.flipX ? 0 : selItem.w);
                                var ey = selItem.y + (selItem.flipY ? 0 : selItem.h);
                                
                                if (isDraggingHandle === "start") {
                                    sx = mouse.x;
                                    sy = mouse.y;
                                } else {
                                    ex = mouse.x;
                                    ey = mouse.y;
                                }
                                
                                if (mouse.modifiers & Qt.ShiftModifier) {
                                    var dx = ex - sx;
                                    var dy = ey - sy;
                                    var angle = Math.atan2(dy, dx);
                                    var snapped = Math.round(angle / (Math.PI / 4)) * (Math.PI / 4);
                                    var r = Math.sqrt(dx*dx + dy*dy);
                                    if (isDraggingHandle === "start") {
                                        sx = ex - r * Math.cos(snapped);
                                        sy = ey - r * Math.sin(snapped);
                                    } else {
                                        ex = sx + r * Math.cos(snapped);
                                        ey = sy + r * Math.sin(snapped);
                                    }
                                }

                                var nnx = Math.min(sx, ex);
                                var nny = Math.min(sy, ey);
                                var nnw = Math.abs(ex - sx);
                                var nnh = Math.abs(ey - sy);
                                
                                shapeModel.setProperty(selectedIndex, "x", nnx);
                                shapeModel.setProperty(selectedIndex, "y", nny);
                                shapeModel.setProperty(selectedIndex, "w", nnw);
                                shapeModel.setProperty(selectedIndex, "h", nnh);
                                shapeModel.setProperty(selectedIndex, "flipX", sx > ex);
                                shapeModel.setProperty(selectedIndex, "flipY", sy > ey);
                                isSaved = false;
                                return;
                            } else if (selItem.type === "rect" || selItem.type === "circle") {
                                var activeStart = null;
                                if (selectedDragShape.length > 1) {
                                    for (var j = 0; j < selectedDragShape.length; j++) {
                                        if (selectedDragShape[j].selectedIndex === selectedIndex) {
                                            activeStart = selectedDragShape[j];
                                            break;
                                        }
                                    }
                                }
                                var resizeStart = activeStart !== null ? activeStart : selItem;
                                var tx = resizeStart.x;
                                var ty = resizeStart.y;
                                var bx = resizeStart.x + resizeStart.w;
                                var by = resizeStart.y + resizeStart.h;
                                
                                var signX = 1;
                                var signY = 1;
                                var size = 0;

                                if (isDraggingHandle === "tl") {
                                    tx = mouse.x; ty = mouse.y;
                                } else if (isDraggingHandle === "tr") {
                                    bx = mouse.x; ty = mouse.y;
                                } else if (isDraggingHandle === "bl") {
                                    tx = mouse.x; by = mouse.y;
                                } else if (isDraggingHandle === "br") {
                                    bx = mouse.x; by = mouse.y;
                                }

                                if (mouse.modifiers & Qt.ShiftModifier) {
                                    var dw = Math.abs(bx - tx);
                                    var dh = Math.abs(by - ty);
                                    size = Math.max(dw, dh);
                                    if (isDraggingHandle === "tl") {
                                        signX = mouse.x < bx ? -1 : 1;
                                        signY = mouse.y < by ? -1 : 1;
                                        tx = bx + signX * size;
                                        ty = by + signY * size;
                                    } else if (isDraggingHandle === "tr") {
                                        signX = mouse.x < tx ? -1 : 1;
                                        signY = mouse.y < by ? -1 : 1;
                                        bx = tx + signX * size;
                                        ty = by + signY * size;
                                    } else if (isDraggingHandle === "bl") {
                                        signX = mouse.x < bx ? -1 : 1;
                                        signY = mouse.y < ty ? -1 : 1;
                                        tx = bx + signX * size;
                                        by = ty + signY * size;
                                    } else if (isDraggingHandle === "br") {
                                        signX = mouse.x < tx ? -1 : 1;
                                        signY = mouse.y < ty ? -1 : 1;
                                        bx = tx + signX * size;
                                        by = ty + signY * size;
                                    }
                                }

                                // 複数選択時は、操作対象の図形を基準に各図形の開始位置・サイズを変換する
                                if (selectedDragShape.length > 1) {
                                    if (activeStart !== null && activeStart.w !== 0 && activeStart.h !== 0) {
                                        var anchorX = (isDraggingHandle === "tl" || isDraggingHandle === "bl")
                                            ? activeStart.x + activeStart.w : activeStart.x;
                                        var anchorY = (isDraggingHandle === "tl" || isDraggingHandle === "tr")
                                            ? activeStart.y + activeStart.h : activeStart.y;
                                        var scaleX = (bx - tx) / activeStart.w;
                                        var scaleY = (by - ty) / activeStart.h;

                                        for (var k = 0; k < selectedDragShape.length; k++) {
                                            var dragItem = selectedDragShape[k];
                                            var transformedLeft = anchorX + (dragItem.x - anchorX) * scaleX;
                                            var transformedRight = anchorX + (dragItem.x + dragItem.w - anchorX) * scaleX;
                                            var transformedTop = anchorY + (dragItem.y - anchorY) * scaleY;
                                            var transformedBottom = anchorY + (dragItem.y + dragItem.h - anchorY) * scaleY;

                                            shapeModel.setProperty(dragItem.selectedIndex, "x",
                                                                   Math.min(transformedLeft, transformedRight));
                                            shapeModel.setProperty(dragItem.selectedIndex, "y",
                                                                   Math.min(transformedTop, transformedBottom));
                                            shapeModel.setProperty(dragItem.selectedIndex, "w",
                                                                   Math.abs(transformedRight - transformedLeft));
                                            shapeModel.setProperty(dragItem.selectedIndex, "h",
                                                                   Math.abs(transformedBottom - transformedTop));
                                            if (dragItem.flipX !== undefined) {
                                                shapeModel.setProperty(dragItem.selectedIndex, "flipX",
                                                                       scaleX < 0 ? !dragItem.flipX : dragItem.flipX);
                                            }
                                            if (dragItem.flipY !== undefined) {
                                                shapeModel.setProperty(dragItem.selectedIndex, "flipY",
                                                                       scaleY < 0 ? !dragItem.flipY : dragItem.flipY);
                                            }
                                        }
                                    }
                                    isSaved = false;
                                    return;
                                }

                                shapeModel.setProperty(selectedIndex, "x", Math.min(tx, bx));
                                shapeModel.setProperty(selectedIndex, "y", Math.min(ty, by));
                                shapeModel.setProperty(selectedIndex, "w", Math.abs(bx - tx));
                                shapeModel.setProperty(selectedIndex, "h", Math.abs(by - ty));
                                isSaved = false;
                                return;
                            }
                        }

                        if (currentTool === "none" && isDraggingShape && selectedIndex >= 0) {
                            var dx = mouse.x - dragStartX;
                            var dy = mouse.y - dragStartY;

                            // 複数選択している場合、それぞれの図形のxy軸にマウス移動距離を足す
                            if (selectedDragShape.length !== 0) {
                                for (var i = 0; i < selectedDragShape.length; i++) {
                                    shapeModel.setProperty(selectedDragShape[i].selectedIndex, "x", selectedDragShape[i].x + dx);
                                    shapeModel.setProperty(selectedDragShape[i].selectedIndex, "y", selectedDragShape[i].y + dy);
                                }                                
                                isSaved = false;
                                return;
                            }

                            // XY軸それぞれ、図形のドラック開始時の座標に＋移動距離をセットしている
                            shapeModel.setProperty(selectedIndex, "x", shapeStartX + dx);
                            shapeModel.setProperty(selectedIndex, "y", shapeStartY + dy);
                            isSaved = false;
                            return;
                        }

                        if (!isDrawing) return;
                        
                        var lastIdx = shapeModel.count - 1;
                        var nx = Math.min(startX, mouse.x);
                        var ny = Math.min(startY, mouse.y);
                        var nw = Math.abs(mouse.x - startX);
                        var nh = Math.abs(mouse.y - startY);
                        
                        if ((currentTool === "circle" || currentTool === "rect") && (mouse.modifiers & Qt.ShiftModifier)) {
                            var size = Math.max(nw, nh);
                            nw = size;
                            nh = size;
                            nx = mouse.x < startX ? startX - size : startX;
                            ny = mouse.y < startY ? startY - size : startY;
                        }
                        
                        shapeModel.setProperty(lastIdx, "x", nx);
                        shapeModel.setProperty(lastIdx, "y", ny);
                        shapeModel.setProperty(lastIdx, "w", nw);
                        shapeModel.setProperty(lastIdx, "h", nh);
                        if (currentTool === "arrow") {
                            if (mouse.modifiers & Qt.ShiftModifier) {
                                var adx = mouse.x - startX;
                                var ady = mouse.y - startY;
                                var aangle = Math.atan2(ady, adx);
                                var asnapped = Math.round(aangle / (Math.PI / 4)) * (Math.PI / 4);
                                var ar = Math.sqrt(adx*adx + ady*ady);
                                var targetX = startX + ar * Math.cos(asnapped);
                                var targetY = startY + ar * Math.sin(asnapped);
                                shapeModel.setProperty(lastIdx, "x", Math.min(startX, targetX));
                                shapeModel.setProperty(lastIdx, "y", Math.min(startY, targetY));
                                shapeModel.setProperty(lastIdx, "w", Math.abs(targetX - startX));
                                shapeModel.setProperty(lastIdx, "h", Math.abs(targetY - startY));
                                shapeModel.setProperty(lastIdx, "flipX", targetX < startX);
                                shapeModel.setProperty(lastIdx, "flipY", targetY < startY);
                            } else {
                                shapeModel.setProperty(lastIdx, "flipX", mouse.x < startX);
                                shapeModel.setProperty(lastIdx, "flipY", mouse.y < startY);
                            }
                        }
                    }

                    onReleased: (mouse) => {
                        if (isDraggingHandle !== "") {
                            isDraggingHandle = "";
                            saveState();
                            return;
                        }

                        if (isDraggingShape) {
                            isDraggingShape = false;
                            if (mouse.x !== dragStartX || mouse.y !== dragStartY) {
                                saveState();
                            }
                            return;
                        }

                        if (isDrawing) {
                            isDrawing = false;
                            var lastIdx = shapeModel.count - 1;
                            if (lastIdx >= 0) {
                                var item = shapeModel.get(lastIdx);
                                if (item.w < 5 && item.h < 5) {
                                    shapeModel.remove(lastIdx);
                                    selectedIndex = -1;
                                } else {
                                    isSaved = false;
                                    saveState();
                                    currentTool = "none";
                                    selectedIndex = lastIdx;                                    
                                    selectedIndexes = [lastIdx];                                    
                                }
                            }
                        }
                    }
                }

                Repeater {
                    model: shapeModel
                    delegate: Item {
                        id: shapeItem
                        x: model.x
                        y: model.y
                        width: model.w
                        height: model.h

                        property bool isSelected: selectedIndexes.indexOf(index) !== -1
                        property real hScale: 1.0 / captureArea.scale

                        Item {
                            anchors.fill: parent
                            anchors.margins: - (model.thickness / 2) - 4 * hScale
                            visible: isSelected && currentTool === "none"

                            Rectangle {
                                id: selectionTop
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                height: 2 * hScale
                                color: "#00aaff"
                            }
                            Rectangle {
                                id: selectionBottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 2 * hScale
                                color: "#00aaff"
                            }
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 2 * hScale
                                color: "#00aaff"
                            }
                            Rectangle {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 2 * hScale
                                color: "#00aaff"
                            }
                        }
                        
                        // Rect/Circle handles
                        Rectangle {
                            width: 14 * hScale; height: 14 * hScale; radius: 7 * hScale
                            color: "#00aaff"; border.color: "white"; border.width: 2 * hScale
                            x: - (model.thickness / 2) - 4 * hScale - 7 * hScale; y: - (model.thickness / 2) - 4 * hScale - 7 * hScale
                            visible: isSelected && currentTool === "none" && (model.type === "rect" || model.type === "circle")
                        }
                        Rectangle {
                            width: 14 * hScale; height: 14 * hScale; radius: 7 * hScale
                            color: "#00aaff"; border.color: "white"; border.width: 2 * hScale
                            x: model.w + (model.thickness / 2) + 4 * hScale - 7 * hScale; y: - (model.thickness / 2) - 4 * hScale - 7 * hScale
                            visible: isSelected && currentTool === "none" && (model.type === "rect" || model.type === "circle")
                        }
                        Rectangle {
                            width: 14 * hScale; height: 14 * hScale; radius: 7 * hScale
                            color: "#00aaff"; border.color: "white"; border.width: 2 * hScale
                            x: - (model.thickness / 2) - 4 * hScale - 7 * hScale; y: model.h + (model.thickness / 2) + 4 * hScale - 7 * hScale
                            visible: isSelected && currentTool === "none" && (model.type === "rect" || model.type === "circle")
                        }
                        Rectangle {
                            width: 14 * hScale; height: 14 * hScale; radius: 7 * hScale
                            color: "#00aaff"; border.color: "white"; border.width: 2 * hScale
                            x: model.w + (model.thickness / 2) + 4 * hScale - 7 * hScale; y: model.h + (model.thickness / 2) + 4 * hScale - 7 * hScale
                            visible: isSelected && currentTool === "none" && (model.type === "rect" || model.type === "circle")
                        }
                        
                        // Arrow handles
                        Rectangle {
                            width: 14 * hScale; height: 14 * hScale; radius: 7 * hScale
                            color: "#00aaff"; border.color: "white"; border.width: 2 * hScale
                            x: (model.flipX ? model.w : 0) - 7 * hScale; y: (model.flipY ? model.h : 0) - 7 * hScale
                            visible: isSelected && currentTool === "none" && model.type === "arrow"
                        }
                        Rectangle {
                            width: 14 * hScale; height: 14 * hScale; radius: 7 * hScale
                            color: "#00aaff"; border.color: "white"; border.width: 2 * hScale
                            x: (model.flipX ? 0 : model.w) - 7 * hScale; y: (model.flipY ? 0 : model.h) - 7 * hScale
                            visible: isSelected && currentTool === "none" && model.type === "arrow"
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: model.filled === true ? model.color : "transparent"
                            border.color: model.color
                            border.width: model.thickness
                            visible: model.type === "rect"
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: model.filled === true ? model.color : "transparent"
                            border.color: model.color
                            border.width: model.thickness
                            radius: Math.max(width, height)
                            visible: model.type === "circle"
                        }

                        Text {
                            anchors.fill: parent
                            text: model.textStr
                            color: model.color
                            font.pixelSize: Math.max(20, model.thickness * 10)
                            wrapMode: Text.Wrap
                            visible: model.type === "text" && !(textInput.visible && textInput.editingIndex === index)
                        }

                        Canvas {
                            anchors.fill: parent
                            anchors.margins: -Math.max(20, model.thickness * 4)
                            visible: model.type === "arrow"
                            
                            property int _w: model.w
                            property int _h: model.h
                            property color _c: model.color
                            property int _t: model.thickness
                            property bool _fx: model.flipX !== undefined ? model.flipX : false
                            property bool _fy: model.flipY !== undefined ? model.flipY : false
                            property int _pad: Math.max(20, model.thickness * 4)
                            
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                
                                var sx = (_fx ? _w : 0) + _pad;
                                var sy = (_fy ? _h : 0) + _pad;
                                var ex = (_fx ? 0 : _w) + _pad;
                                var ey = (_fy ? 0 : _h) + _pad;
                                
                                ctx.beginPath();
                                ctx.moveTo(sx, sy);
                                ctx.lineTo(ex, ey);
                                ctx.strokeStyle = _c;
                                ctx.lineWidth = _t;
                                ctx.lineCap = "round";
                                ctx.lineJoin = "round";
                                ctx.stroke();
                                
                                var dx = ex - sx;
                                var dy = ey - sy;
                                var angle = Math.atan2(dy, dx);
                                var headlen = Math.max(15, _t * 3);
                                
                                ctx.beginPath();
                                ctx.moveTo(ex, ey);
                                ctx.lineTo(ex - headlen * Math.cos(angle - Math.PI / 6), ey - headlen * Math.sin(angle - Math.PI / 6));
                                ctx.lineTo(ex - headlen * Math.cos(angle + Math.PI / 6), ey - headlen * Math.sin(angle + Math.PI / 6));
                                ctx.closePath();
                                ctx.fillStyle = _c;
                                ctx.fill();
                            }
                            
                            on_WChanged: requestPaint()
                            on_HChanged: requestPaint()
                            on_CChanged: requestPaint()
                            on_TChanged: requestPaint()
                            on_FxChanged: requestPaint()
                            on_FyChanged: requestPaint()
                        }
                        
                        Rectangle {
                            width: 14
                            height: 14
                            radius: 7
                            color: "#00aaff"
                            border.color: "white"
                            border.width: 2
                            x: (model.flipX ? model.w : 0) - 7
                            y: (model.flipY ? model.h : 0) - 7
                            visible: isSelected && currentTool === "none" && model.type === "arrow"
                        }
                        Rectangle {
                            width: 14
                            height: 14
                            radius: 7
                            color: "#00aaff"
                            border.color: "white"
                            border.width: 2
                            x: (model.flipX ? 0 : model.w) - 7
                            y: (model.flipY ? 0 : model.h) - 7
                            visible: isSelected && currentTool === "none" && model.type === "arrow"
                        }
                    }
                }

                TextEdit {
                    id: textInput
                    visible: false
                    property int editingIndex: -1
                    color: currentColor
                    font.pixelSize: Math.max(20, currentThickness * 10)
                    selectByMouse: true
                    
                    onActiveFocusChanged: {
                        if (!activeFocus && visible) {
                            if (editingIndex >= 0 && editingIndex < shapeModel.count) {
                                if (text !== "") {
                                    shapeModel.setProperty(editingIndex, "textStr", text);
                                    shapeModel.setProperty(editingIndex, "w", Math.max(width, contentWidth));
                                    shapeModel.setProperty(editingIndex, "h", Math.max(height, contentHeight));
                                } else {
                                    shapeModel.remove(editingIndex);
                                }
                                isSaved = false;
                                saveState();
                            } else if (text !== "") {
                                shapeModel.append({
                                    type: "text",
                                    color: currentColor,
                                    thickness: currentThickness,
                                    x: x,
                                    y: y,
                                    w: width,
                                    h: height,
                                    textStr: text
                                })
                                isSaved = false;
                                saveState();
                            }
                            editingIndex = -1;
                            selectedIndex = -1;
                            visible = false;
                        }
                    }

                    Rectangle {
                        z: -1
                        anchors.fill: parent
                        anchors.margins: -5
                        color: "transparent"
                        border.color: "#88000000"
                        border.width: 1
                        visible: parent.visible
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            color: "transparent"
                            border.color: "#88ffffff"
                            border.width: 1
                        }
                    }
                }
            }
        }
    }

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
                if (!isSaved) {
                    discardDialog.pendingImageUrl = String(drop.urls[0]);
                    discardDialog.pendingImageIsPasted = false;
                    discardDialog.open();
                } else {
                    loadImage(String(drop.urls[0]), false);
                }                 
            }
        }
    }
}
