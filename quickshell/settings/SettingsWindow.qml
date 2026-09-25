// ─── Ventana de configuración del sistema (Quickshell) ──────────────
// Se abre con SUPER+COMMA, desde el engranaje del popup de reloj o
// desde la entrada "Configuración" del launcher.
// Layout: barra lateral de secciones a la izquierda + contenido a la
// derecha. Cada sección es un Component de QML.
//
// Para añadir una sección nueva:
//   1) Define un Component (como appearanceSection).
//   2) Añade su entrada a `sections` (título + icono).
//   3) Añade un case en el Loader del contenido.
// Los índices de `sections` y los `case` del Loader deben coincidir.

pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import "../config"

    FloatingWindow {
    id: settingsWindow
    color: "transparent"
    implicitWidth: 680
    // 520 da para el contenido; la barra lateral tiene Flickable, así que si
    // se añaden más secciones las últimas scrollean en vez de quedar cortadas.
    implicitHeight: 520
    title: "qs-settings"
    visible: false

    // Sobre un juego fullscreen el foco inicial puede quedarse en el juego
    // (constraint del puntero); pedirlo por dispatcher rompe el bloqueo.
    SelfFocus {
        targetTitle: "qs-settings"
        active: settingsWindow.visible
    }

    // ── Sección elegida en la barra lateral ─────────────────────
    property int currentSection: 0

    // ── Catálogo de secciones (sidebar) ─────────────────────────
    // Hardware-adaptativo: micrófono oculto total si no hay fuente
    // (Settings.hasMic). El Loader usa id, no índice fijo.
    readonly property var _allSections: [
        { id: "appearance", title: "Apariencia", icon: Icons.settings },
        { id: "apps",       title: "Aplicaciones", icon: Icons.apps },
        { id: "bar",        title: "Barra", icon: Icons.monitor },
        { id: "power",      title: "Suspensión", icon: Icons.suspend },
        { id: "energy",     title: "Energía", icon: Icons.power },
        { id: "light",      title: "Luz nocturna", icon: Icons.nightlight },
        { id: "bluetooth",  title: "Bluetooth", icon: Icons.bluetooth },
        { id: "mic",        title: "Micrófono", icon: Icons.mic },
        { id: "audio",      title: "Audio", icon: Icons.volumeHigh },
        { id: "dictation",  title: "Dictado", icon: Icons.mic },
        { id: "shortcuts",  title: "Atajos", icon: Icons.keyboard },
    ]
    readonly property var sections: {
        var out = [];
        for (var i = 0; i < _allSections.length; i++) {
            var s = _allSections[i];
            if (s.id === "mic" && !Settings.hasMic) continue;
            out.push(s);
        }
        return out;
    }
    onSectionsChanged: {
        if (currentSection >= sections.length) currentSection = Math.max(0, sections.length - 1);
    }

    Component {
        id: appearanceSection
        ThemeSection {}
    }

    Component {
        id: appsSection
        AppsSection {}
    }

    Component {
        id: barSection
        BarSection {}
    }

    Component {
        id: powerSection
        PowerSection {}
    }

    Component {
        id: energySection
        EnergySection {}
    }

    Component {
        id: lightSection
        LightSection {}
    }

    Component {
        id: bluetoothSection
        BluetoothSection {}
    }

    Component {
        id: micSection
        MicSection {}
    }

    Component {
        id: audioSection
        AudioSection {}
    }

    Component {
        id: dictationSection
        DictationSection {}
    }

    Component {
        id: shortcutsSection
        ShortcutsSection {}
    }

    function toggle(): void {
        settingsWindow.visible = !settingsWindow.visible;
    }

    function open(): void {
        settingsWindow.visible = true;
    }

    function close(): void {
        settingsWindow.visible = false;
    }

    // Navegación entre secciones (SUPER+CTRL+P/N): sube/baja en la barra
    // lateral con wrap-around. Si la ventana está cerrada la abre.
    function stepSection(dir: int): void {
        if (!settingsWindow.visible)
            settingsWindow.open();
        var n = settingsWindow.sections.length;
        settingsWindow.currentSection = (settingsWindow.currentSection + dir + n) % n;
    }

    // Abre directamente la sección de atajos (buscador de binds).
    function openShortcuts(): void {
        settingsWindow.open();
        for (var i = 0; i < settingsWindow.sections.length; i++)
            if (settingsWindow.sections[i].id === "shortcuts") {
                settingsWindow.currentSection = i;
                break;
            }
    }

    // ── Comunicación IPC: `qs ipc call settings toggle` ──────────
    IpcHandler {
        target: "settings"
        function toggle(): void { settingsWindow.toggle(); }
        function open(): void { settingsWindow.open(); }
        function close(): void { settingsWindow.close(); }
        function previous(): void { settingsWindow.stepSection(-1); }
        function next(): void { settingsWindow.stepSection(1); }
        function shortcuts(): void { settingsWindow.openShortcuts(); }
    }

    // ─── Fondo (esquinas rectas: la ventana va en mosaico) ──────
    Rectangle {
        id: bg
        anchors.fill: parent
        focus: settingsWindow.visible
        Keys.onEscapePressed: settingsWindow.visible = false
        // Navegación de secciones con CTRL+P/N (mismo patrón que el
        // launcher: Keys.onPressed sobre el elemento con foco). P sube,
        // N baja, con wrap-around; si la ventana está cerrada la abre.
        Keys.onPressed: event => {
            if (event.modifiers & Qt.ControlModifier) {
                if (event.key === Qt.Key_P) {
                    settingsWindow.stepSection(-1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_N) {
                    settingsWindow.stepSection(1);
                    event.accepted = true;
                }
            }
        }

        color: Settings.bg
        radius: 0

        Text {
            id: title
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 16
            text: "Configuración"
            color: Settings.fg
            font.family: Settings.fontFamily
            font.pixelSize: 18
            font.weight: Font.Bold
        }

        // ── Cuerpo: barra lateral + contenido ────────────────────
        Item {
            anchors.top: title.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 16
            anchors.topMargin: 16

            // Barra lateral de secciones
            // Con Flickable: si las entradas no caben (ventana baja o muchas
            // secciones), se desplazan con la rueda del ratón en vez de
            // quedar cortadas por abajo.
            Rectangle {
                id: sidebar
                width: 180
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                color: Settings.surface
                radius: 10
                clip: true

                Flickable {
                    id: sideFlick
                    anchors.fill: parent
                    anchors.margins: 6
                    contentWidth: width
                    contentHeight: sideCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: sideCol
                        width: sideFlick.width
                        spacing: 4

                        Repeater {
                            model: settingsWindow.sections

                            delegate: Rectangle {
                                required property int index
                                required property var modelData

                                width: parent.width
                                height: 38
                                radius: 8
                                color: settingsWindow.currentSection === index ? Settings.selectionBg : "transparent"
                                Behavior on color { ColorAnimation { duration: Settings.animationFast } }

                                Row {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 10
                                    spacing: 8

                                    SymbolicIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        path: modelData.icon
                                        color: Settings.fg
                                        implicitSize: 18
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.title
                                        color: Settings.fg
                                        font.family: Settings.fontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: settingsWindow.currentSection = index
                                }
                            }
                        }
                    }

                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                }
            }

            // Contenido de la sección elegida
            Rectangle {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: sidebar.right
                anchors.right: parent.right
                anchors.leftMargin: 16
                color: "transparent"

                Loader {
                    anchors.fill: parent
                    sourceComponent: {
                        var id = settingsWindow.sections[settingsWindow.currentSection] ? settingsWindow.sections[settingsWindow.currentSection].id : "";
                        switch (id) {
                            case "appearance": return appearanceSection;
                            case "apps": return appsSection;
                            case "bar": return barSection;
                            case "power": return powerSection;
                            case "energy": return energySection;
                            case "light": return lightSection;
                            case "bluetooth": return bluetoothSection;
                            case "mic": return micSection;
                            case "audio": return audioSection;
                            case "dictation": return dictationSection;
                            case "shortcuts": return shortcutsSection;
                            default: return null;
                        }
                    }
                }
            }
        }
    }
}
