import QtQuick
import QtQuick.Window
import Qt.labs.folderlistmodel
import QtQuick.Dialogs

Item {
    property alias mouseArea: mouseArea

    // 描画領域全体のマウス入力を受け持つ
    // 選択ツールでは図形やハンドルの当たり判定を行い、選択・移動・サイズ変更を処理する
    // 描画ツールではドラッグ中に図形モデルを更新し、テキストツールでは入力欄を開く
    // 操作完了時には変更を確定し、必要に応じてMain.qmlのUndo履歴へ記録する。
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true

        property int startX: 0
        property int startY: 0
        property bool isDrawing: false

        property bool isDraggingShape: false
        property real dragStartX: 0
        property real dragStartY: 0
        property real shapeStartX: 0
        property real shapeStartY: 0
        property real shapeStartW: 0
        property real shapeStartH: 0
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
            mainWindow.selectedIndex = index;
            mainWindow.currentColor = item.color;
            mainWindow.currentThickness = item.thickness;
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

        // 選択図形のドラッグ開始時点の位置・サイズを保存する
        function saveSelectedDragShape() {
            var state = [];
            for (var j = 0; j < mainWindow.selectedIndexes.length; j++) {
                var modelIndex = mainWindow.selectedIndexes[j];
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
            
            if (textInput.visible && mainWindow.currentTool === "text") {
                textInput.focus = false;
                return;
            }

            if (mainWindow.currentTool === "none") {
                for (var handleIndex = shapeModel.count - 1; handleIndex >= 0; handleIndex--) {
                    if (mainWindow.selectedIndexes.indexOf(handleIndex) === -1) {
                        continue;
                    }
                    var selItem = shapeModel.get(handleIndex);
                    if (selItem.type === "arrow") {
                        var sx = selItem.x + (selItem.flipX ? selItem.w : 0);
                        var sy = selItem.y + (selItem.flipY ? selItem.h : 0);
                        var ex = selItem.x + (selItem.flipX ? 0 : selItem.w);
                        var ey = selItem.y + (selItem.flipY ? 0 : selItem.h);
                        shapeStartW = selItem.w;
                        shapeStartH = selItem.h;
                        if (hitTestHandle(mouse.x, mouse.y, sx, sy)) {
                            mainWindow.selectedIndex = handleIndex;
                            isDraggingHandle = "start";
                            saveSelectedDragShape();
                            return;
                        }
                        if (hitTestHandle(mouse.x, mouse.y, ex, ey)) {
                            mainWindow.selectedIndex = handleIndex;
                            isDraggingHandle = "end";
                            saveSelectedDragShape();
                            return;
                        }
                    } else if (selItem.type === "rect" || selItem.type === "circle" || selItem.type === "text") {
                        var tx = selItem.x;
                        var ty = selItem.y;
                        var bx = selItem.x + selItem.w;
                        var by = selItem.y + selItem.h;
                        shapeStartW = selItem.w;
                        shapeStartH = selItem.h;
                        if (hitTestHandle(mouse.x, mouse.y, tx, ty)) {
                            mainWindow.selectedIndex = handleIndex;
                            isDraggingHandle = "tl";
                            saveSelectedDragShape();
                            return;
                        }
                        if (hitTestHandle(mouse.x, mouse.y, bx, ty)) {
                            mainWindow.selectedIndex = handleIndex;
                            isDraggingHandle = "tr";
                            saveSelectedDragShape();
                            return;
                        }
                        if (hitTestHandle(mouse.x, mouse.y, tx, by)) {
                            mainWindow.selectedIndex = handleIndex;
                            isDraggingHandle = "bl";
                            saveSelectedDragShape();
                            return;
                        }
                        if (hitTestHandle(mouse.x, mouse.y, bx, by)) {
                            mainWindow.selectedIndex = handleIndex;
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
                        mainWindow.selectedIndex = i;
                        if (mouse.modifiers & Qt.ShiftModifier) {
                            if (mainWindow.selectedIndexes.indexOf(i) === -1) {
                                mainWindow.selectedIndexes = mainWindow.selectedIndexes.concat([i]);
                                
                            }
                        } else {
                            if (mainWindow.selectedIndexes.indexOf(mainWindow.selectedIndex) == -1) {
                                mainWindow.selectedIndexes = [i];
                                selectedDragShape = [];
                            }
                        }
                        // 線の太さ
                        mainWindow.currentThickness = item.thickness;
                        mainWindow.currentColor = item.color;
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
                mainWindow.selectedIndex = -1;
                mainWindow.selectedIndexes = [];
                selectedDragShape = [];
                return;
            }

            if (mainWindow.currentTool === "text") {
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
                type: mainWindow.currentTool,
                color: mainWindow.currentColor,
                thickness: mainWindow.currentThickness,
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
            if (mainWindow.currentTool !== "none") return;

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
            if (mainWindow.currentTool === "none" && isDraggingHandle !== "" && mainWindow.selectedIndex >= 0) {
                var selItem = shapeModel.get(mainWindow.selectedIndex);
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
                    
                    shapeModel.setProperty(mainWindow.selectedIndex, "x", nnx);
                    shapeModel.setProperty(mainWindow.selectedIndex, "y", nny);
                    shapeModel.setProperty(mainWindow.selectedIndex, "w", nnw);
                    shapeModel.setProperty(mainWindow.selectedIndex, "h", nnh);
                    shapeModel.setProperty(mainWindow.selectedIndex, "flipX", sx > ex);
                    shapeModel.setProperty(mainWindow.selectedIndex, "flipY", sy > ey);
                    mainWindow.isSaved = false;
                    return;
                } else if (selItem.type === "rect" || selItem.type === "circle" || selItem.type === "text") {
                    var activeStart = null;
                    if (selectedDragShape.length > 1) {
                        for (var j = 0; j < selectedDragShape.length; j++) {
                            if (selectedDragShape[j].selectedIndex === mainWindow.selectedIndex) {
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

                    // 複数選択時は、各図形のドラッグ角の反対側の角を固定してサイズ変更する
                    if (selectedDragShape.length > 1) {
                        if (activeStart !== null && activeStart.w !== 0 && activeStart.h !== 0) {
                            var scaleX = (bx - tx) / activeStart.w;
                            var scaleY = (by - ty) / activeStart.h;
                            var resizeFromLeft = isDraggingHandle === "tl" || isDraggingHandle === "bl";
                            var resizeFromTop = isDraggingHandle === "tl" || isDraggingHandle === "tr";

                            for (var k = 0; k < selectedDragShape.length; k++) {
                                var dragItem = selectedDragShape[k];
                                if (dragItem.selectedIndex === mainWindow.selectedIndex) {
                                    shapeModel.setProperty(dragItem.selectedIndex, "x", Math.min(tx, bx));
                                    shapeModel.setProperty(dragItem.selectedIndex, "y", Math.min(ty, by));
                                    shapeModel.setProperty(dragItem.selectedIndex, "w", Math.abs(bx - tx));
                                    shapeModel.setProperty(dragItem.selectedIndex, "h", Math.abs(by - ty));
                                } else {
                                    var resizedWidth = Math.abs(dragItem.w * scaleX);
                                    var resizedHeight = Math.abs(dragItem.h * scaleY);
                                    var fixedX = resizeFromLeft ? dragItem.x + dragItem.w : dragItem.x;
                                    var fixedY = resizeFromTop ? dragItem.y + dragItem.h : dragItem.y;
                                    var resizedEdgeX = fixedX + (resizeFromLeft ? -1 : 1) * dragItem.w * scaleX;
                                    var resizedEdgeY = fixedY + (resizeFromTop ? -1 : 1) * dragItem.h * scaleY;
                                    shapeModel.setProperty(dragItem.selectedIndex, "x",
                                                            Math.min(fixedX, resizedEdgeX));
                                    shapeModel.setProperty(dragItem.selectedIndex, "y",
                                                            Math.min(fixedY, resizedEdgeY));
                                    shapeModel.setProperty(dragItem.selectedIndex, "w",
                                                            resizedWidth);
                                    shapeModel.setProperty(dragItem.selectedIndex, "h",
                                                            resizedHeight);
                                }
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
                        mainWindow.isSaved = false;
                        return;
                    }

                    shapeModel.setProperty(mainWindow.selectedIndex, "x", Math.min(tx, bx));
                    shapeModel.setProperty(mainWindow.selectedIndex, "y", Math.min(ty, by));
                    shapeModel.setProperty(mainWindow.selectedIndex, "w", Math.abs(bx - tx));
                    shapeModel.setProperty(mainWindow.selectedIndex, "h", Math.abs(by - ty));
                    mainWindow.isSaved = false;
                    return;
                }
            }

            if (mainWindow.currentTool === "none" && isDraggingShape && mainWindow.selectedIndex >= 0) {
                var dx = mouse.x - dragStartX;
                var dy = mouse.y - dragStartY;

                // 複数選択している場合、それぞれの図形のxy軸にマウス移動距離を足す
                if (selectedDragShape.length !== 0) {
                    for (var i = 0; i < selectedDragShape.length; i++) {
                        shapeModel.setProperty(selectedDragShape[i].selectedIndex, "x", selectedDragShape[i].x + dx);
                        shapeModel.setProperty(selectedDragShape[i].selectedIndex, "y", selectedDragShape[i].y + dy);
                    }                                
                    mainWindow.isSaved = false;
                    return;
                }

                // XY軸それぞれ、図形のドラック開始時の座標に＋移動距離をセットしている
                shapeModel.setProperty(mainWindow.selectedIndex, "x", shapeStartX + dx);
                shapeModel.setProperty(mainWindow.selectedIndex, "y", shapeStartY + dy);
                mainWindow.isSaved = false;
                return;
            }

            if (!isDrawing) return;
            
            var lastIdx = shapeModel.count - 1;
            var nx = Math.min(startX, mouse.x);
            var ny = Math.min(startY, mouse.y);
            var nw = Math.abs(mouse.x - startX);
            var nh = Math.abs(mouse.y - startY);
            
            // Shift押下時は円・四角形の縦横比を1:1に固定する
            if ((mainWindow.currentTool === "circle" || mainWindow.currentTool === "rect") && (mouse.modifiers & Qt.ShiftModifier)) {
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
            if (mainWindow.currentTool === "arrow") {
                // 矢印はShift押下時に45度刻みへ揃え、始点・終点の向きはflip属性で保持する
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
                var handleItem = shapeModel.get(mainWindow.selectedIndex);
                // 図家の幅・高さと比べ、サイズが変わったときだけ履歴を保存
                if (handleItem.w !== shapeStartW || handleItem.h !== shapeStartH) {
                    mainWindow.saveState();
                }
                return;
            }

            if (isDraggingShape) {
                isDraggingShape = false;
                var draggedItem = shapeModel.get(mainWindow.selectedIndex);
                // 図形の位置を比べ、変わった時だけ履歴を保存
                if (draggedItem.x !== shapeStartX || draggedItem.y !== shapeStartY) {
                    mainWindow.saveState();
                }
                return;
            }

            if (isDrawing) {
                isDrawing = false;
                var lastIdx = shapeModel.count - 1;
                if (lastIdx >= 0) {
                    var item = shapeModel.get(lastIdx);
                    // 小さすぎる図形は作成を取り消し、それ以外は新規図形として確定する
                    if (item.w < 5 && item.h < 5) {
                        shapeModel.remove(lastIdx);
                        mainWindow.selectedIndex = -1;
                    } else {
                        mainWindow.isSaved = false;
                        mainWindow.saveState();
                        mainWindow.currentTool = "none";
                        mainWindow.selectedIndex = lastIdx;
                        mainWindow.selectedIndexes = [lastIdx];
                    }
                }
            }
        }
    }

    
    // RepeaterはshapeModel(図形を保持するリスト)を読み込んで実際に表示する
    Repeater {
        model: shapeModel
        delegate: Item {
            id: shapeItem
            required property var model
            required property int index
            x: shapeItem.model.x
            y: shapeItem.model.y
            width: shapeItem.model.w
            height: shapeItem.model.h

            property bool isSelected: mainWindow.selectedIndexes.indexOf(shapeItem.index) !== -1
            property real hScale: 1.0 / captureArea.scale

            Item {
                anchors.fill: parent
                anchors.margins: - (shapeItem.model.thickness / 2) - 4 * shapeItem.hScale
                visible: shapeItem.isSelected && mainWindow.currentTool === "none"

                Rectangle {
                    id: selectionTop
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 2 * shapeItem.hScale
                    color: "#00aaff"
                }
                Rectangle {
                    id: selectionBottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 2 * shapeItem.hScale
                    color: "#00aaff"
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 2 * shapeItem.hScale
                    color: "#00aaff"
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 2 * shapeItem.hScale
                    color: "#00aaff"
                }
            }
            
            // Rect/Circle handles
            Rectangle {
                width: 14 * shapeItem.hScale; height: 14 * shapeItem.hScale; radius: 7 * shapeItem.hScale
                color: "#00aaff"; border.color: "white"; border.width: 2 * shapeItem.hScale
                x: - (shapeItem.model.thickness / 2) - 4 * shapeItem.hScale - 7 * shapeItem.hScale; y: - (shapeItem.model.thickness / 2) - 4 * shapeItem.hScale - 7 * shapeItem.hScale
                visible: shapeItem.isSelected && mainWindow.currentTool === "none" && (shapeItem.model.type === "rect" || shapeItem.model.type === "circle" || shapeItem.model.type === "text")
            }
            Rectangle {
                width: 14 * shapeItem.hScale; height: 14 * shapeItem.hScale; radius: 7 * shapeItem.hScale
                color: "#00aaff"; border.color: "white"; border.width: 2 * shapeItem.hScale
                x: shapeItem.model.w + (shapeItem.model.thickness / 2) + 4 * shapeItem.hScale - 7 * shapeItem.hScale; y: - (shapeItem.model.thickness / 2) - 4 * shapeItem.hScale - 7 * shapeItem.hScale
                visible: shapeItem.isSelected && mainWindow.currentTool === "none" && (shapeItem.model.type === "rect" || shapeItem.model.type === "circle" || shapeItem.model.type === "text")
            }
            Rectangle {
                width: 14 * shapeItem.hScale; height: 14 * shapeItem.hScale; radius: 7 * shapeItem.hScale
                color: "#00aaff"; border.color: "white"; border.width: 2 * shapeItem.hScale
                x: - (shapeItem.model.thickness / 2) - 4 * shapeItem.hScale - 7 * shapeItem.hScale; y: shapeItem.model.h + (shapeItem.model.thickness / 2) + 4 * shapeItem.hScale - 7 * shapeItem.hScale
                visible: shapeItem.isSelected && mainWindow.currentTool === "none" && (shapeItem.model.type === "rect" || shapeItem.model.type === "circle" || shapeItem.model.type === "text")
            }
            Rectangle {
                width: 14 * shapeItem.hScale; height: 14 * shapeItem.hScale; radius: 7 * shapeItem.hScale
                color: "#00aaff"; border.color: "white"; border.width: 2 * shapeItem.hScale
                x: shapeItem.model.w + (shapeItem.model.thickness / 2) + 4 * shapeItem.hScale - 7 * shapeItem.hScale; y: shapeItem.model.h + (shapeItem.model.thickness / 2) + 4 * shapeItem.hScale - 7 * shapeItem.hScale
                visible: shapeItem.isSelected && mainWindow.currentTool === "none" && (shapeItem.model.type === "rect" || shapeItem.model.type === "circle" || shapeItem.model.type === "text")
            }
            
            // Arrow handles
            Rectangle {
                width: 14 * shapeItem.hScale; height: 14 * shapeItem.hScale; radius: 7 * shapeItem.hScale
                color: "#00aaff"; border.color: "white"; border.width: 2 * shapeItem.hScale
                x: (shapeItem.model.flipX ? shapeItem.model.w : 0) - 7 * shapeItem.hScale; y: (shapeItem.model.flipY ? shapeItem.model.h : 0) - 7 * shapeItem.hScale
                visible: shapeItem.isSelected && mainWindow.currentTool === "none" && shapeItem.model.type === "arrow"
            }
            Rectangle {
                width: 14 * shapeItem.hScale; height: 14 * shapeItem.hScale; radius: 7 * shapeItem.hScale
                color: "#00aaff"; border.color: "white"; border.width: 2 * shapeItem.hScale
                x: (shapeItem.model.flipX ? 0 : shapeItem.model.w) - 7 * shapeItem.hScale; y: (shapeItem.model.flipY ? 0 : shapeItem.model.h) - 7 * shapeItem.hScale
                visible: shapeItem.isSelected && mainWindow.currentTool === "none" && shapeItem.model.type === "arrow"
            }

            Rectangle {
                anchors.fill: parent
                color: shapeItem.model.filled === true ? shapeItem.model.color : "transparent"
                border.color: shapeItem.model.color
                border.width: shapeItem.model.thickness
                visible: shapeItem.model.type === "rect"
            }

            Rectangle {
                anchors.fill: parent
                color: shapeItem.model.filled === true ? shapeItem.model.color : "transparent"
                border.color: shapeItem.model.color
                border.width: shapeItem.model.thickness
                radius: Math.max(width, height)
                visible: shapeItem.model.type === "circle"
            }

            Text {
                anchors.fill: parent
                text: shapeItem.model.textStr
                color: shapeItem.model.color
                font.pixelSize: Math.max(20, shapeItem.model.thickness * 10)
                wrapMode: Text.Wrap
                visible: shapeItem.model.type === "text" && !(textInput.visible && textInput.editingIndex === shapeItem.index)
            }

            Canvas {
                anchors.fill: parent
                anchors.margins: -Math.max(20, shapeItem.model.thickness * 4)
                visible: shapeItem.model.type === "arrow"
                
                property int _w: shapeItem.model.w
                property int _h: shapeItem.model.h
                property color _c: shapeItem.model.color
                property int _t: shapeItem.model.thickness
                property bool _fx: shapeItem.model.flipX !== undefined ? shapeItem.model.flipX : false
                property bool _fy: shapeItem.model.flipY !== undefined ? shapeItem.model.flipY : false
                property int _pad: Math.max(20, shapeItem.model.thickness * 4)
                
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    
                    var sx = (_fx ? _w : 0) + _pad;
                    var sy = (_fy ? _h : 0) + _pad;
                    var ex = (_fx ? 0 : _w) + _pad;
                    var ey = (_fy ? 0 : _h) + _pad;
                    
                    var dx = ex - sx;
                    var dy = ey - sy;
                    var angle = Math.atan2(dy, dx);
                    var arrowLength = Math.sqrt(dx * dx + dy * dy);
                    var headlen = Math.min(Math.max(15, _t * 3), arrowLength * 0.8);
                    var leftX = ex - headlen * Math.cos(angle - Math.PI / 6);
                    var leftY = ey - headlen * Math.sin(angle - Math.PI / 6);
                    var rightX = ex - headlen * Math.cos(angle + Math.PI / 6);
                    var rightY = ey - headlen * Math.sin(angle + Math.PI / 6);
                    var baseX = (leftX + rightX) / 2;
                    var baseY = (leftY + rightY) / 2;

                    ctx.beginPath();
                    ctx.moveTo(sx, sy);
                    ctx.lineTo(baseX, baseY);
                    ctx.strokeStyle = _c;
                    ctx.lineWidth = _t;
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";
                    ctx.stroke();
                    
                    ctx.beginPath();
                    ctx.moveTo(ex, ey);
                    ctx.lineTo(leftX, leftY);
                    ctx.lineTo(rightX, rightY);
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
                x: (shapeItem.model.flipX ? shapeItem.model.w : 0) - 7
                y: (shapeItem.model.flipY ? shapeItem.model.h : 0) - 7
                visible: shapeItem.isSelected && mainWindow.currentTool === "none" && shapeItem.model.type === "arrow"
            }
            Rectangle {
                width: 14
                height: 14
                radius: 7
                color: "#00aaff"
                border.color: "white"
                border.width: 2
                x: (shapeItem.model.flipX ? 0 : shapeItem.model.w) - 7
                y: (shapeItem.model.flipY ? 0 : shapeItem.model.h) - 7
                visible: shapeItem.isSelected && mainWindow.currentTool === "none" && shapeItem.model.type === "arrow"
            }
        }
    }

    property bool textEditorActive: textInput.activeFocus
    property bool textEditorVisible: textInput.visible

    function focusTextEditor() {
        textInput.forceActiveFocus();
    }

    function pasteText() {
        textInput.paste();
    }

    function copyText() {
        textInput.copy();
    }

    function undoText() {
        textInput.undo();
    }

    function redoText() {
        textInput.redo();
    }

    TextEdit {
        id: textInput
        visible: false
        property int editingIndex: -1
        color: mainWindow.currentColor
        font.pixelSize: Math.max(20, mainWindow.currentThickness * 10)
        selectByMouse: true
        
        // 編集欄からフォーカスが外れた時点で、入力中の内容を図形モデルへ確定する
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
                    mainWindow.isSaved = false;
                    mainWindow.saveState();
                } else if (text !== "") {
                    shapeModel.append({
                        type: "text",
                        color: mainWindow.currentColor,
                        thickness: mainWindow.currentThickness,
                        x: x,
                        y: y,
                        w: width,
                        h: height,
                        textStr: text
                    })
                    mainWindow.isSaved = false;
                    mainWindow.saveState();
                }
                editingIndex = -1;
                mainWindow.selectedIndex = -1;
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