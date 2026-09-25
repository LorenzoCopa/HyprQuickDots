// ─── OSD de volumen ───────────────────────────────────────────────
// Indicador "on-screen display" que se muestra brevemente al cambiar
// el volumen o el estado de mute del sink de audio por defecto.
//
// Es una ventana layer-shell en la capa `Overlay`, por lo que se dibuja
// ENCIMA de las ventanas a pantalla completa (juegos como Dota 2), a
// diferencia de un FloatingWindow (toplevel) o de la capa `Top`, que
// quedan por debajo y "desaparecen" durante una partida.
//
// Es reactivo: se dispara solo al detectar un cambio en Pipewire, sin
// tocar los binds de Hyprland (que siguen llamando a `wpctl`).

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import "../config"

PanelWindow {
    id: osd
    color: "transparent"
    visible: false

    // ── Capa Overlay: visible sobre ventanas fullscreen ─────────
    WlrLayershell.layer: WlrLayer.Overlay
    // keyboardFocus por defecto = None (overlay pasivo; no roba foco).

    WlrLayershell.namespace: "qs-osd"

    // exclusiveZone 0 = flotante: la superficie NO reserva espacio en el
    // borde ni empuja el contenido hacia arriba (solo actúa como overlay).
    WlrLayershell.exclusiveZone: 0

    // Sin exclusiveZone ni grabFocus: overlay pasivo que no reserva
    // espacio ni roba el foco/entrada al juego.

    // `PanelWindow` (layer-shell) no tiene ancla "horizontalCenter": sus
    // anchors son bottom/left/right/top. Para centrar la píldora de forma
    // contenida (sin bloquear una franja completa del borde inferior del
    // juego), anclamos left+right+bottom y calculamos unos márgenes iguales
    // para que la ventana adopte exactamente el ancho de la píldora centrada.
    readonly property int osdWidth: 270

    // Pantalla con foco en ese momento (sigue a dónde juegas/trabajas).
    // Asignamos `screen` explícitamente para que el OSD mapee incluso al
    // nacer oculto, y calculamos los márgenes contra esa misma pantalla
    // (con 2 monitores, Quickshell.screens[0] puede ser la secundaria y
    // desalinear el centrado).
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

    // ── Estado de audio (reactivo vía Pipewire) ─────────────────
    readonly property var sink: Pipewire.ready ? Pipewire.defaultAudioSink : null

    // Guardas: al vincularse el nodo, `volume`/`muted` llegan `undefined`
    // brevemente antes de que Pipewire reporte sus valores reales.
    // El volumen/mute viven en `sink.audio` (un PwNodeAudio).
    readonly property real volume: osd.sink && osd.sink.audio && Number.isFinite(osd.sink.audio.volume) ? osd.sink.audio.volume : 0
    readonly property bool muted: osd.sink && osd.sink.audio && typeof osd.sink.audio.muted === "boolean" ? osd.sink.audio.muted : false

    // Solo muestra el OSD tras el primer sync con Pipewire (evita
    // que "salte" al arrancar la sesión).
    property bool armShow: false

    PwObjectTracker {
        objects: osd.sink ? [osd.sink] : []
    }

    // Respaldo garantizado: fuerza el armado aunque las señales de Pipewire
    // (ready / defaultAudioSink) se hayan emitido antes de crear este archivo.
    Timer {
        interval: 800
        running: true
        repeat: false
        onTriggered: {
            if (Pipewire.ready)
                osd.armShow = true;
        }
    }

    Connections {
        target: Pipewire
        function onReadyChanged(): void {
            if (Pipewire.ready)
                osd.armShow = true;
        }
    }

    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged(): void {
            if (Pipewire.ready)
                osd.armShow = true;
        }
    }

    Component.onCompleted: {
        if (Pipewire.ready)
            osd.armShow = true;
    }

    // ── Icono según nivel de volumen / dispositivo ──────────────
    readonly property bool isBluetooth: osd.sink && typeof osd.sink.name === "string" && osd.sink.name.indexOf("bluez_output.") === 0
    readonly property string iconChar: {
        if (osd.isBluetooth) return Icons.bluetooth;
        if (osd.muted) return Icons.volumeMute;
        if (osd.volume <= 0.01) return Icons.volumeOff;
        if (osd.volume < 0.34) return Icons.volumeLow;
        if (osd.volume < 0.67) return Icons.volumeMedium;
        return Icons.volumeHigh;
    }

    // Detección de cambios: reactivo primero (PwObjectTracker notifica
    // volume/muted del nodo trackeado) con un poll LENTO de respaldo a 1s,
    // porque algún caso borde no emite la señal. Antes era un poll ciego de
    // 120ms corriendo para siempre (~500 ticks/min en idle); ahora el coste
    // en reposo es una evaluación por segundo y la reacción al volumen es
    // instantánea.
    property real lastVolume: -1
    property bool lastMuted: false

    function checkAudioChange(): void {
        if (!osd.armShow)
            return;
        const v = osd.sink && osd.sink.audio && Number.isFinite(osd.sink.audio.volume) ? osd.sink.audio.volume : 0;
        const m = osd.sink && osd.sink.audio && typeof osd.sink.audio.muted === "boolean" ? osd.sink.audio.muted : false;

        // Aparece un sink nuevo (conexión/reconexión BT): activa la
        // supresión local para tapar el gap inicial, antes de que
        // shell.qml marque btVolumeSettling. En el arranque no se
        // activa si el BT ya estaba estable.
        if (osd.sink !== osd._lastSinkRef) {
            osd._lastSinkRef = osd.sink;
            osd._btSawSettling = false;
            if (osd.isBluetooth && osd.lastVolume !== -1)
                osd._btSettlingLocal = true;
            else
                osd._btSettlingLocal = false;
        }

        if (osd.lastVolume === -1) {
            osd.lastVolume = v;
            osd.lastMuted = m;
            return;
        }

        // Durante la supresión BT solo se rastrea el valor. La
        // supresión termina (y se dispara UNA vez) cuando hemos visto
        // btVolumeSettling activo y ahora ya no lo está.
        if (osd.isBluetooth && osd._btSettlingLocal) {
            if (root.btVolumeSettling)
                osd._btSawSettling = true;
            osd.lastVolume = v;
            osd.lastMuted = m;
            if (osd._btSawSettling && !root.btVolumeSettling) {
                osd._btSettlingLocal = false;
                osd.trigger();
            }
            return;
        }

        if (v !== osd.lastVolume || m !== osd.lastMuted) {
            osd.lastVolume = v;
            osd.lastMuted = m;
            osd.trigger();
        }
    }

    // Reacción inmediata: señales del nodo trackeado.
    Connections {
        target: osd.sink && osd.sink.audio ? osd.sink.audio : null
        function onVolumeChanged(): void { osd.checkAudioChange(); }
        function onMutedChanged(): void { osd.checkAudioChange(); }
    }

    // Respaldo garantizado: cubre los casos donde Pipewire no notifica.
    Timer {
        id: pollTimer
        interval: 1000
        repeat: true
        running: true
        onTriggered: osd.checkAudioChange()
    }

    // Supresión de saltos al conectar un sink bluetooth: el dispositivo
    // re-reporta su propio volumen (el "sonido de conexión" a ~100) y el
    // restaurador (shell.qml) lo corrige al valor guardado. Durante ese
    // proceso el volumen pasa por varios valores intermedios; aquí se
    // ignoran todos y se dispara UNA sola vez con el volumen final.
    property var _lastSinkRef: null
    property bool _btSettlingLocal: false
    property bool _btSawSettling: false

    // ── Aparición / desaparición ────────────────────────────────
    Timer {
        id: hideTimer
        interval: 900
        onTriggered: fadeOut.running = true
    }

    NumberAnimation {
        id: fadeIn
        target: pill
        property: "opacity"
        from: 0
        to: 1
        duration: 120
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: fadeOut
        target: pill
        property: "opacity"
        from: 1
        to: 0
        duration: 260
        easing.type: Easing.InQuad
        onFinished: osd.visible = false
    }

    function trigger(): void {
        console.log("[osd] trigger vol", osd.volume.toFixed(2), "bt", osd.isBluetooth);
        // Si el OSD ya está visible (fade-in terminado o en curso), NO
        // reiniciamos a opacidad 0: solo postergamos el ocultado. Así,
        // subir/bajar volumen de forma continuada (key-repeat de wpctl)
        // extiende la píldora en lugar de parpadear (desaparecer y volver).
        if (osd.visible && pill.opacity > 0.05 && !fadeOut.running) {
            hideTimer.stop();
            hideTimer.start();
            return;
        }
        if (fadeOut.running)
            fadeOut.stop();
        osd.visible = true;
        pill.opacity = 0;
        fadeIn.running = true;
        hideTimer.stop();
        hideTimer.start();
    }

    // ── IPC (llamable desde hyprland.lua si se desea) ───────────
    IpcHandler {
        target: "osd"
        function showOsd(): void { osd.trigger(); }
        function hideOsd(): void { osd.visible = false; fadeOut.running = false; }
    }

    // ── Contenido visual ────────────────────────────────────────
    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        implicitWidth: 250
        implicitHeight: 52
        radius: 26
        color: Settings.bg
        border {
            width: 1
            color: Settings.surface
        }

        layer.enabled: true
        layer.smooth: true

        Row {
            anchors.centerIn: parent
            spacing: 14

            Rectangle {
                width: 34
                height: 34
                radius: 17
                color: Settings.surface

                SymbolicIcon {
                    anchors.centerIn: parent
                    path: osd.iconChar
                    color: osd.muted ? Settings.red : Settings.accent
                    implicitSize: 22
                }
            }

            Rectangle {
                // barra de progreso (cápsula central)
                width: 128
                height: 8
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: Settings.surface

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, osd.volume))
                    height: parent.height
                    radius: parent.radius
                    color: osd.muted ? Settings.red : Settings.accent
                    Behavior on width { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(osd.volume * 100).toString() + " %"
                color: Settings.fg
                font.family: Settings.fontFamily
                font.pixelSize: 18
                font.weight: Font.Bold
            }
        }
    }
}