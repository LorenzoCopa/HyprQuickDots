// ─── Sección de tema de aplicaciones (GTK + Qt) ─────────────────────
// Tres modos: Claro / Oscuro / Sistema. Delega la aplicación en
// scripts/set-theme.sh: GTK vía gsettings y Qt vía el color-scheme del
// xdg-desktop-portal (QT_QPA_PLATFORMTHEME=xdgdesktopportal).

pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import "../config"

Item {
    id: root

    anchors.fill: parent

    readonly property string scriptPath: "$HOME/.config/quickshell/scripts/set-theme.sh"
    property string mode: "dark"

    function setMode(m: string): void {
        if (m === root.mode)
            return;
        root.mode = m;
        applyProc.command = ["sh", "-c", scriptPath + " " + m];
        applyProc.running = true;
    }

    function refresh(): void {
        getProc.running = true;
    }

    Process {
        id: applyProc
        command: ["sh", "-c", scriptPath + " dark"]
        running: false
    }

    Process {
        id: getProc
        command: ["sh", "-c", scriptPath + " get"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var value = text.trim();
                if (value === "dark" || value === "light" || value === "system")
                    root.mode = value;
            }
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 10

        Text {
            text: "Tema de aplicaciones"
            color: Settings.fg
            font.family: Settings.fontFamily
            font.pixelSize: 15
            font.weight: Font.Bold
        }

        Text {
            text: "Se aplica a apps GTK y Qt. La mayoría cambia al instante."
            color: Settings.subtext0
            font.family: Settings.fontFamily
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        Row {
            spacing: 8

            Repeater {
                model: [
                    { label: "Claro",   value: "light" },
                    { label: "Oscuro",  value: "dark" },
                    { label: "Sistema", value: "system" },
                ]

                delegate: Item {
                    required property var modelData
                    width: 92
                    height: 40

                    Rectangle {
                        id: bg
                        anchors.fill: parent
                        radius: 10
                        color: root.mode === modelData.value ? Settings.selectionBg : Settings.surface
                        Behavior on color { ColorAnimation { duration: Settings.animationFast } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: Settings.fg
                            font.family: Settings.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setMode(modelData.value)
                    }
                }
            }
        }

        Text {
            text: "Si alguna app Qt no se actualiza, ciérrala y ábrela de nuevo."
            color: Settings.subtext0
            font.family: Settings.fontFamily
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }
    }

    Component.onCompleted: root.refresh()
}
