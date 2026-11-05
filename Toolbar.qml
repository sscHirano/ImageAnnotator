import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    RowLayout {
        anchors.fill: parent
        anchors.margins: 5
        spacing: 10

        RowLayout {
            spacing: 2
            ToolButton { 
                text: "＋"
                onClicked: mainWindow.createNewScreenshot();
                ToolTip.visible: hovered; ToolTip.text: "新しいスクリーンショット"
                Layout.preferredHeight: 40; Layout.preferredWidth: 40
            }
            ToolButton { 
                icon.source: "icons/paste.svg"
                onClicked: mainWindow.pasteImage()
                ToolTip.visible: hovered; ToolTip.text: "画像を貼り付け (Ctrl+V)"
                Layout.preferredHeight: 40; Layout.preferredWidth: 40
            }
            ToolButton { 
                icon.source: "icons/copy.svg"
                onClicked: mainWindow.copyAnnotatedImage()
                ToolTip.visible: hovered; ToolTip.text: "画像をコピー (Ctrl+C)"
                Layout.preferredHeight: 40; Layout.preferredWidth: 40
            }
            ToolButton { 
                icon.source: "icons/save.svg"
                onClicked: mainWindow.openSaveDialog();
                ToolTip.visible: hovered; ToolTip.text: "画像を保存 (Ctrl+S)"
                Layout.preferredHeight: 40; Layout.preferredWidth: 40
            }
        }

        Rectangle {
            Layout.preferredWidth: 2
            Layout.preferredHeight: 40
            color: "#999"
        }

        ButtonGroup { id: toolGroup }
        
        component ToolButtonIcon: Item {
            id: control
            property string toolName: ""
            property string text: ""
            property bool checked: mainWindow.currentTool === toolName
            
            implicitWidth: 40
            implicitHeight: 40
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
                    mainWindow.currentTool = control.toolName;
                    if (control.toolName !== "none") mainWindow.selectedIndex = -1;
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
                mainWindow.applyFillColor();
            }
            Layout.preferredHeight: 40
            Layout.preferredWidth: 40
        }

        Rectangle {
            Layout.preferredWidth: 2
            Layout.preferredHeight: 40
            color: "#999"
        }

        GridLayout {
            columns: 6
            rowSpacing: 4
            columnSpacing: 4
            Repeater {
                model: ["#ff0000", "#ff8800", "#ffff00", "#00ff00", "#0000ff", "#ff00ff",
                        "#000000", "#555555", "#aaaaaa", "#ffffff", "#800000", "#008080"]
                Rectangle {
                    id: colorSwatch
                    required property var modelData
                    width: 20
                    height: 20
                    color: colorSwatch.modelData
                    border.color: mainWindow.currentColor === colorSwatch.modelData ? (colorSwatch.modelData === "#ffffff" ? "#000" : "#fff") : "#222"
                    border.width: mainWindow.currentColor === colorSwatch.modelData ? 2 : 1
                    radius: 10
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            mainWindow.applyColor(colorSwatch.modelData);
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 2
            Layout.preferredHeight: 40
            color: "#999"
        }

        Text { text: "Size:"; color: "black"; Layout.alignment: Qt.AlignVCenter }
        SpinBox {
            from: 1
            to: 100
            value: mainWindow.currentThickness
            onValueModified: {
                mainWindow.applyThickness(value);
            }
            Layout.preferredWidth: 100
        }

        Rectangle {
            Layout.preferredWidth: 2
            Layout.preferredHeight: 40
            color: "#999"
        }

        RowLayout {
            spacing: 2
            ToolButton { 
                icon.source: "icons/undo.svg"
                onClicked: mainWindow.undoShape()
                ToolTip.visible: hovered; ToolTip.text: "Undo (Ctrl+Z)"
                Layout.preferredHeight: 40; Layout.preferredWidth: 40
            }
            ToolButton { 
                icon.source: "icons/redo.svg"
                onClicked: mainWindow.redoShape()
                ToolTip.visible: hovered; ToolTip.text: "Redo (Ctrl+Y)"
                Layout.preferredHeight: 40; Layout.preferredWidth: 40
            }
            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 30
                color: "#999"
            }
            ToolButton { 
                icon.source: "icons/delete.svg"
                onClicked: mainWindow.deleteSelectedShape()
                enabled: mainWindow.selectedIndex >= 0
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
