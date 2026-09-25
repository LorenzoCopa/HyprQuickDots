pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../config"
import "WidgetShell.qml"

// Widget de batería: porcentaje, estado (cargando/descargando) y tiempo
// estimado. Hardware-adaptativo: si no hay batería (Settings.hasBattery
// false) el contenedor en QuickAccess lo oculta total (height 0).
WidgetShell {
    id: batWidget
    title: "Batería"

    // Solo sondea mientras el panel está visible (`panelActive` lo inyecta
    // QuickAccess.qml): lectura inmediata al abrir y cada 8s después (el
    // tick lanza upower, nada barato, mejor no hacerlo en segundo plano).
    property bool panelActive: false
    property bool hasBattery: Settings.hasBattery
    property int pct: 0
    property string state: "--" // charging/discharging/full
    property string timeText: "--"

    Process {
        id: batProc
        command: ["sh", "-c", "p=$(ls /sys/class/power_supply/BAT* 2>/dev/null | head -n1); [ -z \"$p\" ] && exit 1; cap=$(cat $p/capacity 2>/dev/null); st=$(cat $p/status 2>/dev/null); echo \"cap=$cap st=$st\"; upower -i $(upower -e 2>/dev/null | grep BAT | head -n1) 2>/dev/null | grep -E 'time to|percentage' | head -n2 | tr '\\n' ' ' | sed 's/.*time to[^:]*: *//;s/percentage.*//g' | xargs; echo \"\""]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const txt = text.trim();
                const mCap = txt.match(/cap=([0-9]+)/);
                const mSt = txt.match(/st=([A-Za-z]+)/);
                if (mCap) batWidget.pct = parseInt(mCap[1], 10);
                if (mSt) batWidget.state = mSt[1].toLowerCase();
                // time queda en txt si upower lo dio
                const mTime = txt.match(/([0-9]+[.,]?[0-9]*\s*h[^\\n]*)/);
                if (mTime) batWidget.timeText = mTime[1].trim();
                else batWidget.timeText = batWidget.state === "charging" ? "Cargando" : batWidget.state === "discharging" ? "En uso" : batWidget.state === "full" ? "Completa" : "--";
            }
        }
    }
    Timer {
        interval: 8000
        running: batWidget.hasBattery && batWidget.panelActive
        repeat: true
        onTriggered: { batProc.running = false; batProc.running = true; }
    }
    // Lectura inmediata al abrir el panel.
    onPanelActiveChanged: {
        if (hasBattery && panelActive) {
            batProc.running = false;
            batProc.running = true;
        }
    }
    onHasBatteryChanged: if (hasBattery && panelActive) batProc.running = true

    // si no hay batería, no mostrar nada (el wrapper en QuickAccess lo oculta, pero aquí también)
    visible: hasBattery

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            SymbolicIcon {
                path: batWidget.state === "charging" ? Icons.batteryCharging : Icons.battery
                color: batWidget.pct < 20 && batWidget.state !== "charging" ? Settings.red : Settings.accent
                implicitSize: 16
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                text: batWidget.pct + "%"
                color: Settings.fg
                font.family: Settings.fontFamily
                font.pixelSize: 14
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                text: "· " + batWidget.state
                color: Settings.muted
                font.family: Settings.fontFamily
                font.pixelSize: 11
                Layout.alignment: Qt.AlignVCenter
                visible: batWidget.state !== "--"
            }
            Item { Layout.fillWidth: true }
            Text {
                text: batWidget.timeText
                color: Settings.muted
                font.family: Settings.fontFamily
                font.pixelSize: 10
                Layout.alignment: Qt.AlignVCenter
                visible: batWidget.timeText !== "--"
                elide: Text.ElideRight
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 4
            radius: 2
            color: Settings.surface
            Rectangle {
                anchors.left: parent.left
                width: parent.width * Math.max(0, Math.min(1, batWidget.pct / 100))
                height: parent.height
                radius: parent.radius
                color: batWidget.pct < 20 && batWidget.state !== "charging" ? Settings.red : Settings.accent
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            }
        }
    }
}
