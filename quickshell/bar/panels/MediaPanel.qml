pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../../config"

Item {
    id: root

    property MprisPlayer activePlayer: null
    readonly property bool hasPlayer: activePlayer != null && activePlayer.trackTitle !== ""
    property bool panelActive: false
    // Oculta la visualización de picos de audio (para variantes compactas
    // como el mosaico del QuickAccess; el popup del reloj la conserva).
    property bool showPeaks: true
    // Estira la franja de picos para llenar el cajón alto del QuickAccess
    // (el popup del reloj la mantiene fija en 40px).
    property bool expandPeaks: false

    // ── Position tracker ──
    property real trackPos: 0
    property real trackLen: 0

    // En vivo: el reproductor no expone duración (mpris:length ausente o 0),
    // la posición no es significativa (puede crecer sin límite) o reporta
    // una duración absurda. Se muestra LIVE en lugar del tiempo y se oculta
    // la barra de progreso.
    readonly property bool isLive: {
        if (!root.hasPlayer || !root.activePlayer.isPlaying)
            return false;
        // Bandera estándar MPRIS (la ponen YouTube/Twitch/Chromium, etc.).
        const meta = root.activePlayer.metadata;
        if (meta && meta["mpris:live"] === true)
            return true;
        // Sin duración (radio/directo) o duración absurda (>24h): en un
        // directo algunos reproductores rellenan `length` con basura.
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

    // ── Player detection ──
    function updatePlayer() {
        var next = Settings.findActiveMprisPlayer();
        if (next !== root.activePlayer) {
            root.activePlayer = next;
        } else {
            // Mismo reproductor: el arte puede haber cambiado aunque el
            // objeto no (por eso onActivePlayerChanged no dispara).
            root.refreshArt();
        }
    }

    // Al activarse el panel (abrir el menú/popup) se refresca al instante:
    // si el reproductor apareció o cambió de pista mientras estaba oculto,
    // no hay que esperar al tick de 1s.
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

    // Recarga del arte sin caché: si se reutilizara el mismo URL, la caché
    // de Qt devolvería la miniatura anterior. Se limpia el source y se
    // aplica el nuevo en el siguiente frame para que el viejo no parpadee.
    // OJO: artImage.source es de tipo `url` (QUrl); hay que normalizar con
    // String() ambos lados, o la comparación nunca coincide y el arte se
    // recarga (parpadea) en cada tick del Timer de 1s.
    function refreshArt() {
        var url = root.activePlayer ? String(root.activePlayer.trackArtUrl || "") : "";
        if (String(artImage.source) === url)
            return;
        artImage.source = "";
        Qt.callLater(() => { artImage.source = url; });
    }

    // ── Pipewire peaks ──
    readonly property var audioSink: Pipewire.ready ? Pipewire.defaultAudioSink : null

    PwNodePeakMonitor {
        id: panelPeakMonitor
        node: root.audioSink
        enabled: root.audioSink != null && root.panelActive
    }

    // ── Peak tracker (bind directo, sin Timer) ──
    readonly property real currentPeak: panelPeakMonitor.peak || 0

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

        // ── Fondo: arte desenfocado como backdrop "now playing" ──
        // Hermano (no hijo del ColumnLayout) para ocupar toda la superficie
        // sin robarle filas al contenido.
        Item {
            id: backdrop
            anchors.fill: parent
            visible: root.hasPlayer && artBg.status === Image.Ready

            Image {
                id: artBg
                anchors.fill: parent
                source: root.activePlayer ? String(root.activePlayer.trackArtUrl || "") : ""
                fillMode: Image.PreserveAspectCrop
                // Media resolución: suficiente para un fondo desenfocado y
                // abarata el blur (mismo truco que el lock screen).
                sourceSize {
                    width: 512
                    height: 512
                }
                asynchronous: true
                cache: false
            }

            MultiEffect {
                anchors.fill: parent
                source: artBg
                blurEnabled: true
                blur: 0.85
                saturation: 0.0
                brightness: -0.3
            }

            // Velo oscuro para legibilidad del texto sobre el arte.
            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: 0.55
            }

            // Degradado inferior: apoya el texto y los controles.
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#00000000" }
                    GradientStop { position: 0.6; color: "#B3000000" }
                }
            }
        }

        // ── Estado reproduciendo ─────────────────────────
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6
            visible: root.hasPlayer

            // Arte en miniatura + título/artista (nítidos sobre el fondo).
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 64
                    radius: 12
                    color: Settings.surface
                    clip: true
                    border { width: 1; color: "#33000000" }

                    Image {
                        id: artImage
                        anchors.fill: parent
                        source: root.activePlayer ? root.activePlayer.trackArtUrl : ""
                        sourceSize {
                            width: 128
                            height: 128
                        }
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                        asynchronous: true
                        cache: false
                    }

                    SymbolicIcon {
                        anchors.centerIn: parent
                        visible: !artImage.visible
                        path: Icons.music
                        color: Settings.muted
                        implicitSize: 26
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 3

                    Text {
                        Layout.fillWidth: true
                        text: root.activePlayer ? root.activePlayer.trackTitle : ""
                        color: Settings.fg
                        font.family: Settings.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    // Artista · Álbum en una sola línea.
                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (!root.activePlayer)
                                return "";
                            const a = root.activePlayer.trackArtist || "";
                            const al = root.activePlayer.trackAlbum || "";
                            if (a && al) return a + " \u00b7 " + al;
                            return a || al || "Artista desconocido";
                        }
                        color: Settings.muted
                        font.family: Settings.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
            }

            // ── Progreso + tiempo (o LIVE) ───────────────
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 18
                visible: !root.isLive

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        rightMargin: 56
                        verticalCenter: parent.verticalCenter
                    }
                    height: 5
                    radius: 3
                    color: "#33FFFFFF"

                    Rectangle {
                        readonly property real ratio: root.trackLen > 0 ? Math.min(1, root.trackPos / root.trackLen) : 0
                        width: parent.width * ratio
                        height: parent.height
                        radius: 3
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
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    text: {
                        if (root.trackLen > 0)
                            return root.formatTime(root.trackPos) + " / " + root.formatTime(root.trackLen);
                        if (root.activePlayer && root.activePlayer.isPlaying)
                            return root.formatTime(root.trackPos);
                        return "0:00";
                    }
                    color: Settings.muted
                    font.family: Settings.fontFamily
                    font.pixelSize: 9
                }
            }

            // ── LIVE ─────────────────────────────────────
            Row {
                Layout.alignment: Qt.AlignRight
                Layout.preferredHeight: 18
                visible: root.isLive
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

            // ── Controles unificados en círculos ─────────
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 18

                Item {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36

                    Rectangle {
                        anchors.fill: parent
                        radius: 18
                        color: prevMouse.containsMouse ? "#33FFFFFF" : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }
                    }

                    SymbolicIcon {
                        anchors.centerIn: parent
                        path: Icons.mediaPrev
                        color: root.activePlayer && root.activePlayer.canGoPrevious ? Settings.fg : Settings.muted
                        implicitSize: 18
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
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44

                    Rectangle {
                        anchors.fill: parent
                        radius: 22
                        color: playMouse.containsMouse ? Settings.accent : Settings.selectionBg
                        Behavior on color { ColorAnimation { duration: 80 } }
                        scale: playMouse.pressed ? 0.92 : (playMouse.containsMouse ? 1.06 : 1)
                        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    }

                    SymbolicIcon {
                        anchors.centerIn: parent
                        path: root.activePlayer && root.activePlayer.isPlaying ? Icons.mediaPause : Icons.mediaPlay
                        color: Settings.bg
                        implicitSize: 22
                        // Mismo centrado óptico que MediaHeroPanel: el triángulo
                        // de play se percata a la izquierda sin compensación.
                        anchors.horizontalCenterOffset: root.activePlayer && root.activePlayer.isPlaying ? 0 : 1.7
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
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36

                    Rectangle {
                        anchors.fill: parent
                        radius: 18
                        color: nextMouse.containsMouse ? "#33FFFFFF" : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }
                    }

                    SymbolicIcon {
                        anchors.centerIn: parent
                        path: Icons.mediaNext
                        color: root.activePlayer && root.activePlayer.canGoNext ? Settings.fg : Settings.muted
                        implicitSize: 18
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
            }

            // ── Picos de audio ───────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                Layout.fillHeight: root.expandPeaks
                Layout.bottomMargin: 2
                visible: root.showPeaks
                clip: true

                Row {
                    id: barRow
                    anchors.fill: parent
                    spacing: 2

                    readonly property real peak: root.currentPeak || 0
                    readonly property int barCount: 20
                    readonly property real barWidth: (width - (barCount - 1) * spacing) / barCount

                    Repeater {
                        model: barRow.barCount

                        Item {
                            id: del
                            width: barRow.barWidth
                            height: barRow.height

                            required property int index
                            readonly property real centerDist: Math.abs(index / (barRow.barCount - 1) * 2 - 1)
                            readonly property real multiplier: 0.2 + (1 - centerDist) * 1.3
                            readonly property real barPeak: barRow.peak * multiplier

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width - 1
                                height: Math.max(2, Math.min(parent.height * 0.88, del.barPeak * parent.height * 0.88))
                                radius: width * 0.5
                                color: Settings.accent
                                Behavior on height {
                                    NumberAnimation {
                                        duration: 50 + del.centerDist * 80
                                        easing.type: Easing.OutQuad
                                    }
                                }
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                        }
                    }
                }
            }
        }
    }
}