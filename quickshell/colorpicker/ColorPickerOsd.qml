// ─── OSD selector de color ────────────────────────────────────────────
// Muestra el color elegido con hyprpicker y sus códigos (hex / rgb / hsl)
// con botones para copiarlos al portapapeles. Es un FloatingWindow centrado
// en el monitor con foco; se cierra con ESC, click fuera o auto-hide.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../config"

FloatingWindow {
    id: root
    title: "qs-colorpicker"
    color: "transparent"
    implicitWidth: 420
    implicitHeight: 192
    visible: false

    readonly property int autoHideMs: 12000
    readonly property string monoFont: "JetBrainsMono Nerd Font Mono"

    property string hexColor: ""

    readonly property var rgb: root.hexColor ? root.hexToRgb(root.hexColor) : [0, 0, 0]
    readonly property var hsl: root.hexColor ? root.rgbToHsl(root.rgb[0], root.rgb[1], root.rgb[2]) : [0, 0, 0]
    readonly property string rgbText: "rgb(" + root.rgb[0] + ", " + root.rgb[1] + ", " + root.rgb[2] + ")"
    readonly property string hslText: "hsl(" + root.hsl[0] + ", " + root.hsl[1] + "%, " + root.hsl[2] + "%)"

    // "hex" | "rgb" | "hsl" | "" — qué formato se acaba de copiar
    property string copiedFormat: ""

    function hexToRgb(h) {
        var s = h.replace("#", "");
        if (s.length === 3)
            s = s[0] + s[0] + s[1] + s[1] + s[2] + s[2];
        return [parseInt(s.substr(0, 2), 16), parseInt(s.substr(2, 2), 16), parseInt(s.substr(4, 2), 16)];
    }

    function rgbToHsl(r, g, b) {
        r /= 255; g /= 255; b /= 255;
        var max = Math.max(r, g, b), min = Math.min(r, g, b);
        var h = 0, s = 0, l = (max + min) / 2;
        if (max !== min) {
            var d = max - min;
            s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
            if (max === r) h = (g - b) / d + (g < b ? 6 : 0);
            else if (max === g) h = (b - r) / d + 2;
            else h = (r - g) / d + 4;
            h /= 6;
        }
        return [Math.round(h * 360), Math.round(s * 100), Math.round(l * 100)];
    }

    function copyFormat(fmt) {
        var text = fmt === "rgb" ? root.rgbText : fmt === "hsl" ? root.hslText : root.hexColor;
        var escaped = text.replace(/'/g, "'\\''");
        copyProc.command = ["sh", "-c", "printf '%s' '" + escaped + "' | wl-copy"];
        copyProc.running = true;
        root.copiedFormat = fmt;
        copiedTimer.restart();
    }

    function hide() {
        root.visible = false;
    }

    onVisibleChanged: {
        if (visible) {
            Qt.callLater(function () { keyCatcher.forceActiveFocus(); });
            autoHide.restart();
        }
    }

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: root.visible = false
    }

    // Sobre un juego fullscreen el foco inicial puede quedarse en el juego
    // (constraint del puntero); pedirlo por dispatcher rompe el bloqueo.
    SelfFocus {
        targetTitle: "qs-colorpicker"
        active: root.visible
    }

    Timer {
        id: autoHide
        interval: root.autoHideMs
        onTriggered: root.visible = false
    }

    Timer {
        id: copiedTimer
        interval: 1500
        onTriggered: root.copiedFormat = ""
    }

    Process {
        id: copyProc
        running: false
    }

    Rectangle {
        anchors.fill: parent
        color: Settings.bg
        radius: 14

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            // ── Muestra del color + códigos ───────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 18

                Rectangle {
                    id: swatch
                    Layout.preferredWidth: 92
                    Layout.preferredHeight: 92
                    Layout.alignment: Qt.AlignVCenter
                    radius: 12
                    color: root.hexColor
                    border {
                        width: 1
                        color: Settings.surface
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 3

                    Text {
                        Layout.fillWidth: true
                        text: root.hexColor
                        color: Settings.fg
                        font.family: root.monoFont
                        font.pixelSize: 26
                        font.weight: Font.Bold
                        font.letterSpacing: 1
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.rgbText
                        color: Settings.subtext0
                        font.family: Settings.fontFamily
                        font.pixelSize: 12
                        font.letterSpacing: 0.3
                        horizontalAlignment: Text.AlignLeft
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.hslText
                        color: Settings.subtext0
                        font.family: Settings.fontFamily
                        font.pixelSize: 12
                        font.letterSpacing: 0.3
                        horizontalAlignment: Text.AlignLeft
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    Layout.alignment: Qt.AlignTop
                    radius: 8
                    color: closeMouse.containsMouse ? Settings.selectionBg : "transparent"
                    Behavior on color { ColorAnimation { duration: 80 } }

                    SymbolicIcon {
                        anchors.centerIn: parent
                        path: Icons.close
                        color: Settings.muted
                        implicitSize: 13
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: root.hide()
                    }
                }
            }

            // ── Botones de copiar ─────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [
                        { fmt: "hex", label: "HEX" },
                        { fmt: "rgb", label: "RGB" },
                        { fmt: "hsl", label: "HSL" },
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        id: copyBtn
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: 10
                        color: btnMouse.containsMouse
                            ? (copyBtn.modelData.fmt === root.copiedFormat ? Qt.alpha(Settings.green, 0.15) : Settings.selectionBg)
                            : (copyBtn.modelData.fmt === root.copiedFormat ? Qt.alpha(Settings.green, 0.12) : Settings.surface)
                        Behavior on color { ColorAnimation { duration: 80 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 7

                            SymbolicIcon {
                                path: copyBtn.modelData.fmt === root.copiedFormat ? Icons.check : Icons.copy
                                color: copyBtn.modelData.fmt === root.copiedFormat ? Settings.green : Settings.fg
                                implicitSize: 13
                            }

                            Text {
                                text: copyBtn.modelData.label
                                color: copyBtn.modelData.fmt === root.copiedFormat ? Settings.green : Settings.fg
                                font.family: Settings.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 1
                            }
                        }

                        MouseArea {
                            id: btnMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.copyFormat(copyBtn.modelData.fmt)
                        }
                    }
                }
            }
        }
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                root.hide();
                event.accepted = true;
            }
        }
    }
}