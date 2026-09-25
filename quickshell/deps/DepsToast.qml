pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../config"

// ─── Aviso de paquetes faltantes (toast) ──────────────────────────────
// Muestra, sobre la pantalla con foco, los paquetes que faltan para que el
// shell funcione completo, con el comando de instalación de cada uno
// (sudo pacman -S ...). Vive en la raíz de shell.qml: aparece al arrancar
// si algo falta (instalación de cero) o cuando una feature concreta detecta
// que le falta su binario, en lugar de fallar en silencio. Es un overlay
// pasivo: no roba foco ni input (WlrLayershell.keyboardFocus: None).
PanelWindow {
    id: toast
    color: "transparent"
    // visible lo controla shell.qml (root.showDepsToast)

    WlrLayershell.namespace: "qs-deps"
    WlrLayershell.exclusiveZone: 0

    // Pantalla con foco en ese momento (sigue a dónde trabajas/juegas).
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

    // Paquetes/binarios que faltan (objetos `deps` de DependencyCheck).
    property var missing: []
    property var onDismiss: null
    property var onRetry: null

    readonly property int toastWidth: 440
    readonly property int listRowH: 24
    readonly property int maxListHeight: 288

    // Altura de la lista (con tope: si faltan muchos paquetes, hace scroll).
    readonly property int listHeight: Math.min(toast.missing.length * toast.listRowH, toast.maxListHeight)

    screen: toast.focusedScreen

    anchors {
        top: true
        left: true
        right: true
    }

    margins.left: toast.focusedScreen ? Math.max(0, Math.round((toast.focusedScreen.width - toast.toastWidth) / 2)) : 0
    margins.right: toast.focusedScreen ? Math.max(0, Math.round((toast.focusedScreen.width - toast.toastWidth) / 2)) : 0
    margins.top: Settings.barHeight + 8

    // Auto-ocultar (se reinicia cada vez que el aviso se muestra).
    Timer {
        id: autoHide
        interval: 25000
        running: toast.visible
        onTriggered: if (toast.onDismiss) toast.onDismiss()
    }

    implicitHeight: 12 + 28 + 10 + 16 + 10 + toast.listHeight + 12 + 30 + 12

    // ── Contenido ─────────────────────────────────────────────
    Rectangle {
        id: box
        anchors.fill: parent
        color: Settings.bg
        radius: 12
        border {
            width: 1
            color: Settings.surface
        }

        layer.enabled: true
        layer.smooth: true

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 0

            // Encabezado: icono + título (la lista habla por sí sola, no se
            // muestra contador numérico para no confundir).
            RowLayout {
                width: parent.width
                height: 28
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 14
                    color: Settings.selectionBg

                    SymbolicIcon {
                        anchors.centerIn: parent
                        path: Icons.warning
                        color: Settings.yellow
                        implicitSize: 18
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Faltan paquetes"
                    color: Settings.fg
                    font.pixelSize: 15
                    font.weight: Settings.fontWeight
                    elide: Text.ElideRight
                }
            }

            // Descripción
            Text {
                width: parent.width
                height: 16
                text: "Se han de instalar para que el shell funcione completo:"
                color: Settings.muted
                font.pixelSize: 12
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            Item { width: 1; height: 10 }

            // Lista de paquetes faltantes (scroll si son muchos)
            Flickable {
                id: depsList
                width: parent.width
                height: toast.listHeight
                contentHeight: toast.missing.length * toast.listRowH
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                Column {
                    id: listColumn
                    width: depsList.width
                    spacing: 0

                    Repeater {
                        model: toast.missing

                        delegate: RowLayout {
                            required property var modelData

                            width: listColumn.width
                            height: toast.listRowH
                            spacing: 6

                            Text {
                                text: "•"
                                color: Settings.yellow
                                font.pixelSize: 12
                            }

                            Text {
                                text: modelData.feats + ":"
                                color: Settings.muted
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                Layout.maximumWidth: 150
                            }

                            Text {
                                text: "sudo pacman -S " + modelData.pkg
                                color: Settings.accent
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: 12 }

            // Botones
            RowLayout {
                width: parent.width
                height: 30
                spacing: 8

                Item { Layout.fillWidth: true }

                // Reintentar (primario): re-ejecuta el chequeo completo.
                Rectangle {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 30
                    radius: 8
                    color: Settings.accent

                    Text {
                        anchors.centerIn: parent
                        text: "Reintentar"
                        color: Settings.bg
                        font.pixelSize: 13
                        font.weight: Settings.fontWeight
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (toast.onRetry) toast.onRetry()
                    }
                }

                // Entendido: cierra el aviso (se volverá a mostrar en el
                // próximo chequeo si el paquete sigue sin instalar).
                Rectangle {
                    Layout.preferredWidth: 96
                    Layout.preferredHeight: 30
                    radius: 8
                    color: Settings.surface

                    Text {
                        anchors.centerIn: parent
                        text: "Entendido"
                        color: Settings.muted
                        font.pixelSize: 13
                        font.weight: Settings.fontWeight
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (toast.onDismiss) toast.onDismiss()
                    }
                }
            }
        }
    }
}