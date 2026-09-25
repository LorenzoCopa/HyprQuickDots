import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Io
import Quickshell.Services.Mpris
import "../launcher"
import "../config"

Rectangle {
    id: root
    required property LockContext context
    color: Settings.bg

    property var date: new Date()

    // ── Fondo: captura previa de la pantalla, desenfocada y oscurecida ──
    // `screenName` lo inyecta SessionLock.qml desde el screen de la
    // WlSessionLockSurface (no es accesible vía parent aquí). En cuanto
    // SessionLock bloquea, grim captura cada output a
    // /tmp/qs-lockshot-<output>.png; si el archivo existe se usa él (lo que
    // había en pantalla en el momento del bloqueo), y si no (grim falló o
    // tardó), se cae al wallpaper actual con el cache de awww.
    property string screenName: ""
    property string wallpaperSource: ""
    property bool _resolving: false

    // Captura del monitor: existe solo si SessionLock la tomó al bloquear.
    property string shotSource: root.screenName !== "" ? "file:///tmp/qs-lockshot-" + root.screenName + ".png" : ""

    // OJO: el command se construye AQUÍ (no como binding) porque un binding
    // dependiente de screenName se re-evalúa DESPUÉS de onScreenNameChanged
    // (evaluación perezosa de QML) y el Process arrancaría con el valor
    // caducado (m="") sin resolución. Además se espera a que la superficie
    // esté dimensionada (width/height > 0), porque al crearse aún es 0.
    function tryResolveWallpaper() {
        if (root._resolving || root.wallpaperSource !== "") return;
        if (root.screenName === "" || root.width <= 0 || root.height <= 0) return;
        root._resolving = true;
        wallpaperProc.command = ["sh", "-c", root.wallpaperCmd(root.screenName, Math.round(root.width), Math.round(root.height))];
        wallpaperProc.running = true;
    }

    function wallpaperCmd(m, w, h) {
        return [
            "m=\"" + m + "\"; p=\"\";",
            // 1) cache de awww por nombre de output
            "f=$(ls ~/.cache/awww/*/$m 2>/dev/null | sort -V | tail -n1);",
            "[ -n \"$f\" ] && p=$(tr '\\0' '\\n' < \"$f\" | grep -iE '\\.(png|jpg|jpeg|webp|gif)$' | tail -n1);",
            // 2) awww query por nombre de output
            "[ -z \"$p\" ] && p=$(awww query 2>/dev/null | sed -n \"s/.*: " + m + ": .*image: \\([^ ]*\\).*/\\1/p\" | tail -n1);",
            // 3) awww query por geometría (si el nombre no coincide)
            "[ -z \"$p\" ] && p=$(awww query 2>/dev/null | sed -n \"s/.*: [^:]*: " + w + "x" + h + ", .*image: \\([^ ]*\\).*/\\1/p\" | tail -n1);",
            // 4) awww query: cualquier output con imagen
            "[ -z \"$p\" ] && p=$(awww query 2>/dev/null | grep -oE 'image: [^ ]+' | head -n1 | cut -d' ' -f2);",
            "echo \"$p\""
        ].join(" ");
    }

    onScreenNameChanged: root.tryResolveWallpaper()
    onWidthChanged: root.tryResolveWallpaper()
    onHeightChanged: root.tryResolveWallpaper()

    Process {
        id: wallpaperProc
        command: []
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root._resolving = false;
                const p = text.trim();
                if (p !== "")
                    root.wallpaperSource = "file://" + p;
            }
        }
    }

    // Captura previa de la pantalla (SessionLock la toma antes de bloquear).
    Image {
        id: shotImg
        anchors.fill: parent
        source: root.shotSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: status === Image.Ready
        // Mitad de resolución: suficiente para un fondo desenfocado y abarata el blur.
        sourceSize.width: Math.max(1, Math.round(root.width * 0.5))
        sourceSize.height: Math.max(1, Math.round(root.height * 0.5))
    }

    // Fallback: wallpaper actual del monitor si no hay captura.
    Image {
        id: wallpaperImg
        anchors.fill: parent
        source: root.wallpaperSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: status === Image.Ready
        // Mitad de resolución: suficiente para un fondo desenfocado y abarata el blur.
        // Se re-evalúa al cambiar el tamaño de la superficie (al inicio es 0).
        sourceSize.width: Math.max(1, Math.round(root.width * 0.5))
        sourceSize.height: Math.max(1, Math.round(root.height * 0.5))
    }

    MultiEffect {
        anchors.fill: parent
        source: shotImg.visible ? shotImg : wallpaperImg
        visible: shotImg.visible || wallpaperImg.visible
        blurEnabled: true
        blur: 0.55
        // OJO (Qt 6, QtQuick.Effects.MultiEffect): `saturation` va de -1.0
        // (totalmente desaturado) a ∞ y `0.0` es el valor por defecto = NO
        // cambia nada. Antes se ponía `saturation: 0.0` creyendo que dejaba el
        // fondo en grises, pero no hacía nada: el wallpaper seguía en color y
        // al oscurecerlo -0.45 el mauve (wallhaven-r26ez7) viraba a
        // marrón/ámbar "amarillento". Se mantiene el color real del wallpaper
        // (es lo que se quiere ver) y el ámbar se evita no oscureciendo tanto.
        // Para un gris neutro habría que usar saturation: -1.0.
        brightness: -0.15
        saturation: 0.0
    }

    // Velo oscuro para legibilidad sobre el wallpaper (más ligero que
    // Settings.scrim para que el wallpaper se distinga).
    Rectangle {
        anchors.fill: parent
        color: "#66000000"
    }

    Timer {
        running: root.visible
        repeat: true
        interval: 1000
        onTriggered: root.date = new Date()
    }

    // Parpadeo de los dos puntos del reloj (estilo LED, como ClockBox).
    property real colonOpacity: 1.0
    Timer {
        running: root.visible
        repeat: true
        interval: 1000
        onTriggered: root.colonOpacity = root.colonOpacity === 1.0 ? 0.12 : 1.0
    }

    Component.onCompleted: {
        root.updatePlayer();
    }

    // ── Reloj seven-segment escalado + fecha ──────────────────────────
    Item {
        id: clockArea
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: parent.height * 0.25
        }

        readonly property real ts: 3.0

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 136 * clockArea.ts
                height: 50 * clockArea.ts

                Row {
                    anchors.centerIn: parent
                    transformOrigin: Item.Center
                    scale: clockArea.ts
                    spacing: 2

                    SevenSegmentDigit { value: Math.floor(root.date.getHours() / 10) }
                    SevenSegmentDigit { value: root.date.getHours() % 10 }

                    Item {
                        width: 24
                        height: 50

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 13
                            width: 6
                            height: 6
                            radius: 3
                            color: Settings.accent
                            opacity: root.colonOpacity
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 13
                            width: 6
                            height: 6
                            radius: 3
                            color: Settings.accent
                            opacity: root.colonOpacity
                        }
                    }

                    SevenSegmentDigit { value: Math.floor(root.date.getMinutes() / 10) }
                    SevenSegmentDigit { value: root.date.getMinutes() % 10 }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                color: Settings.subtext0
                font.family: Settings.fontFamily
                font.pixelSize: 18
                font.weight: Font.Medium
                text: {
                    const d = root.date;
                    const days = ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"];
                    const months = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
                                   "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"];
                    return days[d.getDay()] + ", " + d.getDate() + " de " + months[d.getMonth()];
                }
            }
        }
    }

    ColumnLayout {
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.verticalCenter
            topMargin: 40
        }
        spacing: 12

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 260
                Layout.preferredHeight: 40
                radius: 8
                color: Settings.surface

                TextInput {
                    id: passwordInput
                    anchors.fill: parent
                    anchors.margins: 1
                    leftPadding: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Settings.fg
                    font.family: Settings.fontFamily
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    passwordMaskDelay: 0
                    clip: true
                    focus: true
                    enabled: !root.context.unlockInProgress
                    onTextChanged: root.context.currentText = this.text
                    onAccepted: root.context.tryUnlock()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        leftPadding: 12
                        visible: passwordInput.text.length === 0
                        color: Settings.subtext0
                        font.family: Settings.fontFamily
                        font.pixelSize: 18
                        font.weight: Font.Medium
                        text: "Contraseña..."
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 8
                color: btnArea.containsMouse ? Settings.selectionBg : Settings.surface

                SymbolicIcon {
                    anchors.centerIn: parent
                    color: Settings.fg
                    implicitSize: 16
                    path: Icons.lock
                }

                MouseArea {
                    id: btnArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.context.tryUnlock()
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: root.context.showFailure
            color: Settings.red
            font.family: Settings.fontFamily
            font.pixelSize: 13
            font.weight: Font.Medium
            text: "Contraseña incorrecta"
        }
    }

    // ── Reproduciendo ahora (Mpris) ───────────────────────────────────
    property MprisPlayer activePlayer: null
    readonly property bool hasPlayer: root.activePlayer != null && root.activePlayer.trackTitle !== ""

    function updatePlayer() {
        const next = Settings.findActiveMprisPlayer();
        if (next !== root.activePlayer) {
            root.activePlayer = next;
        } else {
            root.refreshArt();
        }
    }

    // Recarga del arte sin caché (mismo patrón que MediaPanel): si se
    // reutilizara el mismo URL, la caché de Qt devolvería la miniatura
    // anterior. Se limpia el source y se aplica el nuevo en el siguiente
    // frame para que el viejo no parpadee.
    function refreshArt() {
        const url = root.activePlayer ? String(root.activePlayer.trackArtUrl || "") : "";
        if (String(artImage.source) === url)
            return;
        artImage.source = "";
        Qt.callLater(() => { artImage.source = url; });
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible
        onTriggered: root.updatePlayer()
    }

    onVisibleChanged: {
        if (root.visible) {
            root.updatePlayer();
            root.refreshArt();
        }
    }

    onActivePlayerChanged: root.refreshArt()

    Connections {
        target: root.activePlayer
        function onTrackChanged() {
            root.refreshArt();
        }
    }

    Rectangle {
        id: mediaCard
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: hint.top
            bottomMargin: 16
        }
        visible: root.hasPlayer
        radius: 12
        color: Settings.surface
        width: mediaRow.implicitWidth + 16
        height: mediaRow.implicitHeight + 16

        Row {
            id: mediaRow
            anchors.centerIn: parent
            spacing: 10

            Rectangle {
                width: 56
                height: 56
                radius: 10
                color: Settings.selectionBg
                clip: true

                Image {
                    id: artImage
                    anchors.fill: parent
                    source: root.activePlayer ? root.activePlayer.trackArtUrl : ""
                    sourceSize {
                        width: 56
                        height: 56
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
                    color: Settings.subtext0
                    implicitSize: 26
                }
            }

            Column {
                width: 220
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    text: root.activePlayer ? root.activePlayer.trackTitle : ""
                    color: Settings.fg
                    font.family: Settings.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    width: parent.width
                    text: root.activePlayer ? (root.activePlayer.trackArtist || "Artista desconocido") : ""
                    color: Settings.subtext0
                    font.family: Settings.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }
    }

    Text {
        id: hint
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 24
        }
        color: Settings.subtext0
        font.family: Settings.fontFamily
        font.pixelSize: 12
        text: "Escribe tu contraseña para desbloquear"
    }
}