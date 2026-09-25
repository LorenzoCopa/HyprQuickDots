// ─── OSD de dictado por voz ───────────────────────────────────────────
// Indicador flotante que se muestra mientras se graba y transcribe con
// whisper.cpp. Es una superficie layer-shell en la capa Overlay (igual patrón
// que osd/VolumeOsd.qml): se pinta encima de ventanas a pantalla completa y,
// lo más importante, NO roba el foco de teclado: la app objetivo conserva el
// foco durante todo el dictado y recibe el texto pegado al terminar.
//
// Estados (dictState, gestionado por shell.qml):
//   idle         → oculto
//   recording    → micrófono pulsante + tiempo + botón "Listo" y "X"
//   transcribing → spinner + "Transcribiendo…"
//   done         → ✓ + texto + nota ("Insertado" / "En portapapeles")
//   error        → texto + mensaje de error

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
    WlrLayershell.namespace: "qs-dictation"
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

    // ── Estado gestionado desde shell.qml ─────────────────────────
    required property string dictState
    required property string elapsedText
    required property string resultText
    required property string resultNote
    // true si el dictado forzó el micro encendido (estaba silenciado).
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

    onDictStateChanged: {
        if (osd.dictState !== "idle")
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
                            running: osd.dictState === "recording"
                            from: 0.7
                            to: 0
                            duration: 1400
                            easing.type: Easing.OutCubic
                            loops: Animation.Infinite
                        }
                        NumberAnimation on scale {
                            running: osd.dictState === "recording"
                            from: 1
                            to: 1.8
                            duration: 1400
                            easing.type: Easing.OutCubic
                            loops: Animation.Infinite
                        }
                    }
                }

                // Animación de rotación (transcribing = spinner)
                RotationAnimator on rotation {
                    running: osd.dictState === "transcribing"
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                }

                SymbolicIcon {
                    anchors.centerIn: parent
                    path: osd.dictState === "done" ? Icons.check
                        : osd.dictState === "error" ? Icons.close
                        : Icons.mic
                    color: osd.dictState === "done" ? Settings.green
                        : osd.dictState === "error" ? Settings.red
                        : Settings.accent
                    implicitSize: 22
                }
            }

            // ── Texto central ──────────────────────────────────
            // El ancho es flexible: la columna absorbe el espacio sobrante
            // para que "Listo" y "X" queden pegados al borde derecho del
            // OSD (antes quedaban ~26px desplazados hacia dentro).
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: row.width - 36 - 34 - 12 * (osd.dictState === "recording" ? 3 : 2) - (osd.dictState === "recording" ? 64 : 0)
                spacing: 2

                Text {
                    text: {
                        if (osd.dictState === "recording") return "Grabando…";
                        if (osd.dictState === "transcribing") return "Transcribiendo…";
                        if (osd.dictState === "done") return osd.resultText;
                        if (osd.dictState === "error") return osd.resultNote;
                        return "";
                    }
                    color: Settings.fg
                    font.family: Settings.fontFamily
                    font.pixelSize: osd.dictState === "recording" ? 14 : 13
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    width: parent.width
                }

                Text {
                    visible: osd.dictState !== "recording"
                    text: osd.resultNote
                    color: Settings.subtext0
                    font.family: Settings.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    width: parent.width
                }

                Text {
                    visible: osd.dictState === "recording"
                    text: osd.elapsedText
                    color: Settings.subtext0
                    font.family: Settings.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }

                Text {
                    visible: osd.dictState === "recording" && osd.micForcedOn
                    text: "Micrófono activado para el dictado"
                    color: Settings.yellow
                    font.family: Settings.fontFamily
                    font.pixelSize: 10
                    font.italic: true
                }
            }

            // ── Botón "Listo" (recording) ──────────────────────
            Rectangle {
                visible: osd.dictState === "recording"
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