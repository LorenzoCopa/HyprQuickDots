// ─── Menú de acceso rápido (QuickAccess) ──────────────────────────────
// Ventana flotante a pantalla completa con fondo transparente, estilo
// "ajustes rápidos" de Android, organizada en tres columnas: la izquierda
// agrupa en un único panel las notificaciones (con los sliders de volumen
// y luz integrados vía showControls); la central apila el reproductor
// Mpris (hero now-playing), el reloj seven-segment en vertical (hora
// grande, antes en el launcher) y el calendario, cada uno en su propia
// caja; la derecha apila los ajustes rápidos, las acciones y un mosaico
// de widgets de información en dos columnas (Sistema con la bandeja
// integrada + Clima a la izquierda; Almacenamiento + GPU a la derecha,
// con la GPU subida bajo Almacenamiento sin espacio muerto). Se abre con
// SUPER+B y se cierra con ESC o con un click fuera/sobre una zona vacía.
//
// Diseño: cabecera con la fecha larga en español sobre el conjunto; las
// superficies (cajas y tiles) se distinguen por relleno tenue (cardBg,
// un pelo más claro que el negro puro) + sombra suave, SIN líneas de
// borde, y el contenido entra con un fade + escala sutil. El acento claro
// (#B3E6DB) se reserva para los estados activos; lo inactivo/secundario
// usa el tono atenuado Settings.muted para no saturar la vista.
//
// El reproductor es un hero now-playing dedicado (MediaHeroPanel, en
// quickshell/quickaccess/); el popup del reloj conserva MediaPanel.
// las notificaciones reutilizan NotificationsPanel (mismo panel que el
// popup del reloj, con el host de shell.qml). Las apps activas y el tray
// replican la lógica de ActiveAppsWidget y TrayButton. Cada icono del tray
// mantiene sus clics (izq/derecho/medio), la rueda y el menú contextual.

pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Networking
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../bar/panels"
import "../launcher"
import "../config"
import "widgets"

