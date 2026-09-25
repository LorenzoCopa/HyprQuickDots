// ─── Sección de micrófono ─────────────────────────────────────────────
// Silencio (toggle), volumen de entrada y medidor en vivo. Permite elegir
// la fuente por defecto entre los dispositivos que reporta Pipewire.
// Hardware-adaptativo: si no hay micrófono, SettingsWindow oculta la
// sección completa (no deja hueco ni opaco).
//
// Usa la API de Quickshell.Services.Pipewire (igual que VolumeOsd):
//   - `Pipewire.defaultAudioSource` (PwNode) es el micrófono en uso.
//   - `node.audio.muted` / `node.audio.volume` controlan estado y nivel
//     (solo válidos tras enlazar el nodo con PwObjectTracker).
//   - `PwNodePeakMonitor` da el nivel en vivo para el medidor.
//   - `Pipewire.preferredDefaultAudioSource = node` cambia la fuente por
//     defecto (la fuente de verdad de Pipewire; no se persiste nada).

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire
import "../config"

Item {
    id: root

    anchors.fill: parent

    // ── Nodo de entrada por defecto ───────────────────────────
    readonly property var source: Pipewire.ready ? Pipewire.defaultAudioSource : null

    readonly property bool micOn: root.source && root.source.audio
        && typeof root.source.audio.muted === "boolean" ? !root.source.audio.muted : false

    readonly property real volume: root.source && root.source.audio
        && Number.isFinite(root.source.audio.volume) ? root.source.audio.volume : 0

    readonly property string sourceName: root.source ? (root.source.nickname || root.source.description || root.source.name) : ""

    // Enlaza el nodo para que muted/volume sean válidos (patrón de VolumeOsd).
    PwObjectTracker {
        objects: root.source ? [root.source] : []
    }

    // ── Nivel en vivo (para ver la estática al calibrar) ──────
    PwNodePeakMonitor {
        id: peakMon
        node: root.source
        enabled: root.source !== null
    }

    readonly property real peak: peakMon.peak || 0

    // ── Lista de fuentes de entrada disponibles ────────────────
    // Filtra los nodos de Pipewire: con audio, que son fuentes (no sinks)
    // y no son streams de aplicaciones.
    property var sources: []

    function refreshSources(): void {
        const list = [];
        if (!Pipewire.ready || !Pipewire.nodes) return;
        const nodes = Pipewire.nodes.values;
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i];
            if (!n || !n.audio) continue;
            if (n.isSink) continue;
            if (n.isStream) continue;
            list.push(n);
        }
        root.sources = list;
    }

    Connections {
        target: Pipewire
        function onReadyChanged(): void { root.refreshSources(); }
        function onDefaultAudioSourceChanged(): void { root.refreshSources(); }
    }

    Component.onCompleted: root.refreshSources()

    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 10

        Text {
            text: "Micrófono"
            color: Settings.fg
            font.family: Settings.fontFamily
            font.pixelSize: 15
            font.weight: Font.Bold
        }

        Text {
            text: "Activa/silencia el micro, ajusta el volumen de entrada y mira el nivel en vivo. Elige también la fuente de entrada por defecto."
            color: Settings.subtext0
            font.family: Settings.fontFamily
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            width: parent.width
        }

        // ── Estado: toggle silenciar/activar ────────────────
        Row {
            width: parent.width
            spacing: 8

            Rectangle {
                width: 40
                height: 22
                radius: 11
                color: root.micOn ? Settings.green : Settings.surface
                Behavior on color { ColorAnimation { duration: 80 } }

                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    color: Settings.bg
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.micOn ? parent.width - width - 3 : 3
                    Behavior on x { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.source && root.source.audio)
                            root.source.audio.muted = root.micOn;
                    }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    text: root.source ? root.sourceName : "Sin micrófono"
                    color: root.source ? Settings.fg : Settings.subtext0
                    font.family: Settings.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    width: 380
                }

                Text {
                    text: root.source ? (root.micOn ? "Encendido" : "Silenciado") : "No se detecta entrada de audio"
                    color: root.source ? (root.micOn ? Settings.green : Settings.red) : Settings.subtext0
                    font.family: Settings.fontFamily
                    font.pixelSize: 10
                }
            }
        }

        // ── Volumen de entrada ─────────────────────────────
        Row {
            width: parent.width
            spacing: 10

            SymbolicIcon {
                anchors.verticalCenter: parent.verticalCenter
                path: root.micOn ? Icons.mic : Icons.micOff
                color: Settings.fg
                implicitSize: 16
            }

            Slider {
                id: volSlider
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 90
                from: 0
                to: 100
                value: Math.round(root.volume * 100)
                enabled: root.source !== null
                onMoved: {
                    if (root.source && root.source.audio)
                        root.source.audio.volume = value / 100;
                }

                background: Rectangle {
                    x: volSlider.leftPadding + volSlider.availableWidth / 2 - width / 2
                    y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                    width: volSlider.availableWidth
                    height: 4
                    radius: 2
                    color: Settings.surface

                    Rectangle {
                        x: volSlider.leftPadding
                        width: volSlider.visualPosition * volSlider.availableWidth
                        height: parent.height
                        radius: 2
                        color: Settings.accent
                    }
                }

                handle: Rectangle {
                    x: volSlider.leftPadding + volSlider.visualPosition * volSlider.availableWidth - width / 2
                    y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                    implicitWidth: 14
                    implicitHeight: 14
                    radius: 7
                    color: Settings.accent
                    border {
                        width: 2
                        color: Settings.bg
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                horizontalAlignment: Text.AlignRight
                text: Math.round(root.volume * 100) + "%"
                color: Settings.fg
                font.family: Settings.fontFamily
                font.pixelSize: 12
                font.weight: Font.Bold
            }
        }

        // ── Medidor de nivel en vivo ───────────────────────
        Text {
            text: "Nivel de entrada"
            color: Settings.subtext0
            font.family: Settings.fontFamily
            font.pixelSize: 11
            font.weight: Font.Bold
        }

        Rectangle {
            width: parent.width
            height: 10
            radius: 5
            color: Settings.surface

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.peak))
                height: parent.height
                radius: parent.radius
                color: Settings.accent
                Behavior on width { NumberAnimation { duration: 60; easing.type: Easing.Linear } }
            }
        }

        // ── Selección de fuente por defecto ────────────────
        Text {
            text: "Fuente de entrada"
            color: Settings.subtext0
            font.family: Settings.fontFamily
            font.pixelSize: 11
            font.weight: Font.Bold
        }

        ListView {
            width: parent.width
            height: Math.min(132, root.sources.length * 38)
            spacing: 4
            clip: true
            model: root.sources

            delegate: Rectangle {
                id: srcDel
                required property var modelData
                readonly property bool active: root.source && modelData.id === root.source.id

                width: ListView.view.width
                height: 34
                radius: 6
                color: srcDel.active ? Settings.accent : (srcMouse.containsMouse ? Settings.surface : "transparent")
                Behavior on color { ColorAnimation { duration: 80 } }

                Row {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 6

                    SymbolicIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        path: srcDel.active ? Icons.mic : Icons.micOff
                        color: srcDel.active ? Settings.bg : Settings.subtext0
                        implicitSize: 14
                        implicitWidth: 20
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 70
                        text: modelData.nickname || modelData.description || modelData.name
                        color: srcDel.active ? Settings.bg : Settings.fg
                        font.family: Settings.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: srcDel.active
                        width: 46
                        height: 20
                        radius: 4
                        color: Settings.bg

                        Text {
                            anchors.centerIn: parent
                            text: "En uso"
                            color: Settings.accent
                            font.family: Settings.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.Bold
                        }
                    }
                }

                MouseArea {
                    id: srcMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!srcDel.active)
                            Pipewire.preferredDefaultAudioSource = modelData;
                    }
                }
            }
        }

        Text {
            visible: root.sources.length === 0
            text: "No se detectaron fuentes de entrada"
            color: Settings.subtext0
            font.family: Settings.fontFamily
            font.pixelSize: 11
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
