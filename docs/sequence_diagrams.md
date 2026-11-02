# 🎨 ImageAnnotator シーケンス図

Qt6 / QML で実装された `ImageAnnotator` の動作フロー図です。イベントの入口と、そこから呼び出される関数を明記しています。

## 1. コンポーネント構成概要

| コンポーネント | 役割・対象ファイル |
| --- | --- |
| **User** | アプリケーションの操作者 |
| **Main.qml (UI)** | ツールバー、キャンバス、マウス・キーボードイベント処理 |
| **Model / History** | 図形リスト (`shapeModel`)、Undo/Redo履歴 (`history`)、画像フォルダ (`folderModel`) |
| **ClipboardHelper** | QMLとOSクリップボード・一時ファイルI/Oを仲介するC++クラス (`clipboardhelper.cpp`) |
| **OS / FileSystem** | OSクリップボード、ローカルディスク |

## 2. アプリケーション起動・初期化フロー

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant MainCpp as main.cpp
    participant Helper as ClipboardHelper (C++)
    participant Engine as QQmlApplicationEngine
    participant MainQML as Main.qml (UI)

    User->>MainCpp: アプリ起動
    MainCpp->>MainCpp: main()
    MainCpp->>Helper: ClipboardHelper インスタンス生成
    activate Helper
    Helper->>Helper: コンストラクター<br/>setupTempDirectory()
    deactivate Helper

    MainCpp->>Engine: loadFromModule("ImageAnnotator", "Main")
    activate Engine
    Engine->>MainQML: Main.qml を読み込み root object を生成
    activate MainQML
    Engine-->>MainCpp: loadFromModule() 完了
    MainCpp->>MainQML: rootObjects().constFirst().setProperty("clipboardHelper", &clipboardHelper)
    MainCpp->>MainCpp: app.exec()
    MainQML-->>User: メイン画面表示 (ドラッグ&ドロップ待機)
    deactivate MainQML
    deactivate Engine
```

## 3. 画像の読み込み・取り込みフロー

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant QML as Main.qml
    participant Helper as ClipboardHelper
    participant OS as OS

    alt クリップボードから貼り付け
        alt 貼り付けボタン
            User->>QML: ToolButton.onClicked
        else Ctrl+V
            User->>QML: Shortcut.onActivated
        end
        QML->>QML: mainWindow.pasteImage()
        activate QML
        QML->>Helper: clipboardHelper.hasImage()
        Helper->>OS: クリップボード画像を確認
        OS-->>Helper: 画像の有無
        Helper-->>QML: hasImage()
        alt 画像あり
            QML->>Helper: clipboardHelper.pasteImageToTempFile()
            Helper->>OS: 画像を一時PNGに保存
            OS-->>Helper: tempFileUrl
            Helper-->>QML: tempFileUrl
                alt 未保存の変更あり
                    QML->>QML: discardDialog.open()
                    User->>QML: 続行を選択
                    QML->>QML: discardDialog.onAccepted
                    QML->>QML: loadImage(tempFileUrl, true)
                else 保存済み
                    QML->>QML: loadImage(tempFileUrl, true)
                end
        else 画像なし
            Note over QML: 画像を読み込まず終了
        end
        deactivate QML
    else ファイルをドロップ
        User->>QML: DropArea.onDropped: (drop) => {
        alt 保存済み
            QML->>QML: mainWindow.loadImage(fileUrl, false)
        else 未保存の変更あり
            QML->>QML: 確認ダイアログを表示
            User->>QML: 続行を選択
            QML->>QML: discardDialog.onAccepted
            QML->>QML: mainWindow.loadImage(fileUrl, false)
        end
    else フォルダ内の画像を切り替え
        User->>QML: ← / → キー → switchImage(direction)
        QML->>QML: performSwitch() (未保存なら確認後)
        QML->>QML: folderModel から次の画像を取得
        QML->>QML: loadImage(nextFileUrl, false)
    end

    Note over QML: loadImage() は図形・履歴・選択状態と画像を更新。貼り付け画像以外は画像フォルダも設定
```

## 4. アノテーション描画・編集・Undo/Redoフロー

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Canvas as drawArea (MouseArea)
    participant QML as Main.qml
    participant Model as shapeModel
    participant History as history (Undo/Redo)

    note over User, History: 【新規図形の描画】
    User->>Canvas: 図形ツール選択後、drawArea.MouseArea.onPressed
    Canvas->>Model: shapeModel.append(初期図形)
    User->>Canvas: マウスドラッグ
    Canvas->>Canvas: onPositionChanged で座標・サイズを更新<br/>Shift で正円/正方形・矢印角度を調整
    User->>Canvas: drawArea.MouseArea.onReleased
    Canvas->>QML: mainWindow.saveState()
    QML->>History: 図形一覧を履歴に追加
    QML->>QML: isSaved = false<br/>有効サイズなら currentTool = "none"
    note over User, History: 【図形の選択・変形・移動】
    User->>Canvas: 選択ツールで図形/ハンドルをクリック・ドラッグ
    Canvas->>Canvas: drawArea.onPressed / hitTest...()
    Canvas->>Model: onPositionChanged で shapeModel.setProperty()
    User->>Canvas: drawArea.onReleased
    Canvas->>QML: 移動/変形があれば mainWindow.saveState()
    QML->>History: 更新後の図形一覧を履歴に追加
    note over User, History: 【Undo / Redo 操作】
    alt Ctrl+Z
        User->>QML: Shortcut.onActivated
            QML->>QML: mainWindow.undoShape()
            QML->>QML: applyState(history[historyIndex])
            QML->>Model: shapeModel.clear() / append()
            Model-->>Canvas: モデル変更に応じて UI を再描画
    else Undo ボタン
        User->>QML: ToolButton.onClicked
        QML->>QML: mainWindow.undoShape()
        QML->>QML: applyState(history[historyIndex])
        QML->>Model: shapeModel.clear() / append()
        Model-->>Canvas: モデル変更に応じて UI を再描画
    end

    alt Ctrl+Y
        User->>QML: Shortcut.onActivated
            QML->>QML: mainWindow.redoShape()
            QML->>QML: applyState(history[historyIndex])
            QML->>Model: shapeModel.clear() / append()
            Model-->>Canvas: モデル変更に応じて UI を再描画
    else Redo ボタン
        User->>QML: ToolButton.onClicked
        QML->>QML: mainWindow.redoShape()
        QML->>QML: applyState(history[historyIndex])
        QML->>Model: shapeModel.clear() / append()
        Model-->>Canvas: モデル変更に応じて UI を再描画
    end
