pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "../../config"
import "WidgetShell.qml"

// Panel del sistema: CPU, memoria, temperatura, carga y la bandeja del
// sistema integrada al final de la tarjeta (iconos de aplicaciones
// residentes con menú contextual, mismos clics que TrayButton). Lee /proc
// y sensors con `Process` periódico (mismo patrón que hyprctl en
// QuickAccess). Emite un único bloque de texto que se parsea aquí.
WidgetShell {
    id: sysWidget
    title: "Sistema"

    // El anchor del menú contextual del tray; expuesto para que el
    // HyprlandFocusGrab del QuickAccess sepa cuándo está abierto.
    property alias trayContextMenu: trayMenu
    // Ventana contenedora (FloatingWindow del QuickAccess), inyectada
    // desde QuickAccess.qml: el `window` mágico no resuelve dentro del
    // scope de este componente.
    property var anchorWindow: null

    // ── Lectura periódica ──
    // Solo sondea mientras el panel está visible (`panelActive` lo inyecta
    // QuickAccess.qml con `quickAccess.visible`): al abrir se lanza una
    // lectura inmediata y de ahí en adelante cada 3s. Con el panel cerrado
    // no se lanza NINGÚN proceso (antes eran ~20 forks/min de sh+awk+
    // sensors+jq aunque nadie mirara la tarjeta).
    property bool panelActive: false

    property real cpuPct: 0
    property real ramPct: 0
    property string ramUsed: "--"
    property string ramTotal: "--"
    property string temp: "--"

    Process {
        id: sysProc
        command: ["sh", "-c",
            // Dos lecturas de /proc/stat separadas 0.4s; awk suma total e idle.
            "u1=$(awk '/^cpu /{s=0; for(i=2;i<=8;i++) s+=$i; print s, $5+$6}' /proc/stat); " +
            "sleep 0.4; " +
            "u2=$(awk '/^cpu /{s=0; for(i=2;i<=8;i++) s+=$i; print s, $5+$6}' /proc/stat); " +
            "set -- $u1; t1=$1; i1=$2; set -- $u2; t2=$1; i2=$2; " +
            "dt=$((t2-t1)); di=$((i2-i1)); [ $dt -gt 0 ] && echo \"cpu=$(( (dt-di)*100/dt ))\"; " +
            "m=$(grep -E 'MemTotal|MemAvailable' /proc/meminfo | awk '{print $2}'); " +
            "mt=$(echo \"$m\" | head -1); ma=$(echo \"$m\" | tail -1); " +
            "echo \"ram=$(( (mt-ma)*100/mt )) " +
            "ramU=$(awk -v x=$((mt-ma)) 'BEGIN{printf \"%.1f\", x/1048576}') " +
            "ramT=$(awk -v x=$mt 'BEGIN{printf \"%.1f\", x/1048576}')\"; " +
            "t=$(sensors -j 2>/dev/null | jq -r '.. | .temp1_input? // empty' | head -1); " +
            "[ -n \"$t\" ] && echo \"temp=${t%.*}\""]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split(" ");
                    for (let j = 0; j < parts.length; j++) {
                        const kv = parts[j].split("=");
                        if (kv.length !== 2) continue;
                        if (kv[0] === "cpu") sysWidget.cpuPct = Number(kv[1]);
                        else if (kv[0] === "ram") sysWidget.ramPct = Number(kv[1]);
                        else if (kv[0] === "ramU") sysWidget.ramUsed = kv[1];
                        else if (kv[0] === "ramT") sysWidget.ramTotal = kv[1];
                        else if (kv[0] === "temp") sysWidget.temp = kv[1];
                    }
                }
            }
        }
    }

    Timer {
        interval: 3000
        running: sysWidget.panelActive
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            sysProc.running = false;
            sysProc.running = true;
        }
    }
    // Refresco inmediato al abrir el panel (los datos no envejecen aunque
    // estuviera cerrado un rato).
    onPanelActiveChanged: {
        if (sysWidget.panelActive) {
            sysProc.running = false;
            sysProc.running = true;
        }
    }

    // ── Barra de progreso reutilizable ──
    component PctBar: Item {
        required property real pct
        property color fillColor: Settings.accent
        height: 4
        Rectangle {
            anchors.fill: parent
            radius: 2
            color: Settings.surface
        }
        Rectangle {
            anchors.left: parent.left
            width: parent.width * parent.pct / 100
            height: parent.height
            radius: 2
            color: parent.fillColor
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }
    }

    // ── Fila: etiqueta + valor ──
    component MetricRow: Item {
        required property string label
        required property string value
        height: 14
        RowLayout {
            anchors.fill: parent
            spacing: 6
            Text {
                text: parent.parent.label
                color: Settings.muted
                font.family: Settings.fontFamily
                font.pixelSize: 10
            }
            Item { Layout.fillWidth: true }
            Text {
                text: parent.parent.value
                color: Settings.fg
                font.family: Settings.fontFamily
                font.pixelSize: 10
                font.weight: Font.Bold
            }
        }
    }

    // ── Contenido ──
    MetricRow { label: "CPU"; value: sysWidget.cpuPct + "%" }
    PctBar { pct: sysWidget.cpuPct; Layout.fillWidth: true }

    MetricRow { label: "RAM"; value: sysWidget.ramUsed + " / " + sysWidget.ramTotal + " GiB" }
    PctBar { pct: sysWidget.ramPct; Layout.fillWidth: true }

    MetricRow {
        label: "Temp."
        value: (sysWidget.temp !== "--" ? sysWidget.temp + "°" : "--")
    }
    PctBar {
        pct: sysWidget.temp !== "--" ? Math.min(100, sysWidget.temp / 100 * 100) : 0
        fillColor: sysWidget.temp >= 80 ? Settings.red : Settings.accent
        Layout.fillWidth: true
    }

    // ── Bandeja del sistema (integrada al final de la tarjeta) ──
    // Separador sutil + iconos de las aplicaciones residentes, con el
    // mismo menú contextual (QsMenuAnchor) y clics que TrayButton: izquierdo
    // activa, derecho abre menú, medio acción secundaria y rueda scroll.
    Item {
        Layout.fillWidth: true
        height: 1
        Rectangle {
            anchors.fill: parent
            color: Settings.surface
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: "Bandeja"
            color: Settings.muted
            font.family: Settings.fontFamily
            font.pixelSize: 10
            font.weight: Font.Bold
        }

        Flow {
            Layout.fillWidth: true
            spacing: 4

            Text {
                visible: SystemTray.items.length === 0
                text: "Sin iconos"
                color: Settings.muted
                font.family: Settings.fontFamily
                font.pixelSize: 10
            }

            Repeater {
                model: SystemTray.items

                delegate: Item {
                    required property SystemTrayItem modelData
                    width: 28
                    height: 28

                    Rectangle {
                        anchors.fill: parent
                        radius: 7
                        color: trayMouse.containsMouse ? Settings.selectionBg : Settings.surface
                        Behavior on color { ColorAnimation { duration: 80 } }
                    }

                    Image {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        source: modelData.icon
                        sourceSize { width: 18; height: 18 }
                        asynchronous: true
                        fillMode: Image.PreserveAspectFit
                    }

                    MouseArea {
                        id: trayMouse
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                if (modelData.hasMenu) {
                                    const iconPos = trayMouse.mapToItem(
                                        sysWidget.anchorWindow.contentItem,
                                        trayMouse.width / 2,
                                        trayMouse.height
                                    );
                                    trayMenu.anchor.rect.x = Math.round(iconPos.x);
                                    trayMenu.anchor.rect.y = Math.round(iconPos.y + 6);
                                    trayMenu.menu = modelData.menu;
                                    trayMenu.open();
                                }
                            } else if (mouse.button === Qt.LeftButton) {
                                modelData.activate();
                            } else if (mouse.button === Qt.MiddleButton) {
                                modelData.secondaryActivate();
                            }
                        }

                        onWheel: wheelEvent => {
                            const delta = wheelEvent.angleDelta.y || wheelEvent.angleDelta.x;
                            const horiz = Math.abs(wheelEvent.angleDelta.x) > Math.abs(wheelEvent.angleDelta.y);
                            modelData.scroll(delta, horiz);
                        }
                    }
                }
            }
        }
    }

    QsMenuAnchor {
        id: trayMenu
        anchor.window: sysWidget.anchorWindow
    }
}