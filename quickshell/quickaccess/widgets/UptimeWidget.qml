pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../config"
import "WidgetShell.qml"

// Tiempo de uso del sistema (uptime desde el arranque) + hora de arranque.
// Lee /proc/uptime y who -b (fecha/hora de inicio, los dos últimos campos
// para ser independiente del locale) y muestra el uptime en "Xh Ym" (sin
// días: la máquina apenas supera las 24h de encendido) junto a cuándo se
// encendió. Si el uptime empieza desde 0 y la hora de arranque es reciente,
// el apagado anterior fue correcto (el equipo llegó a apagarse del todo).
//
// Solo muestrea mientras el panel está visible (`panelActive` lo inyecta
// QuickAccess.qml con `quickAccess.visible`): el texto se actualiza cada
// segundo con un Timer ligero de QML (sin lanzar procesos), y el proceso de
// /proc/uptime solo se lanza al abrir y cada 30s para resincronizar.
WidgetShell {
    id: upWidget
    title: "Tiempo"

    property bool panelActive: false
    property string uptimeText: "--"
    property string bootText: ""
    // Momento (epoch ms de reloj) al que corresponde el arranque; desde ahí
    // el timer de 1s deriva el uptime sin procesos.
    property real bootEpochMs: 0

    function fmtUptime(sec) {
        // Entero: el timer de 1s pasa un float (Date.now() - bootEpochMs) y
        // sin floor el %60 mostraba decimales ("35.71", "0.000..."). Siempre
        // se muestran horas, minutos y segundos para no saltar de formato.
        const s = Math.floor(sec);
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        return h + "h " + m + "m " + (s % 60) + "s";
    }

    function fmtBoot(epochSec) {
        const d = new Date(epochSec * 1000);
        const now = new Date();
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const bootDay = new Date(d.getFullYear(), d.getMonth(), d.getDate());
        const diffDays = Math.round((today - bootDay) / 86400000);
        const hh = ("0" + d.getHours()).slice(-2);
        const mm = ("0" + d.getMinutes()).slice(-2);
        let when = "encendido ";
        if (diffDays === 0)
            when += "hoy";
        else if (diffDays === 1)
            when += "ayer";
        else
            when += d.toLocaleDateString("es-ES", { day: "numeric", month: "short" });
        return when + " " + hh + ":" + mm;
    }

    function updateUptimeText() {
        if (upWidget.bootEpochMs > 0)
            upWidget.uptimeText = upWidget.fmtUptime((Date.now() - upWidget.bootEpochMs) / 1000);
    }

    Process {
        id: uptimeProc
        command: ["sh", "-c",
            "u=$(awk '{print int($1)}' /proc/uptime); " +
            "b=$(date +%s -d \"$(who -b | awk '{print $(NF-1)\" \"$NF}')\" 2>/dev/null); " +
            "echo \"$u $b\""]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(" ");
                if (p.length >= 1 && p[0] !== "") {
                    upWidget.bootEpochMs = Date.now() - Number(p[0]) * 1000;
                    upWidget.updateUptimeText();
                    const boot = Number(p.length >= 2 ? p[1] : NaN);
                    if (!isNaN(boot) && boot > 0)
                        upWidget.bootText = upWidget.fmtBoot(boot);
                }
            }
        }
    }

    // Texto en vivo cada segundo (solo reloj QML, sin procesos).
    Timer {
        interval: 1000
        repeat: true
        running: upWidget.panelActive
        onTriggered: upWidget.updateUptimeText()
    }

    // Resincronización con /proc/uptime: al abrir el panel y cada 30s.
    Timer {
        interval: 30000
        repeat: true
        running: upWidget.panelActive
        triggeredOnStart: true
        onTriggered: {
            uptimeProc.running = false;
            uptimeProc.running = true;
        }
    }

    // ── Contenido ──
    Row {
        Layout.alignment: Qt.AlignHCenter
        spacing: 8

        SymbolicIcon {
            path: Icons.clockOutline
            color: Settings.muted
            implicitSize: 18
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: upWidget.uptimeText
            color: Settings.fg
            font.family: Settings.fontFamily
            font.pixelSize: 16
            font.weight: Font.Bold
        }
    }

    Text {
        Layout.fillWidth: true
        text: upWidget.bootText
        color: Settings.muted
        font.family: Settings.fontFamily
        font.pixelSize: 10
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }
}