pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../config"

// ─── Menú de sesión (wlogout) ──────────────────────────────────────────
// Overlay a pantalla completa sobre el scrim oscuro (el fondo se queda
// como está: atenuado sobre lo que haya abierto). Los botones son
// tarjetas bien visibles SIN necesidad de hover: relleno elevado sobre
// el scrim (#171717 → #242424 al hover) e iconos/etiquetas a acento
// pleno en reposo. Al pasar el ratón la tarjeta se aclara, escala un
// poco y el contenido pasa al color "hot" (rojo en Apagar, por ser la
// acción destructiva). La tecla rápida va INTEGRADA en la etiqueta:
// la primera letra (A/R/S/C/B) sale en blanco y negrita dentro del
// propio texto (ej. **A**pagar), no en una esquina.
FloatingWindow {
    id: wlOverlay
    title: "wlogout"
    color: Settings.scrim

    // Cubre toda la pantalla del monitor con foco SIN `fullscreen`:
    // una ventana fullscreen se "esconde" en la esquina superior izquierda
    // al cerrarla la primera vez y retiene ese estado entre hide/show
    // (mismo motivo que el QuickAccess: tamaño de monitor explícito).
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

    // Superficies de las tarjetas: un punto más altas que las del
    // QuickAccess para que destaquen solas sobre el scrim (local aquí,
    // la paleta global no cambia).
    readonly property string cardBg: "#171717"
    readonly property string cardHover: "#242424"
    readonly property string keyLetterColor: "#FFFFFF"

    screen: wlOverlay.focusedScreen
    implicitWidth: wlOverlay.focusedScreen ? wlOverlay.focusedScreen.width : 0
    implicitHeight: wlOverlay.focusedScreen ? wlOverlay.focusedScreen.height : 0

    signal closeRequested
    signal lockScreen

    onVisibleChanged: {
        if (visible)
            Qt.callLater(function () {
                escCatcher.forceActiveFocus();
            });
    }

    MouseArea {
        id: bgClick
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: false
        onClicked: wlOverlay.closeRequested()
    }

    Process {
        id: logoutProc
        command: ["uwsm", "stop"]
    }
    Process {
        id: suspendProc
        command: ["systemctl", "suspend"]
    }
    Process {
        id: rebootProc
        command: ["systemctl", "reboot"]
    }
    Process {
        id: shutdownProc
        command: ["systemctl", "poweroff"]
    }

    // Contenido centrado con entrada suave (fade + escala sutil),
    // igual que el QuickAccess.
    Item {
        id: contentWrap
        anchors.fill: parent
        opacity: wlOverlay.visible ? 1 : 0
        scale: wlOverlay.visible ? 1 : 0.96
        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 22

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "SESIÓN"
                color: Settings.muted
                font.family: Settings.fontFamily
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 3
            }

            Row {
                spacing: 18

                Repeater {
                    model: [
                        {
                            icon: Icons.power,
                            proc: shutdownProc,
                            label: "Apagar",
                            hot: Settings.red
                        },
                        {
                            icon: Icons.reboot,
                            proc: rebootProc,
                            label: "Reiniciar",
                            hot: "#FFFFFF"
                        },
                        {
                            icon: Icons.suspend,
                            proc: suspendProc,
                            label: "Suspender",
                            hot: "#FFFFFF"
                        },
                        {
                            icon: Icons.logout,
                            proc: logoutProc,
                            label: "Cerrar sesión",
                            hot: "#FFFFFF"
                        },
                        {
                            icon: Icons.lock,
                            action: function () {
                                wlOverlay.lockScreen();
                                wlOverlay.closeRequested();
                            },
                            label: "Bloquear",
                            hot: "#FFFFFF"
                        },
                    ]

                    delegate: Item {
                        id: wlDelegate
                        required property var modelData

                        // Primera letra de la etiqueta = tecla rápida
                        // (Apagar→A, Reiniciar→R, Suspender→S,
                        // Cerrar sesión→C, Bloquear→B). Coinciden con los
                        // binds del escCatcher.
                        readonly property string keyLetter: modelData.label.charAt(0)
                        readonly property string restLabel: modelData.label.substring(1)
                        readonly property bool hovered: btnMouse.containsMouse

                        width: 128
                        height: 128

                        scale: btnMouse.containsMouse ? 1.05 : 1.0
                        Behavior on scale {
                            NumberAnimation {
                                duration: 130
                                easing.type: Easing.OutCubic
                            }
                        }

                        // Sombra suave bajo la tarjeta (elevación sin
                        // borde, mismo truco de 3 capas del WidgetShell).
                        Item {
                            anchors.fill: parent
                            Rectangle {
                                x: 0
                                y: 2
                                width: parent.width
                                height: parent.height
                                radius: 16
                                color: "#2E000000"
                            }
                            Rectangle {
                                x: 0
                                y: 5
                                width: parent.width
                                height: parent.height
                                radius: 17
                                color: "#1F000000"
                            }
                            Rectangle {
                                x: 0
                                y: 8
                                width: parent.width
                                height: parent.height
                                radius: 18
                                color: "#12000000"
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: wlDelegate.hovered ? wlOverlay.cardHover : wlOverlay.cardBg
                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 11

                            SymbolicIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                path: wlDelegate.modelData.icon
                                color: wlDelegate.hovered ? wlDelegate.modelData.hot : Settings.accent
                                implicitSize: 38
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }
                            }

                            // Etiqueta con la tecla integrada: la primera
                            // letra en blanco y negrita (**A**pagar), el
                            // resto a acento en reposo y al hot color en
                            // hover.
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                textFormat: Text.RichText
                                text: "<font color='" + wlOverlay.keyLetterColor + "'><b>"
                                      + wlDelegate.keyLetter + "</b></font><font color='"
                                      + (wlDelegate.hovered ? wlDelegate.modelData.hot : Settings.accent)
                                      + "'>" + wlDelegate.restLabel + "</font>"
                                font.family: Settings.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Bold
                            }
                        }

                        MouseArea {
                            id: btnMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                if (wlDelegate.modelData.action) {
                                    wlDelegate.modelData.action();
                                } else {
                                    wlDelegate.modelData.proc.running = true;
                                    wlOverlay.closeRequested();
                                }
                            }
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "ESC para salir"
                color: Settings.muted
                opacity: 0.8
                font.family: Settings.fontFamily
                font.pixelSize: 10
            }
        }
    }

    HyprlandFocusGrab {
        windows: [wlOverlay]
    }

    // Sobre un juego fullscreen el foco inicial puede quedarse en el juego
    // (constraint del puntero); pedirlo por dispatcher rompe el bloqueo.
    SelfFocus {
        targetTitle: "wlogout"
        active: wlOverlay.visible
    }

    Item {
        id: escCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                wlOverlay.closeRequested();
                event.accepted = true;
            } else if (event.key === Qt.Key_B) {
                wlOverlay.lockScreen();
                wlOverlay.closeRequested();
                event.accepted = true;
            } else if (event.key === Qt.Key_C) {
                logoutProc.running = true;
                wlOverlay.closeRequested();
                event.accepted = true;
            } else if (event.key === Qt.Key_S) {
                suspendProc.running = true;
                wlOverlay.closeRequested();
                event.accepted = true;
            } else if (event.key === Qt.Key_R) {
                rebootProc.running = true;
                wlOverlay.closeRequested();
                event.accepted = true;
            } else if (event.key === Qt.Key_A) {
                shutdownProc.running = true;
                wlOverlay.closeRequested();
                event.accepted = true;
            }
        }
    }
}
