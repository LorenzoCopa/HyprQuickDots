pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../config"

FloatingWindow {
    id: clipboard
    color: "transparent"
    implicitWidth: 420
    implicitHeight: 580
    title: "qs-clipboard"
    visible: false

    property var items: []
    property bool cliphistInstalled: true
    property int hoveredId: -1
    property int _thumbIndex: -1
    property int _textLoadedId: -1
    property string previewText: ""
    property int keyboardIdx: 0

    readonly property var hoveredItem: {
        if (hoveredId < 0) { previewText = ""; _textLoadedId = -1; return null; }
        for (var i = 0; i < items.length; i++) {
            if (items[i].id === hoveredId) return items[i];
        }
        previewText = "";
        _textLoadedId = -1;
        return null;
    }

    onHoveredIdChanged: {
        if (hoveredId < 0) { previewText = ""; _textLoadedId = -1; return; }
        if (hoveredId === _textLoadedId) return;
        for (var i = 0; i < items.length; i++) {
            if (items[i].id === hoveredId && !items[i].isImage) {
                _textLoadedId = hoveredId;
                previewText = "";
                textPreviewProc.command = ["sh", "-c", "cliphist decode " + hoveredId + " 2>/dev/null"];
                textPreviewProc.running = true;
                return;
            }
        }
        _textLoadedId = hoveredId;
        previewText = "";
    }

    function moveSelection(delta) {
        var q = searchInput.text.toLowerCase().trim();
        var filtered = [];
        for (var i = 0; i < items.length; i++) {
            if (!q || items[i].preview.toLowerCase().indexOf(q) >= 0)
                filtered.push(items[i]);
        }
        if (filtered.length === 0) return;
        keyboardIdx = Math.max(0, Math.min(filtered.length - 1, keyboardIdx + delta));
        var item = filtered[keyboardIdx];
        hoveredId = item.id;
        if (!item.isImage) {
            _textLoadedId = item.id;
            previewText = "";
            textPreviewProc.command = ["sh", "-c", "cliphist decode " + item.id + " 2>/dev/null"];
            textPreviewProc.running = true;
        }
        list.positionViewAtIndex(keyboardIdx, ListView.Contain);
    }

    // ── IPC toggle ─────────────────────────────────────────────
    IpcHandler {
        target: "clipboard"
        function toggle(): void {
            if (!clipboard.visible) {
                searchInput.text = "";
                clipboard.keyboardIdx = 0;
                clipboard.refresh();
                clipboard.visible = true;
                Qt.callLater(() => searchInput.forceActiveFocus());
            } else {
                clipboard.visible = false;
            }
        }
        function hide(): void { clipboard.visible = false; }
    }

    // ── Auto-close on focus loss ───────────────────────────────
    HyprlandFocusGrab {
        windows: [clipboard]
        active: clipboard.visible && !Settings.captureActive
        onCleared: clipboard.visible = false
    }

    // Sobre un juego fullscreen el foco inicial puede quedarse en el juego
    // (constraint del puntero); pedirlo por dispatcher rompe el bloqueo.
    SelfFocus {
        targetTitle: "qs-clipboard"
        active: clipboard.visible
    }

    // ── Processes ──────────────────────────────────────────────
    Process {
        id: listProc
        command: ["sh", "-c", "cliphist list 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var data = text.trim();
                if (!data) {
                    clipboard.items = [];
                    return;
                }
                var lines = data.split("\n");
                var parsed = [];
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i];
                    if (!line) continue;
                    var idx = line.indexOf("\t");
                    if (idx >= 0) {
                        var cid = parseInt(line.substring(0, idx));
                        var content = line.substring(idx + 1);
                        var isImage = content.indexOf("binary data") >= 0;
                        var preview = content.split("\n")[0];
                        if (isImage) {
                            preview = preview.replace(/^\[\[ binary data | \]\]$/g, "");
                        }
                        if (preview.length > 80) preview = preview.substring(0, 80) + "...";
                        parsed.push({ id: cid, preview: preview, isImage: isImage, thumbReady: false });
                    }
                }
                clipboard.items = parsed;
                Qt.callLater(clipboard._startThumbQueue);
            }
        }
        onExited: function(exitCode) {
            if (exitCode === 127)
                clipboard.cliphistInstalled = false;
        }
    }

    Process {
        id: copyProc
        command: []
        running: false
    }

    Process {
        id: deleteProc
        command: []
        running: false
        onExited: clipboard.refresh()
    }

    Process {
        id: textPreviewProc
        command: []
        running: false
        stdout: StdioCollector {
            onStreamFinished: clipboard.previewText = text
        }
    }

    Process {
        id: thumbProc
        command: []
        running: false
        onExited: {
            if (clipboard._thumbIndex >= 0 && clipboard._thumbIndex < clipboard.items.length) {
                var newItems = [];
                for (var i = 0; i < clipboard.items.length; i++) {
                    if (i === clipboard._thumbIndex) {
                        var copy = {};
                        for (var k in clipboard.items[i]) copy[k] = clipboard.items[i][k];
                        copy.thumbReady = true;
                        newItems.push(copy);
                    } else {
                        newItems.push(clipboard.items[i]);
                    }
                }
                clipboard.items = newItems;
            }
            clipboard._thumbIndex++;
            clipboard._processNextThumb();
        }
    }

    // ── Functions ──────────────────────────────────────────────
    function copyItem(id): void {
        copyProc.command = ["sh", "-c", "cliphist decode " + id + " | wl-copy"];
        copyProc.running = true;
    }

    function deleteItem(id): void {
        deleteProc.command = ["sh", "-c", "cliphist delete " + id + " 2>/dev/null"];
        deleteProc.running = true;
    }

    function clearAll(): void {
        deleteProc.command = ["sh", "-c", "cliphist wipe 2>/dev/null"];
        deleteProc.running = true;
    }

    function refresh(): void {
        listProc.running = false;
        listProc.running = true;
    }

    function _startThumbQueue(): void {
        _thumbIndex = 0;
        _processNextThumb();
    }

    function _processNextThumb(): void {
        if (_thumbIndex >= items.length) { _thumbIndex = -1; return; }
        var item = items[_thumbIndex];
        if (!item.isImage || item.thumbReady) { _thumbIndex++; _processNextThumb(); return; }
        thumbProc.command = ["sh", "-c", "cliphist decode " + item.id + " > /tmp/qs_thumb_" + item.id + ".png 2>/dev/null"];
        thumbProc.running = true;
    }

    Component.onCompleted: refresh()

    // ── UI ─────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Settings.bg
        radius: 12

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── Header ────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Portapapeles"
                    color: Settings.subtext0
                    font.family: Settings.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }

                Text {
                    text: "(" + clipboard.items.length + ")"
                    color: Settings.subtext0
                    font.family: Settings.fontFamily
                    font.pixelSize: 11
                }

                Item { Layout.fillWidth: true }

                SymbolicIcon {
                    path: Icons.trash
                    color: clearHover.containsMouse ? Settings.red : Settings.subtext0
                    implicitSize: 12

                    MouseArea {
                        id: clearHover
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: clipboard.clearAll()
                    }
                }

                SymbolicIcon {
                    path: Icons.refresh
                    color: Settings.accent
                    implicitSize: 12

                    MouseArea {
                        id: refreshHover
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: clipboard.refresh()
                    }
                }
            }

            // ── Search input ──────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 28

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: Settings.surface
                }

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    text: "Buscar..."
                    color: Settings.subtext0
                    font.family: Settings.fontFamily
                    font.pixelSize: 11
                    visible: searchInput.text.length === 0
                }

                TextInput {
                    id: searchInput
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 10
                    }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Settings.fg
                    font.family: Settings.fontFamily
                    font.pixelSize: 11
                    onTextChanged: clipboard.keyboardIdx = 0

                    Keys.onEscapePressed: clipboard.visible = false
                    Keys.onReturnPressed: {
                        var filtered = getFilteredList();
                        if (filtered.length > 0 && clipboard.keyboardIdx < filtered.length) {
                            clipboard.copyItem(filtered[clipboard.keyboardIdx].id);
                            clipboard.visible = false;
                        }
                    }
                    Keys.onDownPressed: clipboard.moveSelection(1)
                    Keys.onUpPressed: clipboard.moveSelection(-1)
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier)) {
                            clipboard.moveSelection(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
                            clipboard.moveSelection(-1);
                            event.accepted = true;
                        }
                    }

                    function getFilteredList(): var {
                        var q = text.toLowerCase().trim();
                        if (!q) return clipboard.items;
                        var filtered = [];
                        for (var i = 0; i < clipboard.items.length; i++) {
                            if (clipboard.items[i].preview.toLowerCase().indexOf(q) >= 0)
                                filtered.push(clipboard.items[i]);
                        }
                        return filtered;
                    }
                }
            }

            // ── List ──────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: Settings.surface
                clip: true

                Text {
                    anchors.centerIn: parent
                    text: {
                        if (!clipboard.cliphistInstalled) return "cliphist no instalado";
                        if (clipboard.items.length === 0) return "Portapapeles vacio";
                        return "";
                    }
                    color: Settings.subtext0
                    font.family: Settings.fontFamily
                    font.pixelSize: 11
                    visible: text !== ""
                }

                ListView {
                    id: list
                    anchors.fill: parent
                    anchors.margins: 4
                    anchors.bottomMargin: 168
                    spacing: 2
                    visible: clipboard.items.length > 0
                    clip: true

                    model: {
                        var q = searchInput.text.toLowerCase().trim();
                        if (!q) return clipboard.items;
                        var filtered = [];
                        for (var i = 0; i < clipboard.items.length; i++) {
                            if (clipboard.items[i].preview.toLowerCase().indexOf(q) >= 0)
                                filtered.push(clipboard.items[i]);
                        }
                        return filtered;
                    }

                    delegate: Rectangle {
                        id: itemDelegate
                        width: list.width
                        height: 32
                        radius: 6
                        color: itemMouse.containsMouse || index === clipboard.keyboardIdx ? Settings.selectionBg : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }

                        required property var modelData
                        required property int index

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            spacing: 6

                            // ── Icon / thumbnail ─────────────
                            Item {
                                width: 22
                                height: 22
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 4
                                    color: modelData.isImage ? Settings.bg : "transparent"
                                    visible: modelData.isImage
                                }

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    source: modelData.isImage && modelData.thumbReady ? "file:///tmp/qs_thumb_" + modelData.id + ".png" : ""
                                    sourceSize { width: 22; height: 22 }
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    visible: modelData.isImage && modelData.thumbReady
                                }

                                SymbolicIcon {
                                    anchors.centerIn: parent
                                    path: modelData.isImage ? Icons.image : Icons.textFile
                                    color: modelData.isImage ? Settings.yellow : Settings.accent
                                    implicitSize: 11
                                    visible: !modelData.isImage || !modelData.thumbReady
                                }
                            }

                            // ── Preview text ─────────────────
                            Text {
                                Layout.fillWidth: true
                                text: modelData.preview
                                color: Settings.fg
                                font.family: Settings.fontFamily
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            // ── Delete button ────────────────
                            SymbolicIcon {
                                path: Icons.close
                                color: delHover.containsMouse ? Settings.red : "transparent"
                                implicitSize: 10

                                MouseArea {
                                    id: delHover
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        clipboard.deleteItem(itemDelegate.modelData.id);
                                        event.accepted = true;
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onEntered: clipboard.hoveredId = modelData.id
                            onExited: {
                                if (clipboard.hoveredId === modelData.id)
                                    clipboard.hoveredId = -1;
                            }
                            onClicked: {
                                clipboard.copyItem(itemDelegate.modelData.id);
                                clipboard.visible = false;
                            }
                        }
                    }
                }
            }
        }

        // ── Preview overlay (text + images) ──────────────
        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: 12
            }
            height: 160
            radius: 6
            color: Settings.bg
            z: 10
            visible: clipboard.hoveredItem != null

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: {
                            if (!clipboard.hoveredItem) return "";
                            return clipboard.hoveredItem.isImage ? "Imagen" : "Texto";
                        }
                        color: Settings.accent
                        font.family: Settings.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "Click para copiar"
                        color: Settings.subtext0
                        font.family: Settings.fontFamily
                        font.pixelSize: 8
                    }
                }

                // ── Image content ──────────────────────────
                Image {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: clipboard.hoveredItem && clipboard.hoveredItem.isImage
                    source: clipboard.hoveredItem && clipboard.hoveredItem.isImage && clipboard.hoveredItem.thumbReady ? "file:///tmp/qs_thumb_" + clipboard.hoveredItem.id + ".png" : ""
                    sourceSize { width: 400; height: 140 }
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (clipboard.hoveredItem) {
                                clipboard.copyItem(clipboard.hoveredItem.id);
                                clipboard.visible = false;
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Generando vista previa..."
                        color: Settings.subtext0
                        font.family: Settings.fontFamily
                        font.pixelSize: 10
                        visible: parent.status === Image.Loading || (clipboard.hoveredItem && clipboard.hoveredItem.isImage && !clipboard.hoveredItem.thumbReady)
                    }

                    SymbolicIcon {
                        anchors.centerIn: parent
                        path: Icons.image
                        color: Settings.yellow
                        implicitSize: 24
                        visible: parent.status === Image.Error
                    }
                }

                // ── Text content ───────────────────────────
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: clipboard.hoveredItem && !clipboard.hoveredItem.isImage
                    contentHeight: textPreview.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (clipboard.hoveredItem) {
                                clipboard.copyItem(clipboard.hoveredItem.id);
                                clipboard.visible = false;
                            }
                        }
                    }

                    Text {
                        id: textPreview
                        width: parent.width
                        text: clipboard.previewText || (clipboard.hoveredItem ? clipboard.hoveredItem.preview : "")
                        color: Settings.fg
                        font.family: Settings.fontFamily
                        font.pixelSize: 10
                        wrapMode: Text.Wrap
                        maximumLineCount: 50
                    }
                }
            }
        }
    }
}
