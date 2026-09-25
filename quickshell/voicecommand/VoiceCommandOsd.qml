// ─── OSD de comandos de voz ───────────────────────────────────────────
// Indicador flotante que se muestra mientras se graba, transcribe y ejecuta
// un comando de voz con whisper.cpp. Es una superficie layer-shell en la capa
// Overlay (igual patrón que osd/VolumeOsd.qml y dictation/DictationOsd.qml):
// no roba el foco de teclado, así que la app objetivo conserva el foco.
//
// Estados (vcState, gestionado por VoiceCommand.qml):
//   idle      → oculto
//   recording → micrófono pulsante + tiempo + botón "Listo" y "X"
//   thinking  → spinner + "Entendiendo…"
//   executing → spinner rápido + "Ejecutando…"
//   done      → ✓ + comando reconocido + nota de lo ejecutado
//   error     → mensaje de error

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../config"

PanelWindow {
    id: osd
    color: "transparent"
    visible: false

    // ── Capa Overlay: visible sobre ventanas fullscreen, sin foco ──
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-voicecmd"
    WlrLayershell.exclusiveZone: 0

    readonly property int osdWidth: 460

    // Pantalla con foco en ese momento (sigue a dónde estás trabajando).
    readonly property var focusedScreen: {
        const monitors = Quickshell.screens;
        const n = monitors.length;
        if (Hyprland.focusedMonitor) {
            for (let i = 0; i < n; i++) {
                if (monitors[i].name === Hyprland.focusedMonitor.name)
                    return monitors[i];
            }
        }
        return n > 0 ? monitors[0] : null;
    }

    screen: osd.focusedScreen

    anchors {
        bottom: true
        left: true
        right: true
    }

    margins.left: osd.focusedScreen ? Math.max(0, Math.round((osd.focusedScreen.width - osd.osdWidth) / 2)) : 0
    margins.right: osd.focusedScreen ? Math.max(0, Math.round((osd.focusedScreen.width - osd.osdWidth) / 2)) : 0
    margins.bottom: 32

    // ── Estado gestionado desde VoiceCommand.qml ───────────────
    required property string vcState
    required property string elapsedText
    required property string resultText
    required property string resultNote
    // true si el comando forzó el micro encendido (estaba silenciado).
    property bool micForcedOn: false

    signal stopRequested()
    signal cancelRequested()

    // ── Aparición / desaparición ──────────────────────────────────
    function show(): void {
        osd.visible = true;
        fadeOut.stop();
        pill.opacity = 0;
        fadeIn.running = true;
    }

    function hideSoon(): void {
        fadeOut.stop();
        osd.visible = false;
    }

    onVcStateChanged: {
        if (osd.vcState !== "idle")
            osd.show();
        else
            osd.hide();
    }

    NumberAnimation {
        id: fadeIn
        target: pill
        property: "opacity"
        from: 0
        to: 1
        duration: 150
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: fadeOut
        target: pill
        property: "opacity"
        from: 1
        to: 0
        duration: 220
        easing.type: Easing.InQuad
        onFinished: osd.visible = false
    }

    function hide(): void {
        fadeOut.running = true;
    }

    // ── Contenido visual ────────────────────────────────────────
    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        implicitWidth: 460
        implicitHeight: 64
        radius: 32
        color: Settings.bg
        border {
            width: 1
            color: Settings.surface
        }

        layer.enabled: true
        layer.smooth: true

        Row {
            id: row
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            // ── Icono izquierdo (estado) ─────────────────────
            Item {
                width: 36
                height: 36
                anchors.verticalCenter: parent.verticalCenter

                // Anillos pulsantes del micrófono (recording)
                Repeater {
                    model: 2
                    Rectangle {
                        anchors.centerIn: parent
                        width: 36
                        height: 36
                        radius: 18
                        color: "transparent"
                        border {
                            width: 2
                            color: Settings.accent
                        }
                        opacity: 0
                        NumberAnimation on opacity {
                            running: osd.vcState === "recording"
                            from: 0.7
                            to: 0
                            duration: 1400
                            easing.type: Easing.OutCubic
                            loops: Animation.Infinite
                        }
                        NumberAnimation on scale {
                            running: osd.vcState === "recording"
                            from: 1
                            to: 1.8
                            duration: 1400
                            easing.type: Easing.OutCubic
                            loops: Animation.Infinite
                        }
                    }
                }

                // Animación de rotación (thinking/executing = spinner)
                RotationAnimator on rotation {
                    running: osd.vcState === "thinking" || osd.vcState === "executing"
                    from: 0
                    to: 360
                    duration: osd.vcState === "executing" ? 700 : 1200
                    loops: Animation.Infinite
                }

                SymbolicIcon {
                    anchors.centerIn: parent
                    path: osd.vcState === "done" ? Icons.check
                        : osd.vcState === "error" ? Icons.close
                        : Icons.mic
                    color: osd.vcState === "done" ? Settings.green
                        : osd.vcState === "error" ? Settings.red
                        : Settings.accent
                    implicitSize: 22
                }
            }

            // ── Texto central ──────────────────────────────────
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: row.width - 36 - 34 - 12 * (osd.vcState === "recording" ? 3 : 2) - (osd.vcState === "recording" ? 64 : 0)
                spacing: 2

                Text {
                    text: {
                        if (osd.vcState === "recording") return "Escuchando comando…";
                        if (osd.vcState === "thinking") return "Entendiendo…";
                        if (osd.vcState === "executing") return "Ejecutando…";
                        if (osd.vcState === "done") return osd.resultText;
                        if (osd.vcState === "error") return osd.resultText.length > 0 ? osd.resultText : osd.resultNote;
                        return "";
                    }
                    color: Settings.fg
                    font.family: Settings.fontFamily
                    font.pixelSize: osd.vcState === "recording" ? 14 : 13
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    width: parent.width
                }

                Text {
                    visible: osd.vcState !== "recording"
                    text: osd.resultNote
                    color: Settings.subtext0
                    font.family: Settings.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    width: parent.width
                }

                Text {
                    visible: osd.vcState === "recording"
                    text: osd.elapsedText
                    color: Settings.subtext0
                    font.family: Settings.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }

                Text {
                    visible: osd.vcState === "recording" && osd.micForcedOn
                    text: "Micrófono activado para el comando"
                    color: Settings.yellow
                    font.family: Settings.fontFamily
                    font.pixelSize: 10
                    font.italic: true
                }
            }

            // ── Botón "Listo" (recording) ──────────────────────
            Rectangle {
                visible: osd.vcState === "recording"
                anchors.verticalCenter: parent.verticalCenter
                width: 64
                height: 34
                radius: 17
                color: Settings.accent

                Text {
                    anchors.centerIn: parent
                    text: "Listo"
                    color: Settings.bg
                    font.family: Settings.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: osd.stopRequested()
                }
            }

            // ── Botón "X" (cancelar) ───────────────────────────
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                height: 34
                radius: 17
                color: Settings.surface

                SymbolicIcon {
                    anchors.centerIn: parent
                    path: Icons.close
                    color: Settings.subtext0
                    implicitSize: 16
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: osd.cancelRequested()
                }
            }
        }
    }
}