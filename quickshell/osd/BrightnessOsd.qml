// ─── OSD de brillo ────────────────────────────────────────────────
// Clon de VolumeOsd pero para backlight. Solo existe si hasBrightness.
// Se dispara al cambiar Settings.brightness (vía IPC o slider).

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../config"

PanelWindow {
    id: osd
    color: "transparent"
    visible: false
    // No mapear si no hay hardware: no reserva layer, no molesta
    // (visible false ya evita mapear, pero el binding de screen igual)
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-brightness-osd"
    WlrLayershell.exclusiveZone: 0

    readonly property int osdWidth: 270
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
    anchors { bottom: true; left: true; right: true }
    margins.left: osd.focusedScreen ? Math.max(0, Math.round((osd.focusedScreen.width - osd.osdWidth) / 2)) : 0
    margins.right: osd.focusedScreen ? Math.max(0, Math.round((osd.focusedScreen.width - osd.osdWidth) / 2)) : 0
    margins.bottom: 32

    property int lastBrightness: -1

    Connections {
        target: Settings
        function onBrightnessChanged(): void {
            if (!Settings.hasBrightness) return;
            if (osd.lastBrightness === -1) { osd.lastBrightness = Settings.brightness; return; }
            if (Settings.brightness !== osd.lastBrightness) {
                osd.lastBrightness = Settings.brightness;
                osd.trigger();
            }
        }
    }
    Component.onCompleted: if (Settings.hasBrightness) osd.lastBrightness = Settings.brightness

    Timer {
        id: hideTimer
        interval: 900
        onTriggered: fadeOut.running = true
    }
    NumberAnimation { id: fadeIn; target: pill; property: "opacity"; from: 0; to: 1; duration: 120; easing.type: Easing.OutCubic }
    NumberAnimation { id: fadeOut; target: pill; property: "opacity"; from: 1; to: 0; duration: 260; easing.type: Easing.InQuad; onFinished: osd.visible = false }

    function trigger(): void {
        if (!Settings.hasBrightness) return;
        if (osd.visible && pill.opacity > 0.05 && !fadeOut.running) { hideTimer.stop(); hideTimer.start(); return; }
        if (fadeOut.running) fadeOut.stop();
        osd.visible = true;
        pill.opacity = 0;
        fadeIn.running = true;
        hideTimer.stop(); hideTimer.start();
    }

    IpcHandler {
        target: "brightness-osd"
        function show(): void { osd.trigger(); }
        function hide(): void { osd.visible = false; fadeOut.running = false; }
    }

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        implicitWidth: 250
        implicitHeight: 52
        radius: 26
        color: Settings.bg
        border { width: 1; color: Settings.surface }
        layer.enabled: true
        layer.smooth: true

        Row {
            anchors.centerIn: parent
            spacing: 14
            Rectangle {
                width: 34; height: 34; radius: 17; color: Settings.surface
                SymbolicIcon { anchors.centerIn: parent; path: Icons.brightness; color: Settings.accent; implicitSize: 22 }
            }
            Rectangle {
                width: 128; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: Settings.surface
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, Settings.brightness / 100))
                    height: parent.height; radius: parent.radius; color: Settings.accent
                    Behavior on width { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Settings.brightness.toString() + " %"
                color: Settings.fg; font.family: Settings.fontFamily; font.pixelSize: 18; font.weight: Font.Bold
            }
        }
    }
}
