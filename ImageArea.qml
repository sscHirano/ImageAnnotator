
import QtQuick
import QtQuick.Window
import Qt.labs.folderlistmodel
import QtQuick.Dialogs

// 画像の表示領域。contentAreaの端から20pxの余白を取り、画像が収まる範囲を定める
Item {
    id: imageContainer
    anchors.fill: parent
    anchors.margins: 20

    property alias drawArea: drawArea
    property alias captureArea: captureArea
    property alias source: mainImage.source

    // 画像未読み込み時
    Text {
        anchors.centerIn: parent
        text: qsTr("画像をここにドラッグ＆ドロップするか、Ctrl+Vで貼り付けてください\n（左右キーでフォルダ内の画像を切り替え）")
        color: "#888888"
        font.pixelSize: 20
        horizontalAlignment: Text.AlignHCenter
        visible: String(mainImage.source) === ""
    }

    // 元画像のピクセル寸法と表示倍率を持ち、背景・画像・図形を重ねるキャプチャ領域
    Item {
        id: captureArea
        visible: String(mainImage.source) !== ""
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
