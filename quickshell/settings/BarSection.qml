// ─── Sección de barra ──────────────────────────────────────────────────
// Elige qué barra usa el shell. La selección se guarda en barstate.json
// (Settings.barType) y se aplica al instante con el botón "Aplicar" (solo
// se reinicia la barra, no todo el shell). El preview es un mock
// decorativo (solo colores de Settings, sin servicios vivos) para no
// duplicar la barra real ni su coste.
// Para añadir un tipo nuevo: añádelo a `types` y un case en el Loader
// de barra de shell.qml.

pragma ComponentBehavior: Bound

import QtQuick
import "../config"

Item {
    id: root

    anchors.fill: parent

    readonly property bool hasChanges: Settings.barType !== Settings.appliedBarType

    readonly property var types: [
        {
            id: "evergarden",
            name: "Predeterminada",
            desc: "La barra actual de HyprQuickDots",
        },
        {
            id: "none",
            name: "Sin barra",
            desc: "No mostrar ninguna barra",
        },
    ]

    function selectBar(id: string): void {
        if (Settings.barType === id)
            return;
        Settings.barType = id;
        if (Settings.writeBarState)
            Settings.writeBarState();
    }

    function apply(): void {
        if (Settings.applyBar)
            Settings.applyBar();
    }

    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Text {
            text: "Barra"
            color: Settings.fg
            font.family: Settings.fontFamily
            font.pixelSize: 15
            font.weight: Font.Bold
        }

        Text {
            text: "Elige qué barra usar y pulsa Aplicar para activarla al instante."
            color: Settings.subtext0
            font.family: Settings.fontFamily
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: root.types
            width: parent.width

            delegate: Item {
                required property var modelData
                readonly property bool selected: Settings.barType === modelData.id

                width: parent.width
                height: 112

                Rectangle {
                    id: card
                    anchors.fill: parent
                    radius: 12
                    color: selected ? Settings.selectionBg : Settings.surface
                    border {
                        width: selected ? 1 : 0
                        color: Settings.accent
                    }
                    Behavior on color { ColorAnimation { duration: Settings.animationFast } }
                }

                SymbolicIcon {
                    path: Icons.check
                    visible: selected
                    anchors.top: card.top
                    anchors.right: card.right
                    anchors.margins: 10
                    implicitSize: 16
                    color: Settings.accent
                }

                Column {
                    anchors.fill: card
                    anchors.margins: 10
                    spacing: 6

                    // ── Preview decorativo de la barra ───────────────
                    Item {
                        width: parent.width
                        height: 36

                        Rectangle {
                            id: previewBar
                            anchors.fill: parent
                            radius: 8
                            color: Settings.bg
                            border { width: 1; color: Settings.surface }
                            opacity: modelData.id === "none" ? 0.35 : 1

                            // Workspaces (izquierda)
                            Row {
                                visible: modelData.id !== "none"
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                Repeater {
                                    model: Settings.workspaceCount
                                    Rectangle {
                                        required property int index
                                        width: index === 0 ? 20 : 5
                                        height: 5
                                        radius: 2.5
                                        color: index === 0 ? Settings.accent : Settings.surface
                                    }
                                }
                            }

                            // Media (izquierda, junto a workspaces)
                            Rectangle {
                                visible: modelData.id !== "none"
                                anchors.left: parent.left
                                anchors.leftMargin: 76
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14
                                height: 14
                                radius: 4
                                color: Settings.surface
                            }

                            // Reloj (centro)
                            Text {
                                visible: modelData.id !== "none"
                                anchors.centerIn: parent
                                text: "12:00"
                                color: Settings.fg
                                font.family: Settings.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Bold
                            }

                            // Indicadores (derecha)
                            Row {
                                visible: modelData.id !== "none"
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Rectangle { width: 12; height: 12; radius: 3; color: Settings.surface }
                                Rectangle { width: 12; height: 12; radius: 3; color: Settings.surface }
                            }

                            // Marca del modo "Sin barra"
                            Text {
                                visible: modelData.id === "none"
                                anchors.centerIn: parent
                                text: "—"
                                color: Settings.subtext0
                                font.family: Settings.fontFamily
                                font.pixelSize: 14
                            }
                        }
                    }

                    Text {
                        text: modelData.name
                        color: Settings.fg
                        font.family: Settings.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }

                    Text {
                        text: modelData.desc
                        color: Settings.subtext0
                        font.family: Settings.fontFamily
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectBar(modelData.id)
                }
            }
        }

        Text {
            visible: root.hasChanges
            text: "Tienes cambios sin aplicar."
            color: Settings.yellow
            font.family: Settings.fontFamily
            font.pixelSize: 11
        }

        Rectangle {
            id: applyBtn
            width: parent.width
            height: 36
            radius: 9
            color: root.hasChanges ? Settings.accent : Settings.surface
            opacity: root.hasChanges ? 1 : 0.6
            Behavior on color { ColorAnimation { duration: Settings.animationFast } }

            Text {
                anchors.centerIn: parent
                text: "Aplicar"
                color: root.hasChanges ? Settings.bg : Settings.subtext0
                font.family: Settings.fontFamily
                font.pixelSize: 13
                font.weight: Font.Bold
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: root.hasChanges
                onClicked: root.apply()
            }
        }
    }
}
