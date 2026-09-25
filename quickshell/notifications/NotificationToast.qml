// ─── Notificación emergente (toast) ─────────────────────────────────
// Muestra la notificación flotante cuando llega una. Vive en la raíz de
// shell.qml (NO en la barra) para que funcione también con la barra en
// "none". Se muestra/oculta según `activeNotif`, que gestiona shell.qml:
// el floatTimer lo limpia a los 4s y con "No molestar" activo nunca se
// asigna. Es un overlay pasivo (no roba foco ni input).
//
// Al hacer clic se invoca la acción por defecto de la notificación (o se
// abre la app) y se descarta; la "✕" solo la descarta.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import "../config"

PanelWindow {
    id: toast
    color: "transparent"
    visible: toast.activeNotif != null

    WlrLayershell.namespace: "qs-notif"
    // exclusiveZone 0 = flotante: no reserva espacio en el borde.
    WlrLayershell.exclusiveZone: 0

    // Pantalla con foco en ese momento (misma lógica que el OSD de
    // volumen): el toast sigue a dónde trabajas/juegas.
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

    required property var activeNotif
    property var onDismiss: null

    readonly property int toastWidth: 360

    screen: toast.focusedScreen

    // Centrado horizontal contenido: PanelWindow no tiene ancla
    // horizontalCenter, así que se ancla left+right con márgenes iguales
    // para que la ventana adopte exactamente el ancho del toast centrado.
    anchors {
        top: true
        left: true
        right: true
    }

    margins.left: toast.focusedScreen ? Math.max(0, Math.round((toast.focusedScreen.width - toast.toastWidth) / 2)) : 0
    margins.right: toast.focusedScreen ? Math.max(0, Math.round((toast.focusedScreen.width - toast.toastWidth) / 2)) : 0
    margins.top: Settings.barHeight + 8

    implicitHeight: 62

    // ── Contenido visual ──────────────────────────────────────
    Rectangle {
        id: toastContent
        anchors.fill: parent
        color: Settings.bg
        radius: 12
        border {
            width: 1
            color: Settings.surface
        }

        layer.enabled: true
        layer.smooth: true

        MouseArea {
            id: contentClickArea
            anchors.fill: parent
            z: 0
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                var n = toast.activeNotif;
                if (n) {
                    var handled = false;
                    for (var i = 0; i < n.actions.length; i++) {
                        if (n.actions[i].identifier === "default") {
                            n.actions[i].invoke();
                            handled = true;
                            break;
                        }
                    }
                    if (!handled && n.desktopEntry !== "") {
                        var entry = DesktopEntries.heuristicLookup(n.desktopEntry);
                        if (entry)
                            entry.execute();
                    }
                }
                if (toast.onDismiss)
                    toast.onDismiss();
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8
            z: 1

            Rectangle {
                id: floatIconBg
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                Layout.alignment: Qt.AlignVCenter
                radius: 15
                color: toast.activeNotif && toast.activeNotif.urgency === NotificationUrgency.Critical ? Settings.red : Settings.selectionBg
                layer.enabled: floatNotifImg.visible

                Image {
                    id: floatNotifImg
                    anchors.fill: parent
                    source: Settings.notifIconUrl(toast.activeNotif)
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    text: {
                        const name = Settings.notifAppName(toast.activeNotif);
                        return name !== "" ? name.charAt(0).toUpperCase() : "?";
                    }
                    color: Settings.bg
                    font.family: Settings.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    visible: !floatNotifImg.visible
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: {
                        const name = Settings.notifAppName(toast.activeNotif);
                        return name !== "" ? name : "notify-send";
                    }
                    color: Settings.fg
                    font.family: Settings.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    Layout.fillWidth: true
                    text: {
                        if (!toast.activeNotif)
                            return "";
                        var s = toast.activeNotif.summary || "";
                        var b = toast.activeNotif.body || "";
                        return s + (s && b ? " — " : "") + b;
                    }
                    color: Settings.subtext0
                    font.family: Settings.fontFamily
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            MouseArea {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                Layout.alignment: Qt.AlignTop
                z: 1
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (toast.onDismiss)
                        toast.onDismiss();
                }

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: Settings.subtext0
                    font.family: Settings.fontFamily
                    font.pixelSize: 11
                }
            }
        }
    }

    // ── Entrada ────────────────────────────────────────────────
    NumberAnimation {
        id: fadeIn
        target: toastContent
        property: "opacity"
        from: 0
        to: 1
        duration: 140
        easing.type: Easing.OutCubic
    }

    // Al llegar una notificación nueva (o la primera) se hace el fade;
    // al limpiarse activeNotif la ventana se desmapea al instante.
    onActiveNotifChanged: {
        if (toast.activeNotif != null) {
            toastContent.opacity = 0;
            fadeIn.start();
        }
    }
}
