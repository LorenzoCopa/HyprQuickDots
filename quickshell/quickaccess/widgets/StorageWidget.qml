pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../config"
import "WidgetShell.qml"

// Almacenamiento: uso de los dispositivos reales (df, excluye los fs
// virtuales). Muestra cada partición con su barra de uso.
WidgetShell {
    id: storageWidget
    title: "Almacenamiento"

    // Solo sondea mientras el panel está visible (`panelActive` lo inyecta
    // QuickAccess.qml): lectura inmediata al abrir y cada 30s después.
    property bool panelActive: false

    property var mounts: []

    Process {
        id: dfProc
        command: ["sh", "-c",
            "df -hP -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs 2>/dev/null | tail -n +2 | " +
            "awk '{seen[$1]++} seen[$1]==1 || $6 ~ /^\\/run\\/media\\// {print $6, $3, $5}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                const lines = text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const p = lines[i].trim().split(/\s+/);
                    if (p.length < 3) continue;
                    const pct = parseInt(p[2].replace("%", ""), 10);
                    if (!Number.isFinite(pct)) continue;
                    // Muestra el punto de montaje raíz por dispositivo (la
                    // raíz primero) y cada medio extraíble por separado.
                    let label = p[0];
                    if (label.indexOf("/run/media/") === 0)
                        label = label.replace(/^.*\//, "");
                    list.push({ mount: label, pct: pct, used: p[1] });
                }
                // Ordena: la raíz primero, luego el resto alfabético.
                list.sort((a, b) => (b.mount === "/") - (a.mount === "/") || a.mount.localeCompare(b.mount));
                storageWidget.mounts = list;
            }
        }
    }

    Timer {
        interval: 30000
        running: storageWidget.panelActive
        repeat: true
        onTriggered: {
            dfProc.running = false;
            dfProc.running = true;
        }
    }
    // Lectura inmediata al abrir el panel.
    onPanelActiveChanged: {
        if (storageWidget.panelActive) {
            dfProc.running = false;
            dfProc.running = true;
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: storageWidget.mounts.length > 0

        Repeater {
            model: storageWidget.mounts

            delegate: ColumnLayout {
                id: mountDel
                required property var modelData
                readonly property string mountName: mountDel.modelData.mount
                readonly property int mountPct: mountDel.modelData.pct
                readonly property string mountUsed: mountDel.modelData.used

                Layout.fillWidth: true
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        text: mountDel.mountName
                        color: Settings.muted
                        font.family: Settings.fontFamily
                        font.pixelSize: 10
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: mountDel.mountUsed + " · " + mountDel.mountPct + "%"
                        color: Settings.fg
                        font.family: Settings.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                }

                Item {
                    Layout.fillWidth: true
                    height: 4
                    Rectangle {
                        anchors.fill: parent
                        radius: 2
                        color: Settings.surface
                    }
                    Rectangle {
                        anchors.left: parent.left
                        width: parent.width * mountDel.mountPct / 100
                        height: parent.height
                        radius: 2
                        color: mountDel.mountPct >= 90 ? Settings.red : Settings.accent
                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }

    Text {
        visible: storageWidget.mounts.length === 0
        text: "Sin dispositivos"
        color: Settings.muted
        font.family: Settings.fontFamily
        font.pixelSize: 10
        Layout.alignment: Qt.AlignHCenter
    }
}