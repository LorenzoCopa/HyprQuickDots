pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../config"
import "WidgetShell.qml"

// Tarjeta de la tarjeta gráfica (AMD): uso, VRAM, temperatura y consumo.
// Lee los sysfs de amdgpu (gpu_busy_percent + mem_info_vram_*) y los
// sensores del driver (junction/edge) con `Process` periódico, mismo
// patrón que SystemWidget. La tarjeta AMD se detecta dinámicamente
// recorriendo /sys/class/drm/card* buscando gpu_busy_percent.
WidgetShell {
    id: gpuWidget
    title: "GPU"

    // ── Lectura periódica ──
    // Solo sondea mientras el panel está visible (`panelActive` lo inyecta
    // QuickAccess.qml): lectura inmediata al abrir y cada 2s después. Con
    // el panel cerrado no se lanza ningún proceso (antes eran ~30 forks/min
    // de sensors+jq aunque nadie mirara la tarjeta).
    property bool panelActive: false

    property real gpuPct: 0
    property string vramUsed: "--"
    property string vramTotal: "--"
    property real vramPct: 0
    property string temp: "--"
    property string power: "--"

    Process {
        id: gpuProc
        command: ["sh", "-c",
            // Localiza la tarjeta AMD (la que expone gpu_busy_percent).
            "card=\"\"; for c in /sys/class/drm/card*; do " +
            "[ -f \"$c/device/gpu_busy_percent\" ] && { card=\"$c\"; break; }; done; " +
            "[ -n \"$card\" ] || exit 0; d=\"$card/device\"; " +
            "g=$(cat \"$d/gpu_busy_percent\"); " +
            "vu=$(cat \"$d/mem_info_vram_used\" 2>/dev/null); vt=$(cat \"$d/mem_info_vram_total\" 2>/dev/null); " +
            "a=$(sensors -j 2>/dev/null | jq -r 'to_entries[] | select(.key|startswith(\"amdgpu\")) | .value'); " +
            "tj=$(echo \"$a\" | jq -r '.junction.temp2_input // .edge.temp1_input // empty'); tj=${tj%.*}; " +
            "pw=$(echo \"$a\" | jq -r '.PPT.power1_average // empty'); pw=${pw%.*}; " +
            "echo \"gpu=$g vu=$vu vt=$vt tj=$tj pw=$pw\""]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(" ");
                for (let i = 0; i < parts.length; i++) {
                    const kv = parts[i].split("=");
                    if (kv.length !== 2) continue;
                    if (kv[0] === "gpu") gpuWidget.gpuPct = Number(kv[1]);
                    else if (kv[0] === "vu") {
                        const vb = Number(kv[1]);
                        gpuWidget.vramUsed = vb > 0 ? (vb / 1073741824).toFixed(1) : "--";
                    } else if (kv[0] === "vt") {
                        const tb = Number(kv[1]);
                        gpuWidget.vramTotal = tb > 0 ? (tb / 1073741824).toFixed(1) : "--";
                        if (tb > 0 && gpuWidget.vramUsed !== "--")
                            gpuWidget.vramPct = Number(gpuWidget.vramUsed) / Number(gpuWidget.vramTotal) * 100;
                    } else if (kv[0] === "tj") gpuWidget.temp = kv[1];
                    else if (kv[0] === "pw") gpuWidget.power = kv[1];
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: gpuWidget.panelActive
        repeat: true
        onTriggered: {
            gpuProc.running = false;
            gpuProc.running = true;
        }
    }
    // Lectura inmediata al abrir el panel.
    onPanelActiveChanged: {
        if (gpuWidget.panelActive) {
            gpuProc.running = false;
            gpuProc.running = true;
        }
    }

    // ── Barra de progreso reutilizable ──
    component PctBar: Item {
        required property real pct
        property color fillColor: Settings.accent
        height: 3
        Rectangle {
            anchors.fill: parent
            radius: 1
            color: Settings.surface
        }
        Rectangle {
            anchors.left: parent.left
            width: parent.width * parent.pct / 100
            height: parent.height
            radius: 1
            color: parent.fillColor
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }
    }

    // ── Celda: etiqueta + valor (opcionalmente con barra) ──
    component MetricCell: ColumnLayout {
        required property string label
        required property string value
        property real pct: -1
        property color valueColor: Settings.fg
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                text: parent.parent.label
                color: Settings.muted
                font.family: Settings.fontFamily
                font.pixelSize: 9
            }
            Item { Layout.fillWidth: true }
            Text {
                text: parent.parent.value
                color: parent.parent.valueColor
                font.family: Settings.fontFamily
                font.pixelSize: 10
                font.weight: Font.Bold
            }
        }
        PctBar {
            visible: parent.pct >= 0
            pct: parent.pct
            Layout.fillWidth: true
            fillColor: parent.valueColor === Settings.red ? Settings.red : Settings.accent
        }
    }

    // ── Contenido: mini-rejilla 2×2 (Uso | Temp / VRAM | Consumo) ──
    // Compacta para que la tarjeta quede al ras con el resto del mosaico:
    // dos columnas de dos métricas, sin ocupar más alto que Clima.
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 8
        rowSpacing: 6

        MetricCell {
            label: "Uso"
            value: gpuWidget.gpuPct + "%"
            pct: gpuWidget.gpuPct
        }
        MetricCell {
            label: "Temp"
            value: gpuWidget.temp !== "--" ? gpuWidget.temp + "°" : "--"
            valueColor: gpuWidget.temp >= 90 ? Settings.red : Settings.fg
        }
        MetricCell {
            label: "VRAM"
            value: gpuWidget.vramUsed + "/" + gpuWidget.vramTotal
            pct: gpuWidget.vramPct
        }
        MetricCell {
            label: "Consumo"
            value: gpuWidget.power !== "--" ? gpuWidget.power + " W" : "--"
            // El consumo es la potencia eléctrica instantánea de la GPU (PPT,
            // media en vatios) — no VRAM ni nada más.
        }
    }

    Text {
        visible: gpuWidget.power !== "--"
        text: "potencia eléctrica media"
        color: Settings.muted
        font.family: Settings.fontFamily
        font.pixelSize: 9
        elide: Text.ElideRight
        Layout.fillWidth: true
    }
}
