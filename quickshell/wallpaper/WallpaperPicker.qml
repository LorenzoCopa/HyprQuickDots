pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../config"

FloatingWindow {
    id: picker
    color: "transparent"
    implicitWidth: 620
    implicitHeight: 360
    title: "qs-wallpaper"
    visible: false

    property int currentIndex: 0
    property string wallpaperDir: Quickshell.env("HOME") + "/Wallpapers"
    property string targetMonitor: ""
    property string transitionType: "random"
    // Cuando se abre el selector, restaura el wallpaper actual del monitor
    // objetivo como el seleccionado (y centrado), para saber con cuál se está.
    property bool pendingRestore: false

    function applyWallpaper(): void {
        if (currentIndex < 0 || currentIndex >= scanner.count) return;
        const fileName = scanner.get(currentIndex);
        const filePath = wallpaperDir + "/" + fileName;
        if (targetMonitor) {
            applyProc.command = ["awww", "img", "-o", targetMonitor, "--transition-type", picker.transitionType, filePath];
        } else {
            applyProc.command = ["awww", "img", "-a", "--transition-type", picker.transitionType, filePath];
        }
        applyProc.running = true;
        picker.visible = false;
    }

    function currentMonitorName(): string {
        return picker.targetMonitor || "N/A";
    }

    // Lee el cache de awww (~/.cache/awww/<version>/<monitor>), que guarda el
    // wallpaper mostrado actualmente, y marca/centra ese archivo en la lista.
    function restoreCurrent(): void {
        if (!picker.targetMonitor || !scanner.count) return;
        currentProc.command = ["sh", "-c",
            "f=$(ls ~/.cache/awww/*/" + picker.targetMonitor + " 2>/dev/null | sort -V | tail -n1); " +
            "if [ -n \"$f\" ]; then tr '\\0' '\\n' < \"$f\" | grep -iE '\\.(png|jpg|jpeg|webp|gif)$' | tail -n1; fi"];
        currentProc.running = true;
    }

    function setCurrentFromCache(raw): void {
        if (raw === undefined || raw === null) return;
        const path = String(raw).trim();
        if (!path) return;
        const slash = path.lastIndexOf("/");
        const file = slash >= 0 ? path.substring(slash + 1) : path;
        for (let i = 0; i < scanner.images.length; i++) {
            if (scanner.images[i] === file) {
                picker.currentIndex = i;
                Qt.callLater(() => wallList.positionViewAtIndex(i, ListView.Center));
                return;
            }
        }
    }

    DirectoryScanner {
        id: scanner
    }

    Process {
        id: applyProc
        command: []
        running: false
    }

    // Una vez cargada la lista, restaura el wallpaper actual (si había
    // solicitud pendiente al abrir el selector).
    Connections {
        target: scanner
        function onReady() {
            if (picker.pendingRestore) {
                picker.pendingRestore = false;
                picker.restoreCurrent();
            }
        }
    }

    Process {
        id: currentProc
        command: []
        running: false
        stdout: StdioCollector {
            onStreamFinished: picker.setCurrentFromCache(text)
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void {
            if (!picker.visible) {
                picker.currentIndex = 0;
                const mon = Hyprland.focusedMonitor;
                picker.targetMonitor = mon ? mon.name : "";
                picker.pendingRestore = true;
                scanner.refresh();
                picker.visible = true;
                Qt.callLater(() => escCatcher.forceActiveFocus());
            } else {
                picker.visible = false;
            }
        }
        function show(): void {
            picker.currentIndex = 0;
            const mon = Hyprland.focusedMonitor;
            picker.targetMonitor = mon ? mon.name : "";
            picker.pendingRestore = true;
            scanner.refresh();
            picker.visible = true;
            Qt.callLater(() => escCatcher.forceActiveFocus());
        }
        function hide(): void {
            picker.visible = false;
        }
    }

    HyprlandFocusGrab {
        windows: [picker]
        active: picker.visible && !Settings.captureActive
        onCleared: picker.visible = false
    }

    // Sobre un juego fullscreen el foco inicial puede quedarse en el juego
    // (constraint del puntero); pedirlo por dispatcher rompe el bloqueo.
    SelfFocus {
        targetTitle: "qs-wallpaper"
        active: picker.visible
    }

    Rectangle {
        id: content
        anchors.fill: parent
        color: Settings.bg
        radius: 12
        clip: true

        transform: Translate {
            x: picker.visible ? 0 : -picker.width
            Behavior on x {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
        }
        opacity: picker.visible ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Wallpapers"
                    color: Settings.fg
                    font.family: Settings.fontFamily
                    font.pixelSize: 18
                    font.weight: Font.Bold
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: monitorRow.implicitWidth + 20
                    radius: 6
                    color: Settings.surface

                    RowLayout {
                        id: monitorRow
                        anchors.centerIn: parent
                        spacing: 5

                        SymbolicIcon {
                            path: Icons.download
                            color: Settings.accent
                            implicitSize: 12
                        }

                        Text {
                            color: Settings.accent
                            font.family: Settings.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            text: picker.currentMonitorName()
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Settings.surface
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                clip: true

                ListView {
                    id: wallList
                    anchors.fill: parent
                    orientation: ListView.Horizontal
                    spacing: 10
                    currentIndex: picker.currentIndex

                    model: scanner.images

                    delegate: Rectangle {
                        id: delegate
                        required property int index
                        required property string modelData

                        width: 180
                        height: wallList.height
                        radius: 10
                        color: "transparent"

                        property bool isCurrent: wallList.currentIndex === delegate.index

                        Rectangle {
                            id: imageRect
                            width: delegate.width - 4
                            height: delegate.height - 4
                            anchors.centerIn: parent
                            radius: 8
                            clip: true
                            scale: delegate.isCurrent ? 1.05 : 1.0
                            border {
                                width: delegate.isCurrent ? 2 : 0
                                color: Settings.accent
                            }
                            Behavior on scale {
                                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                            }
                            Behavior on border.width {
                                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                            }

                            Image {
                                anchors.fill: parent
                                source: "file://" + picker.wallpaperDir + "/" + delegate.modelData
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                sourceSize.width: parent.width * Screen.devicePixelRatio
                                sourceSize.height: parent.height * Screen.devicePixelRatio
                            }
                        }

                        // Círculo de selección: anillo + tic (el tic en el color
                        // de fondo para que contraste con el acento del círculo).
                        Item {
                            visible: delegate.isCurrent
                            scale: delegate.isCurrent ? 1 : 0
                            Behavior on scale {
                                NumberAnimation { duration: 150; easing.type: Easing.OutBack }
                            }
                            anchors.top: imageRect.top
                            anchors.right: imageRect.right
                            anchors.margins: 6
                            width: 28
                            height: 28

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Settings.accent
                                border {
                                    width: 2
                                    color: Settings.bg
                                }
                            }

                            SymbolicIcon {
                                anchors.centerIn: parent
                                path: Icons.check
                                color: Settings.bg
                                implicitSize: 14
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 2
                            height: 28
                            radius: 0
                            color: delegate.isCurrent ? Settings.accent : Settings.scrim
                            visible: delegate.modelData !== undefined

                            Text {
                                anchors.centerIn: parent
                                color: delegate.isCurrent ? Settings.bg : Settings.fg
                                font.family: Settings.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                text: (delegate.isCurrent ? "Actual · " : "") + (delegate.modelData || "")
                                elide: Text.ElideMiddle
                                width: parent.width - 12
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                picker.currentIndex = delegate.index;
                                picker.applyWallpaper();
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Settings.surface
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                color: Settings.subtext0
                font.family: Settings.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                text: "h/l navegar · Enter aplicar · Esc cerrar"
            }
        }
    }

    Item {
        id: escCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                picker.visible = false;
                event.accepted = true;
            } else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
                if (picker.currentIndex > 0) picker.currentIndex--;
                event.accepted = true;
            } else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
                if (picker.currentIndex < scanner.count - 1) picker.currentIndex++;
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                picker.applyWallpaper();
                event.accepted = true;
            }
        }
    }
}