FloatingWindow {
    id: quickAccess
    color: "transparent"
    title: "qs-quickaccess"
    visible: false
    // Cubre toda la pantalla con el fondo transparente: el contenido
    // flota centrado y ninguna caja queda recortada por el borde de la
    // ventana. En Hyprland sigue siendo una ventana flotante (regla
    // qs-quickaccess-float), solo que del tamaño del monitor. Se usa la
    // pantalla con foco, igual que el OSD de volumen.
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

    screen: quickAccess.focusedScreen
    implicitWidth: quickAccess.focusedScreen ? quickAccess.focusedScreen.width : 0
    implicitHeight: quickAccess.focusedScreen ? quickAccess.focusedScreen.height : 0

    // Fondo de cajas y tiles: un pelo más claro que el negro puro del fondo
    // para que las superficies se distingan SIN líneas de borde (se elevan
    // con la sombra suave). Es local al QuickAccess; la barra no cambia.
    readonly property string cardBg: "#121212"
    readonly property string cardHover: "#1C1C1C"

    // ── Notificaciones (inyectadas desde shell.qml) ─────────────
    required property var notifModel
    required property bool dndEnabled
    required property var onToggleDnd
    required property var onClearAll

    // ── Acciones rápidas (inyectadas desde shell.qml) ───────────
    required property var onOpenSettings
    required property var onScreenshot
    required property var onLockScreen
    required property var onToggleWlogout

    // ── Proceso para abrir el portapapeles (misma vía IPC que los
    // accesos directos; cierra este menú antes para darle el foco).
    Process {
        id: clipboardProc
        command: ["qs", "ipc", "call", "clipboard", "toggle"]
        running: false
    }

    function openClipboard(): void {
        quickAccess.visible = false;
        clipboardProc.running = true;
    }

    // ── Comunicación IPC: `qs ipc call quickaccess toggle` ─────────
    IpcHandler {
        target: "quickaccess"
        function toggle(): void {
            quickAccess.visible = !quickAccess.visible;
        }
        function hide(): void { quickAccess.visible = false; }
    }

    // ── Se cierra solo si se pierde el foco (click fuera) ───────────
    // El selector de workspace es un overlay DENTRO de esta misma ventana,
    // así que no hay que vigilarlo aparte (el foco no se pierde al
    // abrirlo). El menú contextual del tray no es un Window, así que se
    // desactiva el grab mientras está abierto (toma el foco y no debe
    // cerrar el panel).
    HyprlandFocusGrab {
        windows: [quickAccess]
        active: quickAccess.visible && !systemWidget.trayContextMenu.visible && !Settings.captureActive
        onCleared: quickAccess.visible = false
    }

    // Sobre un juego fullscreen el foco inicial puede quedarse en el juego
    // (constraint del puntero); pedirlo por dispatcher rompe el bloqueo.
    SelfFocus {
        targetTitle: "qs-quickaccess"
        active: quickAccess.visible
    }

    // ── Cerrar con Esc o con un click en una zona vacía del menú ───
    Item {
        id: closeSurface
        anchors.fill: parent
        focus: quickAccess.visible
        Keys.onEscapePressed: quickAccess.visible = false

        MouseArea {
            anchors.fill: parent
            onClicked: quickAccess.visible = false
        }
    }

    // Esc de respaldo: aunque un control interno (slider, etc.) haya
    // robado el foco, Escape sigue cerrando el menú.
    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        onActivated: quickAccess.visible = false
    }

    // Espacio: play/pausa del reproductor activo. Solo con el menú abierto
    // y mientras haya un reproductor Mpris (mismo guard que el hero): fuera
    // del panel la tecla queda libre para las apps.
    Shortcut {
        sequence: "Space"
        context: Qt.WindowShortcut
        enabled: quickAccess.visible && playerHero.hasPlayer && playerHero.activePlayer.canPlay
        onActivated: playerHero.activePlayer.togglePlaying()
    }

    // N / P: siguiente / anterior del reproductor activo. Mismo guard que
    // Espacio: solo con el menú abierto y si el reproductor lo soporta.
    Shortcut {
        sequence: "N"
        context: Qt.WindowShortcut
        enabled: quickAccess.visible && playerHero.hasPlayer && playerHero.activePlayer.canGoNext
        onActivated: playerHero.activePlayer.next()
    }

    Shortcut {
        sequence: "P"
        context: Qt.WindowShortcut
        enabled: quickAccess.visible && playerHero.hasPlayer && playerHero.activePlayer.canGoPrevious
        onActivated: playerHero.activePlayer.previous()
    }

    // ── Contenido: tres columnas distribuidas ────────────────────────
    // Columna izquierda: notificaciones a todo lo alto. Columna central:
    // reproductor (arriba) + reloj vertical (abajo). Columna derecha:
    // ajustes rápidos, widgets de información y la bandeja.
    //
    // Apertura animada (fade + escala sutil). La ventana entera no se
    // anima para seguir capturando los clics y dejar ver el fondo.
    Row {
        id: columnsRow
        anchors.centerIn: parent
        spacing: 12
        opacity: quickAccess.visible ? 1 : 0
        scale: quickAccess.visible ? 1 : 0.98
        transformOrigin: Item.Center

        // Altura común a las tres columnas = la de la central (sus cajas
        // están auto-ajustadas: reproductor + reloj + calendario). Las
        // laterales se ajustan a esa misma altura: notificaciones llena el
        // hueco (hay espacio de sobra sin notificaciones) y en la derecha
        // los tiles y widgets se apilan desde arriba. Sin techo fijo de
        // 754: el conjunto se encoge a lo natural.
        readonly property real centerHeight:
            playerHero.contentHeight + 20 + clockCard.height + 24 + calendarCard.height
        readonly property real commonHeight: columnsRow.centerHeight
        height: columnsRow.commonHeight

        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        // ── Columna izquierda: Notificaciones ──
        // Panel único con las notificaciones a todo lo alto (con los
        // sliders de volumen/luz integrados vía showControls).
        Item {
            width: 400
            height: columnsRow.height

            // Sombra suave bajo la caja: profundidad sin tapar el fondo
            // (el hueco entre cajas deja ver lo que hay detrás).
            Item {
                anchors.fill: parent
                Rectangle { x: 0; y: 2; width: parent.width; height: parent.height; radius: 16; color: "#26000000" }
                Rectangle { x: 0; y: 5; width: parent.width; height: parent.height; radius: 17; color: "#18000000" }
                Rectangle { x: 0; y: 8; width: parent.width; height: parent.height; radius: 18; color: "#0E000000" }
            }

            Rectangle {
                anchors.fill: parent
                radius: 14
                color: quickAccess.cardBg
            }

            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 0

                // ── Notificaciones (a todo lo alto) ──
                NotificationsPanel {
                    width: parent.width
                    height: parent.height
                    notifModel: quickAccess.notifModel
                    dndEnabled: quickAccess.dndEnabled
                    onToggleDnd: quickAccess.onToggleDnd
                    onClearAll: quickAccess.onClearAll
                    showControls: true
                }
            }
        }

        // ── Columna central: Reproductor + Reloj + Calendario ──
        // Contenedor de la altura común: el Column con las tres cajas se
        // centra verticalmente (gaps simétricos arriba/abajo).
        Item {
            width: 330
            height: columnsRow.height

            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: 12

            // ── Reproductor (hero now-playing compacto, arriba) ──
            // La altura se ajusta al contenido real del MediaHeroPanel
            // (142px reproduciendo, ~66px sin reproducción) + márgenes.
            Item {
                width: parent.width
                height: playerHero.contentHeight + 20

                // Sombra suave bajo la caja (elevación sin tapar el fondo).
                Item {
                    anchors.fill: parent
                    Rectangle { x: 0; y: 2; width: parent.width; height: parent.height; radius: 16; color: "#26000000" }
                    Rectangle { x: 0; y: 5; width: parent.width; height: parent.height; radius: 17; color: "#18000000" }
                    Rectangle { x: 0; y: 8; width: parent.width; height: parent.height; radius: 18; color: "#0E000000" }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: quickAccess.cardBg
                }

                MediaHeroPanel {
                    id: playerHero
                    anchors.fill: parent
                    anchors.margins: 10
                    panelActive: quickAccess.visible
                    showPeaks: true
                }
            }

            // ── Reloj (seven-segment en vertical) ────────────
            // La card se ajusta al alto real del ClockBox (contenido
            // seven-segment + días de la semana) + márgenes.
            Item {
                id: clockCard
                width: parent.width
                height: clockBox.contentHeight + 20

                // Sombra suave bajo la caja (elevación sin tapar el fondo).
                Item {
                    anchors.fill: parent
                    Rectangle { x: 0; y: 2; width: parent.width; height: parent.height; radius: 16; color: "#26000000" }
                    Rectangle { x: 0; y: 5; width: parent.width; height: parent.height; radius: 17; color: "#18000000" }
                    Rectangle { x: 0; y: 8; width: parent.width; height: parent.height; radius: 18; color: "#0E000000" }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: quickAccess.cardBg
                }

                ClockBox {
                    id: clockBox
                    anchors.centerIn: parent
                    boxed: false
                    vertical: true
                }
            }

            // ── Calendario ───────────────────────────────────
            Item {
                id: calendarCard
                width: parent.width
                height: 240

                // Sombra suave bajo la caja (elevación sin tapar el fondo).
                Item {
                    anchors.fill: parent
                    Rectangle { x: 0; y: 2; width: parent.width; height: parent.height; radius: 16; color: "#26000000" }
                    Rectangle { x: 0; y: 5; width: parent.width; height: parent.height; radius: 17; color: "#18000000" }
                    Rectangle { x: 0; y: 8; width: parent.width; height: parent.height; radius: 18; color: "#0E000000" }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: quickAccess.cardBg
                }

                CalendarPanel {
                    anchors.fill: parent
                    anchors.margins: 8
                    compact: true
                    centerContent: true
                }
            }
            }
        }

        // ── Columna derecha: Ajustes + Widgets ──
        // Contenedor de la altura común. El contenido (tiles, widgets de
        // información) se apila en un Column scrolleable: si la suma excede
        // la altura común, se desplaza.
        Item {
            width: 380
            height: columnsRow.height

            Flickable {
                anchors.fill: parent
                contentWidth: width
                contentHeight: rightCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                Column {
                    id: rightCol
                    width: parent.width
                    spacing: 12

            // ── Rompecabezas de ajustes rápidos (estilo Android) ──
            // Cada control es una pieza separada, no un cajón único:
            // cinco tiles cuadrados con etiqueta (Bluetooth, Red, Luz
            // nocturna, Portapapeles y modo de energía). Misma vía de
            // estado que el popup del reloj y los ajustes: Settings.
            // applyBluetooth / applyNightLight / setPowerProfile /
            // Pipewire / Networking. Los sliders (volumen y temperatura
            // de luz) están en la columna izquierda.
            Row {
                id: quickTiles
                width: parent.width
                height: 80
                spacing: 6
                readonly property int visibleCount: (Settings.hasMic ? 6 : 5) + (Settings.hasBrightness ? 1 : 0)
                readonly property real tileW: (parent.width - (visibleCount - 1) * 6) / visibleCount

                // ── Brillo (solo si hay backlight) ──
                Item {
                    visible: Settings.hasBrightness
                    width: visible ? quickTiles.tileW : 0
                    height: parent.height
                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: brightHover.containsMouse ? quickAccess.cardHover : quickAccess.cardBg
                        Behavior on color { ColorAnimation { duration: 80 } }
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        SymbolicIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            path: Icons.brightness
                            color: Settings.muted
                            implicitSize: 20
                        }
                    }
                    MouseArea {
                        id: brightHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // click abre slider ya visible en NotificationsPanel; por ahora solo sube un paso
                            if (Settings.setBrightness) Settings.setBrightness(Math.min(100, Settings.brightness + 10))
                        }
                    }
                }

                // ── Bluetooth ───────────────────────────────
                Item {
                    width: quickTiles.tileW
                    height: parent.height

                    readonly property bool btEnabled: Bluetooth.defaultAdapter
                        && Bluetooth.defaultAdapter.state !== BluetoothAdapterState.Blocked
                        && Bluetooth.defaultAdapter.enabled

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: parent.btEnabled ? Settings.selectionBg
                             : btHover.containsMouse ? quickAccess.cardHover
                             : quickAccess.cardBg
                        Behavior on color { ColorAnimation { duration: 80 } }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        SymbolicIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            path: parent.parent.btEnabled ? Icons.bluetooth : Icons.bluetoothOff
                            color: parent.parent.btEnabled ? Settings.accent : Settings.muted
                            implicitSize: 20
                        }
                    }

                    MouseArea {
                        id: btHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!Bluetooth.defaultAdapter) return;
                            if (Bluetooth.defaultAdapter.state === BluetoothAdapterState.Blocked)
                                btUnblockProc.running = true;
                            else {
                                Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
                                if (Settings.applyBluetooth)
                                    Settings.applyBluetooth(Bluetooth.defaultAdapter.enabled);
                            }
                        }
                    }
                }

                // ── Red (indicador: escritorio, normalmente cable) ─
                Item {
                    width: quickTiles.tileW
                    height: parent.height

                    readonly property bool netConnected: {
                        var vals = Networking.devices.values;
                        if (!vals) return false;
                        for (var i = 0; i < vals.length; i++) {
                            if (vals[i].connected) return true;
                        }
                        return false;
                    }
                    readonly property bool netIsWifi: {
                        var vals = Networking.devices.values;
                        if (!vals) return false;
                        for (var i = 0; i < vals.length; i++) {
                            if (vals[i].connected && vals[i].type === DeviceType.Wifi) return true;
                        }
                        return false;
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: parent.netConnected ? Settings.selectionBg : quickAccess.cardBg
                        Behavior on color { ColorAnimation { duration: 80 } }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        SymbolicIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            path: parent.parent.netConnected
                                ? (parent.parent.netIsWifi ? Icons.wifi : Icons.ethernet)
                                : Icons.networkOffline
                            color: parent.parent.netConnected ? Settings.accent : Settings.muted
                            implicitSize: 20
                        }
                    }
                }

                // ── Luz nocturna (toggle) ────────────────────────────
                Item {
                    width: quickTiles.tileW
                    height: parent.height

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: Settings.nightLightEnabled ? Settings.selectionBg : quickAccess.cardBg
                        Behavior on color { ColorAnimation { duration: 80 } }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        SymbolicIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            path: Icons.nightlight
                            color: Settings.nightLightEnabled ? Settings.accent : Settings.muted
                            implicitSize: 20
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Settings.nightLightEnabled = !Settings.nightLightEnabled;
                            if (Settings.applyNightLight)
                                Settings.applyNightLight();
                        }
                    }
                }

                // ── Portapapeles (abre el gestor de cliphist) ────
                Item {
                    width: quickTiles.tileW
                    height: parent.height

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: clipHover.containsMouse ? quickAccess.cardHover : quickAccess.cardBg
                        Behavior on color { ColorAnimation { duration: 80 } }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        SymbolicIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            path: Icons.clipboard
                            color: Settings.muted
                            implicitSize: 20
                        }
                    }

                    MouseArea {
                        id: clipHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: quickAccess.openClipboard()
                    }
                }

                // ── Modo de energía (perfil activo) ────────────────
                // Muestra el perfil actual de power-profiles-daemon y un
                // clic lo cambia al siguiente (ciclo Perf → Equi → Ahorro).
                // El estado viene de Settings.powerProfile (sync en
                // shell.qml); el cambio se aplica con powerprofilesctl.
                Item {
                    width: quickTiles.tileW
                    height: parent.height

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: energyHover.containsMouse ? quickAccess.cardHover : Settings.selectionBg
                        Behavior on color { ColorAnimation { duration: 80 } }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        SymbolicIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            path: Settings.powerIcon
                            color: Settings.accent
                            implicitSize: 20
                        }
                    }

                    MouseArea {
                        id: energyHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var list = Settings.powerProfiles;
                            for (var i = 0; i < list.length; i++) {
                                if (list[i].id === Settings.powerProfile) {
                                    var next = list[(i + 1) % list.length];
                                    if (Settings.setPowerProfile)
                                        Settings.setPowerProfile(next.id);
                                    return;
                                }
                            }
                            if (list.length && Settings.setPowerProfile)
                                Settings.setPowerProfile(list[0].id);
                        }
                    }
                }

                // ── Micrófono (toggle de mute) ──────────────────────
                // Muta/desmuta el source por defecto (el rnnoise_source
                // del filtro de micrófono). Solo toca el mute, nunca el
                // volumen (el volumen del chain es delicado, ver AGENTS).
                Item {
                    id: micTile
                    visible: Settings.hasMic
                    width: visible ? quickTiles.tileW : 0
                    height: parent.height

                    readonly property var micSrc: Pipewire.ready ? Pipewire.defaultAudioSource : null
                    readonly property bool micMuted: micTile.micSrc && micTile.micSrc.audio
                        && typeof micTile.micSrc.audio.muted === "boolean" ? micTile.micSrc.audio.muted : false

                    // Enlaza el nodo para que `muted` sea válido (patrón de
                    // VolumeOsd/MicSection).
                    PwObjectTracker {
                        objects: micTile.micSrc ? [micTile.micSrc] : []
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: micTile.micMuted
                            ? (micHover.containsMouse ? quickAccess.cardHover : quickAccess.cardBg)
                            : Settings.selectionBg
                        Behavior on color { ColorAnimation { duration: 80 } }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        SymbolicIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            path: micTile.micMuted ? Icons.micOff : Icons.mic
                            color: micTile.micMuted ? Settings.red : Settings.accent
                            implicitSize: 20
                        }
                    }

                    MouseArea {
                        id: micHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (micTile.micSrc && micTile.micSrc.audio)
                                micTile.micSrc.audio.muted = !micTile.micSrc.audio.muted;
                        }
                    }
                }
            }


            Process {
                id: btUnblockProc
                command: ["rfkill", "unblock", "bluetooth"]
                onRunningChanged: if (!running && Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = true
            }

            // ── Acciones rápidas (Ajustes, Captura, Bloquear, Apagar) ──
            // Cierran el menú antes de ejecutarse: las ventanas que abren
            // (ajustes, captura, wlogout) toman el foco y no deben competir
            // con el HyprlandFocusGrab de este panel.
            Row {
                width: parent.width
                height: 80
                spacing: 6

                // ── Ajustes ────────────────────────────────
                Item {
                    width: (parent.width - 18) / 4
                    height: parent.height

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: settingsHover.containsMouse ? quickAccess.cardHover : quickAccess.cardBg
                        Behavior on color { ColorAnimation { duration: 80 } }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        SymbolicIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            path: Icons.settings
                            color: Settings.muted
                            implicitSize: 20
                        }
                    }

                    MouseArea {
                        id: settingsHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            quickAccess.visible = false;
                            if (quickAccess.onOpenSettings) quickAccess.onOpenSettings();
                        }
                    }
                }

                // ── Captura ────────────────────────────────
                Item {
                    width: (parent.width - 18) / 4
                    height: parent.height

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: shotHover.containsMouse ? quickAccess.cardHover : quickAccess.cardBg
                        Behavior on color { ColorAnimation { duration: 80 } }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        SymbolicIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            path: Icons.camera
                            color: Settings.muted
                            implicitSize: 20
                        }
                    }

                    MouseArea {
                        id: shotHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            quickAccess.visible = false;
                            if (quickAccess.onScreenshot) quickAccess.onScreenshot();
                        }
                    }
                }

                // ── Bloquear ────────────────────────────────
                Item {
                    width: (parent.width - 18) / 4
                    height: parent.height

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: lockHover.containsMouse ? quickAccess.cardHover : quickAccess.cardBg
                        Behavior on color { ColorAnimation { duration: 80 } }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        SymbolicIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            path: Icons.lock
                            color: Settings.muted
                            implicitSize: 20
                        }
                    }

                    MouseArea {
                        id: lockHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            quickAccess.visible = false;
                            if (quickAccess.onLockScreen) quickAccess.onLockScreen();
                        }
                    }
                }

                // ── Apagar (abre el overlay de wlogout) ────
                Item {
                    width: (parent.width - 18) / 4
                    height: parent.height

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: powerHover.containsMouse ? quickAccess.cardHover : quickAccess.cardBg
                        Behavior on color { ColorAnimation { duration: 80 } }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        SymbolicIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            path: Icons.power
                            color: Settings.muted
                            implicitSize: 20
                        }
                    }

                    MouseArea {
                        id: powerHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            quickAccess.visible = false;
                            if (quickAccess.onToggleWlogout) quickAccess.onToggleWlogout();
                        }
                    }
                }
            }

            // ── Mosaico de widgets de información ──
            // Dos columnas independientes niveladas por su borde superior:
            // la izquierda apila Sistema (con la bandeja integrada al final
            // de su tarjeta) y Clima; la derecha apila Almacenamiento y GPU.
            // Al no estar en rejilla, la GPU sube pegada bajo Almacenamiento
            // con el mismo hueco de 12px (sin el espacio muerto que dejaba
            // la fila de la rejilla anterior) y además se estira hasta el
            // mismo borde inferior que Clima, así las dos columnas cierran
            // al ras y el bloque se ve como un rectángulo desde fuera.
            Item {
                id: mosaicGrid
                width: parent.width
                height: Math.max(mosaicLeft.height, mosaicRight.height)
                implicitHeight: height

                // ── Columna izquierda: Sistema (con bandeja) | Clima ──
                Column {
                    id: mosaicLeft
                    width: (parent.width - 12) / 2
                    spacing: 12
                    SystemWidget {
                        id: systemWidget
                        anchorWindow: quickAccess
                        panelActive: quickAccess.visible
                    }
                    WeatherWidget {
                        id: weatherWidget
                        panelActive: quickAccess.visible
                    }
                }

                // ── Columna derecha: Almacenamiento | GPU ──
                // La GPU se estira (WidgetShell.stretch) hasta el borde
                // inferior de la columna izquierda: su alto = izquierda
                // menos el Almacenamiento y el hueco de 12px.
                Column {
                    id: mosaicRight
                    x: mosaicLeft.width + 12
                    width: (parent.width - 12) / 2
                    spacing: 12
                    StorageWidget {
                        id: storageWidget
                        panelActive: quickAccess.visible
                    }
                    Item {
                        width: parent.width
                        height: mosaicLeft.height - storageWidget.height - 12
                        GpuWidget {
                            id: gpuWidget
                            stretch: true
                            panelActive: quickAccess.visible
                        }
                    }
                }
            }

            // ── Batería (solo si hay BAT*) ──
            Item {
                width: parent.width
                height: Settings.hasBattery ? implicitHeight : 0
                visible: Settings.hasBattery
                implicitHeight: 70
                BatteryWidget { panelActive: quickAccess.visible }
            }

            // ── Fila Red + Tiempo (rellena el hueco bajo el mosaico) ──
            // Dos tarjetas lado a lado: velocidad de red en vivo y tiempo
            // de uso del sistema. Se estiran hasta el borde inferior de la
            // columna (su alto = lo que sobra tras tiles + acciones + el
            // mosaico), así la derecha cierra al ras como el mosaico.
            Item {
                width: parent.width
                height: Math.max(0, columnsRow.height - 80 - 80 - mosaicGrid.height - 12 * 4 - (Settings.hasBattery ? 70 + 12 : 0))

                Row {
                    width: parent.width
                    height: parent.height
                    spacing: 12

                    Item {
                        width: (parent.width - 12) / 2
                        height: parent.height
                        NetWidget {
                            stretch: true
                            panelActive: quickAccess.visible
                        }
                    }

                    Item {
                        width: (parent.width - 12) / 2
                        height: parent.height
                        UptimeWidget {
                            stretch: true
                            panelActive: quickAccess.visible
                        }
                    }
                }
            }
        }
        }
    }
    }
}