```

## 5. 新規スクリーンショットとキャンセル検知

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant MainQML as Main.qml
    participant Helper as ClipboardHelper (C++)
    participant SnippingTool as SnippingTool.exe
    participant OS as OS / Clipboard

    User->>MainQML: 新規スクリーンショットボタンをクリック
    MainQML->>MainQML: ToolButton.onClicked -> mainWindow.createNewScreenshot()
    MainQML->>MainQML: mainWindow.showMinimized()
    MainQML->>OS: Qt.openUrlExternally("ms-screenclip:")
    MainQML->>Helper: clipboardHelper.watchClipboard()
    Helper->>OS: dataChanged 接続・150 ms タイマー開始

    loop 150 ms間隔
        Helper->>OS: checkClippingWindow() -> EnumWindows()
        OS->>SnippingTool: 表示中ウィンドウの所有プロセスを照会
        SnippingTool-->>OS: 実行ファイル情報
        OS-->>Helper: Snipping Tool ウィンドウの表示状態
    end

    alt Snipping Tool でキャプチャを確定
        SnippingTool->>OS: キャプチャ画像をクリップボードへ設定
        OS-->>Helper: QClipboard::dataChanged
        Helper->>Helper: onClipboardDataChanged() -> hasImage()
        Helper->>OS: QClipboard::image()
        OS-->>Helper: 画像あり
        Helper->>Helper: unwatchClipboard()
        Helper-->>MainQML: clipboardChanged() signal
        MainQML->>MainQML: Connections.onClipboardChanged()
        MainQML->>MainQML: showNormal() / raise() / requestActivate()
    else Esc でキャンセル
        SnippingTool-->>OS: キャプチャ画面を閉じる
        Helper->>Helper: checkClippingWindow() が表示→非表示を検出
        Helper->>Helper: タイマー停止・200 ms後に m_isWatching を確認
        opt 200 ms以内に画像が届いていない
            Helper->>Helper: unwatchClipboard()
            Helper-->>MainQML: captureCanceled() signal
            MainQML->>MainQML: Connections.onCaptureCanceled()
            MainQML->>MainQML: showNormal() / raise() / requestActivate()
        end
    end
```

## 6. アノテーション付き画像の出力（保存 / クリップボードコピー）

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant MainQML as Main.qml
    participant Capture as captureArea (Item)
    participant Dialog as saveDialog (FileDialog)
    participant Helper as ClipboardHelper (C++)
    participant OS as OS / FileSystem

    alt ファイルへ保存
        alt Ctrl+S
            User->>MainQML: Shortcut.onActivated
            MainQML->>MainQML: mainWindow.openSaveDialog()
            MainQML->>Dialog: currentFile を設定して saveDialog.open()
        else 保存ボタン
            User->>MainQML: ToolButton.onClicked
            MainQML->>MainQML: mainWindow.openSaveDialog()
            MainQML->>Dialog: currentFile を設定して saveDialog.open()
        end
        User->>OS: 保存先パスを指定して決定
        OS-->>Dialog: selectedFile
        Dialog->>MainQML: FileDialog.onAccepted
        MainQML->>MainQML: 選択枠を非表示にする
        MainQML->>Capture: grabToImage(callback)
        Capture-->>MainQML: callback(result)
        MainQML->>OS: result.saveToFile(path)
        opt 保存に成功
            MainQML->>MainQML: isSaved = true
        end
        MainQML->>MainQML: 選択状態を復元
    else クリップボードへコピー
        alt Ctrl+C
            User->>MainQML: Shortcut.onActivated
                MainQML->>MainQML: mainWindow.copyAnnotatedImage()
        else Copy ボタン
            User->>MainQML: ToolButton.onClicked
            MainQML->>MainQML: mainWindow.copyAnnotatedImage()
        end
            MainQML->>MainQML: 選択枠を非表示にする
            MainQML->>Capture: grabToImage(callback)
            Capture-->>MainQML: callback(result)
            MainQML->>Helper: generateTempFilePath()
            Helper-->>MainQML: tempUrl
            opt tempUrl が空でない
                MainQML->>OS: result.saveToFile(localPath)
                MainQML->>Helper: copyImageFromTempFile(tempUrl)
                Helper->>OS: QImage(filePath) を読み込み<br/>QClipboard::setImage()
            end
            MainQML->>MainQML: 選択状態を復元
    end
```
