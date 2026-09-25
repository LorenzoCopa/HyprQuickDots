// ─── Sección de suspensión y bloqueo ──────────────────────────────────
// Configura tras cuánta inactividad se bloquea la sesión y se suspende el
// sistema. "Nunca" (0) desactiva esa acción: útil al descargar o mirar
// algo largo sin que se apague. Los valores se eligen con dos menús
// desplegables y se activan con el botón "Aplicar" (patrón de BarSection):
// Settings.applyIdle persiste en idlestate.json y se aplica al IdleManager.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../config"

Item {
    id: root

    anchors.fill: parent

    readonly property bool hasChanges:
        Settings.idleLockMin !== Settings.appliedIdleLockMin
        || Settings.idleSuspendMin !== Settings.appliedIdleSuspendMin

    readonly property var options: [
        { value: 0,  label: "Nunca" },
        { value: 1,  label: "1 min" },
        { value: 2,  label: "2 min" },
        { value: 5,  label: "5 min" },
        { value: 10, label: "10 min" },
        { value: 15, label: "15 min" },
        { value: 30, label: "30 min" },
        { value: 60, label: "60 min" },
    ]

    function apply(): void {
        if (Settings.applyIdle)
            Settings.applyIdle();
    }

    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 10

        Text {
            text: "Suspensión y bloqueo"
            color: Settings.fg
            font.family: Settings.fontFamily
            font.pixelSize: 15
            font.weight: Font.Bold
        }

        Text {
            text: "Elige tras cuánto tiempo sin usar el equipo se bloquea y se suspende. \"Nunca\" desactiva la acción."
            color: Settings.subtext0
            font.family: Settings.fontFamily
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            width: parent.width
        }

        // ── Bloqueo de sesión ─────────────────────────────
        Text {
            text: "Bloqueo de sesión"
            color: Settings.subtext0
            font.family: Settings.fontFamily
            font.pixelSize: 11
            font.weight: Font.Bold
        }

        ComboBox {
            id: lockCombo
            model: root.options
            textRole: "label"

            width: 220
            height: 36

            currentIndex: {
                for (var i = 0; i < root.options.length; i++)
                    if (root.options[i].value === Settings.idleLockMin)
                        return i;
                return 0;
            }

            onActivated: (index) => {
                Settings.idleLockMin = root.options[index].value;
            }

            indicator: Text {
                text: Icons.chevronDown
                color: Settings.subtext0
                font.family: Settings.iconFontFamily
                font.pixelSize: 12
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
            }

            contentItem: Text {
                leftPadding: 12
                rightPadding: 28
                verticalAlignment: Text.AlignVCenter
                text: lockCombo.currentText
                color: Settings.fg
                font.family: Settings.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            background: Rectangle {
                radius: 9
                color: Settings.surface
                border {
                    width: 1
                    color: Settings.selectionBg
                }
            }

            delegate: ItemDelegate {
                id: lockDel
                required property var model
                required property int index
                width: ListView.view.width
                height: 32
                highlighted: lockCombo.highlightedIndex === index

                contentItem: Text {
                    text: lockDel.model[lockCombo.textRole]
                    color: lockDel.highlighted || lockDel.hovered ? Settings.accent : Settings.fg
                    font.family: Settings.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 12
                    rightPadding: 12
                }

                background: Rectangle {
                    radius: 6
                    color: lockDel.highlighted || lockDel.hovered ? Settings.selectionBg : "transparent"
                }
            }

            popup: Popup {
                y: lockCombo.height + 4
                width: lockCombo.width
                padding: 4

                background: Rectangle {
                    radius: 10
                    color: Settings.surface
                    border {
                        width: 1
                        color: Settings.selectionBg
                    }
                }

                contentItem: ListView {
                    clip: true
                    implicitHeight: contentHeight
                    model: lockCombo.delegateModel
                    currentIndex: lockCombo.highlightedIndex
                    highlightMoveDuration: 0
                }
            }
        }

        // ── Suspensión ────────────────────────────────────
        Text {
            text: "Suspensión"
            color: Settings.subtext0
            font.family: Settings.fontFamily
            font.pixelSize: 11
            font.weight: Font.Bold
        }

        ComboBox {
            id: suspendCombo
            model: root.options
            textRole: "label"

            width: 220
            height: 36

            currentIndex: {
                for (var i = 0; i < root.options.length; i++)
                    if (root.options[i].value === Settings.idleSuspendMin)
                        return i;
                return 0;
            }

            onActivated: (index) => {
                Settings.idleSuspendMin = root.options[index].value;
            }

            indicator: Text {
                text: Icons.chevronDown
                color: Settings.subtext0
                font.family: Settings.iconFontFamily
                font.pixelSize: 12
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
            }

            contentItem: Text {
                leftPadding: 12
                rightPadding: 28
                verticalAlignment: Text.AlignVCenter
                text: suspendCombo.currentText
                color: Settings.fg
                font.family: Settings.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            background: Rectangle {
                radius: 9
                color: Settings.surface
                border {
                    width: 1
                    color: Settings.selectionBg
                }
            }

            delegate: ItemDelegate {
                id: suspendDel
                required property var model
                required property int index
                width: ListView.view.width
                height: 32
                highlighted: suspendCombo.highlightedIndex === index

                contentItem: Text {
                    text: suspendDel.model[suspendCombo.textRole]
                    color: suspendDel.highlighted || suspendDel.hovered ? Settings.accent : Settings.fg
                    font.family: Settings.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 12
                    rightPadding: 12
                }

                background: Rectangle {
                    radius: 6
                    color: suspendDel.highlighted || suspendDel.hovered ? Settings.selectionBg : "transparent"
                }
            }

            popup: Popup {
                y: suspendCombo.height + 4
                width: suspendCombo.width
                padding: 4

                background: Rectangle {
                    radius: 10
                    color: Settings.surface
                    border {
                        width: 1
                        color: Settings.selectionBg
                    }
                }

                contentItem: ListView {
                    clip: true
                    implicitHeight: contentHeight
                    model: suspendCombo.delegateModel
                    currentIndex: suspendCombo.highlightedIndex
                    highlightMoveDuration: 0
                }
            }
        }

        Text {
            text: "Nota: si la suspensión es menor que el bloqueo, el equipo se suspenderá sin pasar por la pantalla de bloqueo."
            color: Settings.subtext0
            font.family: Settings.fontFamily
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            width: parent.width
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
