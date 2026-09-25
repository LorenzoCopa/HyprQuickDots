pragma ComponentBehavior: Bound

// Reproductor "hero now-playing" del QuickAccess (SUPER+B). Layout en
// cuadrícula 2×3 (estilo del diseño de referencia que se le pasó):
//   izquierda: carátula / canción / artista
//   derecha:   visualizador / tiempo / botones
// La carátula es cuadrada y nítida (sin fondo desenfocado); el visualizador
// es un panel con un ecualizador de barras (Canvas que anima cada barra con
// el nivel de audio real medido, con factor pseudoaleatorio fijo por barra
// para que no suban todas igual); debajo van el tiempo (barra de progreso
// con minutos a los lados, o LIVE) y los controles compactos
// (anterior/play/siguiente + repetir si el reproductor lo soporta).

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../config"

Item {
    id: root

    property MprisPlayer activePlayer: null
    readonly property bool hasPlayer: activePlayer != null && activePlayer.trackTitle !== ""
    property bool panelActive: false
    property bool showPeaks: true

    // Altura fija del contenido (sin relleno): 142px siempre, con o sin
    // reproductor. Así la card no cambia de tamaño al empezar/parar música
    // y la altura común de las columnas del QuickAccess no salta (el hueco
    // de la columna derecha queda estable).
    readonly property real contentHeight: 142

    // ── Position tracker ──
    property real trackPos: 0
    property real trackLen: 0

    // En vivo: el reproductor no expone duración (mpris:length ausente o 0),
    // la posición no es significativa o reporta una duración absurda. Se
    // muestra LIVE en lugar del tiempo y se oculta la barra de progreso.
    readonly property bool isLive: {
        if (!root.hasPlayer || !root.activePlayer.isPlaying)
            return false;
        const meta = root.activePlayer.metadata;
        if (meta && meta["mpris:live"] === true)
            return true;
        return root.trackLen <= 0 || root.trackLen > 86400;
    }

    Timer {
        interval: 500
        repeat: true
        running: root.activePlayer != null && root.panelActive
        onTriggered: {
            var p = root.activePlayer;
            if (!p)
                return;

            var pos = p.position;
            var len = p.length;

            if (len > 0 && !isNaN(len))
                root.trackLen = len;

            if (pos >= 0 && !isNaN(pos))
                root.trackPos = Math.min(pos, root.trackLen > 0 ? root.trackLen : pos);
        }
    }

    // ── Player detection (misma lógica que MediaPanel) ──
    function updatePlayer() {
        var next = Settings.findActiveMprisPlayer();
        if (next !== root.activePlayer) {
            root.activePlayer = next;
        } else {
            root.refreshArt();
        }
    }

    onPanelActiveChanged: {
        if (root.panelActive) {
            root.updatePlayer();
            root.refreshArt();
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.panelActive
        onTriggered: root.updatePlayer()
    }

    Component.onCompleted: root.updatePlayer()

    onActivePlayerChanged: root.refreshArt()

    Connections {
        target: root.activePlayer
        function onTrackChanged() {
            root.refreshArt();
        }
    }

    // Recarga del arte sin caché (mismo patrón que MediaPanel).
    function refreshArt() {
        var url = root.activePlayer ? String(root.activePlayer.trackArtUrl || "") : "";
        if (String(heroArt.source) === url)
            return;
        heroArt.source = "";
        Qt.callLater(() => { heroArt.source = url; });
    }

    // ── Pipewire peaks ──
    readonly property var audioSink: Pipewire.ready ? Pipewire.defaultAudioSink : null

    PwNodePeakMonitor {
        id: heroPeakMonitor
        node: root.audioSink
        enabled: root.audioSink != null && root.panelActive
    }

    readonly property real currentPeak: heroPeakMonitor.peak || 0

    function formatTime(sec) {
        if (!sec || sec <= 0)
            return "0:00";
        const total = Math.floor(sec);
        return Math.floor(total / 60) + ":" + ("0" + (total % 60)).slice(-2);
    }

    // ── UI ──
    Item {
        anchors.fill: parent

        // ── Sin reproducción ─────────────────────────────
        Column {
            anchors.centerIn: parent
            visible: !root.hasPlayer
            spacing: 8

            SymbolicIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                path: Icons.music
                color: Settings.surface
                implicitSize: 42
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Sin reproducción"
                color: Settings.muted
                font.family: Settings.fontFamily
                font.pixelSize: 12
            }
        }

        // ── Estado reproduciendo ─────────────────────────
        Item {
            anchors.fill: parent
            visible: root.hasPlayer

            // Contenedor: ambas columnas se centran verticalmente y ocupan el
            // mismo alto (142px), balanceando carátula+canción+artista con
            // visualizador+tiempo+botones.
            Item {
                anchors.fill: parent

                // ── Columna izquierda: carátula / canción / artista ──
                Column {
                    id: leftCol
                    width: 92
                    height: 142
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // ── Carátula (cuadrada, nítida) ──
                    Item {
                        id: artWrap
                        width: 80
                        height: 80
                        anchors.horizontalCenter: parent.horizontalCenter

                        // Sombra suave para que el arte flote sobre el fondo.
                        Rectangle { x: 0; y: 2; width: parent.width; height: parent.height; radius: 15; color: "#26000000" }
                        Rectangle { x: 0; y: 5; width: parent.width; height: parent.height; radius: 16; color: "#18000000" }
                        Rectangle { x: 0; y: 8; width: parent.width; height: parent.height; radius: 17; color: "#0E000000" }

                        Rectangle {
                            id: artClip
                            anchors.fill: parent
                            radius: 13
                            clip: true
                            color: Settings.surface

                            Image {
                                id: heroArt
                                anchors.fill: parent
                                source: root.activePlayer ? root.activePlayer.trackArtUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                sourceSize {
                                    width: 480
                                    height: 480
                                }
                                visible: status === Image.Ready
                                asynchronous: true
                                cache: false
                            }

                            // Fallback sin arte: degradado suave + icono.
                            Rectangle {
                                anchors.fill: parent
                                visible: !heroArt.visible
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: Settings.selectionBg }
                                    GradientStop { position: 1.0; color: "#121212" }
                                }
                            }

                            SymbolicIcon {
                                anchors.centerIn: parent
                                visible: !heroArt.visible
                                path: Icons.music
                                color: Settings.muted
                                implicitSize: 24
                            }
                        }
                    }

                    // Título (hasta 2 líneas, o deslizante si es muy largo) +
                    // artista·álbum (deslizante si no cabe).
                    MarqueeText {
                        width: parent.width
                        text: root.activePlayer ? root.activePlayer.trackTitle : ""
                        color: Settings.fg
                        fontFamily: Settings.fontFamily
                        fontPixelSize: 12
                        fontWeight: Font.Bold
                        maxLines: 2
                    }

                    MarqueeText {
                        width: parent.width
                        text: {
                            if (!root.activePlayer)
                                return "";
                            const a = root.activePlayer.trackArtist || "";
                            const al = root.activePlayer.trackAlbum || "";
                            if (a && al) return a + " \u00b7 " + al;
                            return a || al || "Artista desconocido";
                        }
                        color: Settings.muted
                        fontFamily: Settings.fontFamily
                        fontPixelSize: 10
                        fontWeight: Font.Normal
                        maxLines: 1
                    }
                }

                // ── Columna derecha: visualizador / tiempo / botones ──
                ColumnLayout {
                    id: rightCol
                    width: parent.width - leftCol.width - leftCol.anchors.leftMargin - 12
                    height: 142
                    anchors.left: leftCol.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // ── Visualizador (panel con ecualizador) ──
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: root.showPeaks

                        // Sin panel de fondo: el ecualizador se pinta sobre el
                        // propio fondo de la card (cardBg, negro), fundido.
                        Canvas {
                            id: eqCanvas
                            anchors.fill: parent

                            // Nivel por barra (suavizado ataque rápido/caída
                            // lenta) y factor pseudoaleatorio fijo para que
                            // cada barra tenga su propia "personalidad" (no
                            // todas suben igual).
                            readonly property int barCount: 18
                            property var levels: []
                            property var factors: []

                            // Valor pseudoaleatorio estable por índice.
                            function barFactor(i) {
                                const x = Math.sin(i * 12.9898) * 43758.5453;
                                return x - Math.floor(x);
                            }

                            Timer {
                                interval: 33
                                repeat: true
                                running: root.hasPlayer && root.showPeaks && root.panelActive
                                onTriggered: {
                                    const peak = root.currentPeak || 0;
                                    for (let i = 0; i < eqCanvas.barCount; i++) {
                                        const target = peak * (0.25 + 0.75 * eqCanvas.factors[i]);
                                        const cur = eqCanvas.levels[i];
                                        const k = target > cur ? 0.45 : 0.1;
                                        eqCanvas.levels[i] = cur + (target - cur) * k;
                                    }
                                    eqCanvas.requestPaint();
                                }
                            }

                            Component.onCompleted: {
                                for (let i = 0; i < eqCanvas.barCount; i++) {
                                    eqCanvas.levels.push(0);
                                    eqCanvas.factors.push(eqCanvas.barFactor(i + 1));
                                }
                            }

                            // Barra redondeada por arriba (roundRect no existe en
                            // el Canvas de quickshell: se traza con arcos a mano).
                            function drawBar(ctx, x, y, w, h, r) {
                                const rr = Math.min(r, h / 2);
                                ctx.beginPath();
                                ctx.moveTo(x, y + h);
                                ctx.lineTo(x, y + rr);
                                ctx.arcTo(x, y, x + rr, y, rr);
                                ctx.lineTo(x + w - rr, y);
                                ctx.arcTo(x + w, y, x + w, y + rr, rr);
                                ctx.lineTo(x + w, y + h);
                                ctx.closePath();
                                ctx.fill();
                            }

                            onPaint: {
                                const ctx = eqCanvas.getContext("2d");
                                const w = eqCanvas.width;
                                const h = eqCanvas.height;
                                ctx.reset();
                                ctx.clearRect(0, 0, w, h);

                                const gap = 3;
                                const barW = (w - gap * (eqCanvas.barCount - 1)) / eqCanvas.barCount;
                                const maxH = h * 0.95;
                                const r = barW / 2;

                                for (let i = 0; i < eqCanvas.barCount; i++) {
                                    const level = Math.min(1, eqCanvas.levels[i]);
                                    const barH = Math.max(3, level * maxH);
                                    const x = i * (barW + gap);
                                    const y = h - barH;

                                    // Barra redondeada; el brillo sube con el audio.
                                    ctx.globalAlpha = 0.25 + 0.75 * level;
                                    ctx.fillStyle = Settings.accent;
                                    eqCanvas.drawBar(ctx, x, y, barW, barH, r);
                                    ctx.globalAlpha = 1;
                                }
                            }
                        }
                    }

                    // ── Tiempo: progreso + minutos a los lados ──
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 16
                        visible: !root.isLive

                        Row {
                            anchors.fill: parent
                            spacing: 8

                            Text {
                                width: 34
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.formatTime(root.trackPos)
                                color: Settings.muted
                                font.family: Settings.fontFamily
                                font.pixelSize: 9
                            }

                            Item {
                                width: parent.width - 34 - 34 - 16
                                height: 4
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 2
                                    color: "#33FFFFFF"
                                }

                                Rectangle {
                                    readonly property real ratio: root.trackLen > 0 ? Math.min(1, root.trackPos / root.trackLen) : 0
                                    width: parent.width * ratio
                                    height: parent.height
                                    radius: 2
                                    color: Settings.accent
                                    Behavior on width {
                                        NumberAnimation {
                                            duration: 100
                                            easing.type: Easing.Linear
                                        }
                                    }
                                }
                            }

                            Text {
                                width: 34
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.trackLen > 0 ? root.formatTime(root.trackLen) : ""
                                color: Settings.muted
                                font.family: Settings.fontFamily
                                font.pixelSize: 9
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }

                    // ── LIVE ─────────────────────────────────
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 16
                        visible: root.isLive

                        Row {
                            anchors.centerIn: parent
                            spacing: 5

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 7
                                height: 7
                                radius: 4
                                color: "#FF5252"
                            }

                            Text {
                                text: "LIVE"
                                color: "#FF5252"
                                font.family: Settings.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.Bold
                            }
                        }
                    }

                    // ── Botones: prev / play / next (+ repetir) ──
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34

                        Row {
                            anchors.centerIn: parent
                            spacing: 10

                            Item {
                                width: 28
                                height: 28

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 14
                                    color: prevMouse.containsMouse ? "#33FFFFFF" : "transparent"
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                }

                                SymbolicIcon {
                                    anchors.centerIn: parent
                                    path: Icons.mediaPrev
                                    color: root.activePlayer && root.activePlayer.canGoPrevious ? Settings.fg : Settings.muted
                                    implicitSize: 16
                                }

                                MouseArea {
                                    id: prevMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        if (root.activePlayer && root.activePlayer.canGoPrevious)
                                            root.activePlayer.previous();
                                    }
                                }
                            }

                            Item {
                                width: 34
                                height: 34

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 17
                                    color: playMouse.containsMouse ? Settings.accent : Settings.selectionBg
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                    scale: playMouse.pressed ? 0.92 : (playMouse.containsMouse ? 1.06 : 1)
                                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                                }

                                SymbolicIcon {
                                    anchors.centerIn: parent
                                    path: root.activePlayer && root.activePlayer.isPlaying ? Icons.mediaPause : Icons.mediaPlay
                                    color: Settings.bg
                                    implicitSize: 20
                                    // El triángulo de play tiene la masa hacia la izquierda
                                    // (centroide a 1/3 del ancho del glifo): centrado por caja
                                    // se percata corrido a la izquierda dentro del círculo.
                                    // Se compensa a la derecha para centrarlo ópticamente.
                                    anchors.horizontalCenterOffset: root.activePlayer && root.activePlayer.isPlaying ? 0 : 1.5
                                }

                                MouseArea {
                                    id: playMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        if (root.activePlayer && root.activePlayer.canPlay)
                                            root.activePlayer.togglePlaying();
                                    }
                                }
                            }

                            Item {
                                width: 28
                                height: 28

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 14
                                    color: nextMouse.containsMouse ? "#33FFFFFF" : "transparent"
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                }

                                SymbolicIcon {
                                    anchors.centerIn: parent
                                    path: Icons.mediaNext
                                    color: root.activePlayer && root.activePlayer.canGoNext ? Settings.fg : Settings.muted
                                    implicitSize: 16
                                }

                                MouseArea {
                                    id: nextMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        if (root.activePlayer && root.activePlayer.canGoNext)
                                            root.activePlayer.next();
                                    }
                                }
                            }

                            // ── Repetir (solo si el reproductor lo soporta):
                            // cicla None → Track (canción) → Playlist → None.
                            Item {
                                width: 28
                                height: 28
                                visible: root.activePlayer && root.activePlayer.loopSupported

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 14
                                    color: repeatMouse.containsMouse ? "#33FFFFFF" : "transparent"
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                }

                                SymbolicIcon {
                                    anchors.centerIn: parent
                                    path: root.activePlayer && root.activePlayer.loopState === MprisLoopState.Track ? Icons.repeatOnce : Icons.repeat
                                    color: root.activePlayer && root.activePlayer.loopState !== MprisLoopState.None ? Settings.accent : Settings.muted
                                    implicitSize: 15
                                }

                                MouseArea {
                                    id: repeatMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        const p = root.activePlayer;
                                        if (!p || !p.canControl || !p.loopSupported)
                                            return;
                                        if (p.loopState === MprisLoopState.None)
                                            p.loopState = MprisLoopState.Track;
                                        else if (p.loopState === MprisLoopState.Track)
                                            p.loopState = MprisLoopState.Playlist;
                                        else
                                            p.loopState = MprisLoopState.None;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}