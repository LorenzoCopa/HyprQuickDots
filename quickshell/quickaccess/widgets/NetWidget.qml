pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../config"
import "WidgetShell.qml"

// Velocidad de red real (descarga/subida en vivo). Muestreo continuo:
// cada tick lee /proc/net/dev una vez y mide el delta contra la lectura
// anterior (la ventana completa entre ticks; antes el proceso dormía 1s
// dentro del timer de 2s y la mitad del tiempo quedaba sin medir). Por
// debajo de 1 Mbps se muestra en KB/s: con un decimal fijo en Mbps el
// tráfico de reposo (unos pocos KB/s) siempre pintaba "0.0". Con
// `stretch: true` la tarjeta se estira hasta el borde inferior de su
// contenedor. Solo muestrea mientras el panel está visible (`panelActive`
// lo inyecta QuickAccess.qml con `quickAccess.visible`).
WidgetShell {
    id: netWidget
    title: "Red"

    property bool panelActive: false

    // Lectura anterior de contadores (-1 = aún sin muestra) para el delta.
    property real prevRx: -1
    property real prevTx: -1
    property real lastMs: 0

    readonly property string downText: speedParts(downMbps)[0]
    readonly property string downUnit: speedParts(downMbps)[1]
    readonly property string upText: speedParts(upMbps)[0]
    readonly property string upUnit: speedParts(upMbps)[1]

    property real downMbps: 0
    property real upMbps: 0

    // ≥1 Mbps → "X.X" + "Mbps"; debajo → KB/s (1 Mbps = 125 KB/s decimales).
    function speedParts(mbps) {
        if (mbps >= 1)
            return [mbps.toFixed(1), "Mbps"];
        const kbs = mbps * 125;
        return [kbs >= 100 ? kbs.toFixed(0) : kbs.toFixed(1), "KB/s"];
    }

    Process {
        id: netProc
        command: ["sh", "-c",
            "awk 'NR>2 && $1!=\"lo:\"{rx+=$2; tx+=$10} END{print rx+0, tx+0}' /proc/net/dev"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(" ");
                if (parts.length < 2)
                    return;
                const rx = Number(parts[0]);
                const tx = Number(parts[1]);
                const now = Date.now();
                if (netWidget.prevRx >= 0 && now > netWidget.lastMs) {
                    const secs = (now - netWidget.lastMs) / 1000;
                    // Un contador que se resetea (iface caída/reinicio) da
                    // delta negativo: se satura a 0 y resincroniza.
                    netWidget.downMbps = Math.max(0, rx - netWidget.prevRx) * 8 / secs / 1e6;
                    netWidget.upMbps = Math.max(0, tx - netWidget.prevTx) * 8 / secs / 1e6;
                }
                netWidget.prevRx = rx;
                netWidget.prevTx = tx;
                netWidget.lastMs = now;
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: netWidget.panelActive
        triggeredOnStart: true
        onTriggered: {
            netProc.running = false;
            netProc.running = true;
        }
    }

    // ── Contenido ──
    Row {
        Layout.alignment: Qt.AlignHCenter
        spacing: 6

        SymbolicIcon {
            path: Icons.arrowDown
            color: Settings.accent
            implicitSize: 16
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: netWidget.downText
            color: Settings.fg
            font.family: Settings.fontFamily
            font.pixelSize: 18
            font.weight: Font.Bold
        }

        Text {
            text: netWidget.downUnit
            color: Settings.muted
            font.family: Settings.fontFamily
            font.pixelSize: 10
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Row {
        Layout.alignment: Qt.AlignHCenter
        spacing: 6

        SymbolicIcon {
            path: Icons.arrowUp
            color: Settings.muted
            implicitSize: 16
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: netWidget.upText
            color: Settings.fg
            font.family: Settings.fontFamily
            font.pixelSize: 18
            font.weight: Font.Bold
        }

        Text {
            text: netWidget.upUnit
            color: Settings.muted
            font.family: Settings.fontFamily
            font.pixelSize: 10
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}