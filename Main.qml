import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import QtQuick.Dialogs

Window {
    id: mainWindow
    width: 900
    height: 600
    visible: true
    title: qsTr("Image Annotator") + (isSaved ? "" : " *")
    color: "#2b2b2b"

    property string currentTool: "none"
    property string currentColor: "#ff0000"
    property int currentThickness: 3
    property bool isPastedImage: false
    property int selectedIndex: -1
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
                textStr: item.textStr
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

    function undoShape() {
        if (historyIndex > 0) {
            historyIndex--;
            applyState(history[historyIndex]);
            selectedIndex = -1;
            isSaved = false;
        } else if (historyIndex === 0) {
            historyIndex = -1;
            applyState([]);
            selectedIndex = -1;
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
        if (selectedIndex >= 0 && selectedIndex < shapeModel.count) {
            shapeModel.remove(selectedIndex);
            selectedIndex = -1;
            isSaved = false;
            saveState();
        }
    }

    function nudgeShape(dx, dy) {
        if (selectedIndex >= 0 && selectedIndex < shapeModel.count) {
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
        text: "保存されていない変更が破棄されますが、別の画像へ移動しますか？"
        buttons: MessageDialog.Yes | MessageDialog.No
        property int pendingDirection: 0
        onAccepted: {
            shapeModel.clear();
            history = [];
            historyIndex = -1;
            isSaved = true;
            performSwitch(pendingDirection);
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

    onClosing: (close_event) => {
        if (!isSaved && shapeModel.count > 0) {
            close_event.accepted = false;
            exitDialog.open();
        }
    }

    Shortcut { sequence: "Ctrl+S"; onActivated: saveDialog.open(); context: Qt.ApplicationShortcut }

    Shortcut {
        sequence: StandardKey.Paste
        context: Qt.ApplicationShortcut
        onActivated: {
            if (textInput.activeFocus) textInput.paste();
            else pasteImage();
        }
    }
    Shortcut {
        sequence: StandardKey.Copy
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
        sequence: StandardKey.Delete
        context: Qt.ApplicationShortcut
        onActivated: {
            if (!textInput.activeFocus) deleteSelectedShape();
        }
    }

    function switchImage(direction) {
        if (isPastedImage) return;
        if (folderModel.count <= 1 || mainImage.source == "") return;
        
        if (shapeModel.count > 0 && !isSaved) {
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
                loadImage(url, true);
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

            ColumnLayout {
                spacing: 2
                Button { text: "Paste"; onClicked: pasteImage(); Layout.preferredHeight: 22 }
                Button { text: "Copy"; onClicked: copyAnnotatedImage(); Layout.preferredHeight: 22 }
            }
            Button { text: "Save As"; onClicked: saveDialog.open(); Layout.preferredHeight: 46 }

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
            ToolButtonIcon { text: "A"; toolName: "text" }

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
                                if (selectedIndex >= 0) {
                                    shapeModel.setProperty(selectedIndex, "color", modelData);
                                    isSaved = false;
                                    saveState();
                                }
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
                    if (selectedIndex >= 0) {
                        shapeModel.setProperty(selectedIndex, "thickness", value);
                        isSaved = false;
                        saveState();
                    }
                }
                Layout.preferredWidth: 100
            }

            Rectangle { width: 2; height: parent.height - 10; color: "#999" }

            ColumnLayout {
                spacing: 2
                Button { text: "Undo"; onClicked: undoShape(); Layout.preferredHeight: 22 }
                Button { text: "Redo"; onClicked: redoShape(); Layout.preferredHeight: 22 }
            }
            ColumnLayout {
                spacing: 2
                Button { text: "Delete"; onClicked: deleteSelectedShape(); Layout.preferredHeight: 22; enabled: selectedIndex >= 0 }
                Button { text: "Clear All"; onClicked: { shapeModel.clear(); selectedIndex = -1; isSaved = false; saveState(); } Layout.preferredHeight: 22 }
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

                    function hitTestRect(mx, my, x, y, w, h, thickness) {
                        var margin = Math.max(15, thickness + 5);
                        var outer = (mx >= x - margin && mx <= x + w + margin && my >= y - margin && my <= y + h + margin);
                        var inner = (mx > x + margin && mx < x + w - margin && my > y + margin && my < y + h - margin);
                        return outer && !inner;
                    }

                    function hitTestCircle(mx, my, x, y, w, h, thickness) {
                        var rx = w / 2;
                        var ry = h / 2;
                        if (rx < 0.1) rx = 0.1;
                        if (ry < 0.1) ry = 0.1;
                        var cx = x + rx;
                        var cy = y + ry;
                        var dx = mx - cx;
                        var dy = my - cy;
                        var nx = dx / rx;
                        var ny = dy / ry;
                        var d = Math.sqrt(nx * nx + ny * ny);
                        
                        var m = Math.max(15, thickness + 5);
                        var minR = Math.min(rx, ry);
                        var marginRatio = m / minR;
                        
                        if (minR < 5) return d <= 1.0 + marginRatio;
                        return d >= 1.0 - marginRatio && d <= 1.0 + marginRatio;
                    }

                    function hitTestFill(mx, my, x, y, w, h) {
                        var margin = 5;
                        return (mx >= x - margin && mx <= x + w + margin && my >= y - margin && my <= y + h + margin);
                    }

                    onPressed: (mouse) => {
                        contentArea.forceActiveFocus();
                        
                        if (textInput.visible && currentTool === "text") {
                            textInput.focus = false;
                            return;
                        }

                        if (currentTool === "none") {
                            for (var i = shapeModel.count - 1; i >= 0; i--) {
                                var item = shapeModel.get(i);
                                var hit = false;
                                if (item.type === "text") {
                                    hit = hitTestFill(mouse.x, mouse.y, item.x, item.y, item.w, item.h);
                                } else if (item.type === "circle") {
                                    hit = hitTestCircle(mouse.x, mouse.y, item.x, item.y, item.w, item.h, item.thickness);
                                } else {
                                    hit = hitTestRect(mouse.x, mouse.y, item.x, item.y, item.w, item.h, item.thickness);
                                }
                                
                                if (hit) {
                                    selectedIndex = i;
                                    currentThickness = item.thickness;
                                    currentColor = item.color;
                                    dragStartX = mouse.x;
                                    dragStartY = mouse.y;
                                    shapeStartX = item.x;
                                    shapeStartY = item.y;
                                    isDraggingShape = true;
                                    return;
                                }
                            }
                            selectedIndex = -1;
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
                            textStr: ""
                        })
                    }

                    onPositionChanged: (mouse) => {
                        if (currentTool === "none" && isDraggingShape && selectedIndex >= 0) {
                            var dx = mouse.x - dragStartX;
                            var dy = mouse.y - dragStartY;
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
                    }

                    onReleased: (mouse) => {
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
                                } else {
                                    isSaved = false;
                                    saveState();
                                }
                            }
                            selectedIndex = -1;
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

                        property bool isSelected: index === selectedIndex

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: - (model.thickness / 2) - 4
                            color: "transparent"
                            border.color: "#00aaff"
                            border.width: 2
                            visible: isSelected && currentTool === "none"
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: model.color
                            border.width: model.thickness
                            visible: model.type === "rect"
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
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
                            visible: model.type === "text"
                        }
                    }
                }

                TextEdit {
                    id: textInput
                    visible: false
                    color: currentColor
                    font.pixelSize: Math.max(20, currentThickness * 10)
                    selectByMouse: true
                    
                    onActiveFocusChanged: {
                        if (!activeFocus && visible) {
                            if (text !== "") {
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
                loadImage(String(drop.urls[0]), false);
            }
        }
    }
}
