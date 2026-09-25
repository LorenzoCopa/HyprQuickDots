// ─── Sección de modo de energía ────────────────────────────────────────
// Elige el perfil de power-profiles-daemon (performance / balanced /
// power-saver). Se aplica al instante, igual que la luz nocturna: al tocar
// una opción se ejecuta `powerprofilesctl set`. El estado lo gestiona
// shell.qml (Settings.setPowerProfile + sync por poll).

pragma ComponentBehavior: Bound

import QtQuick
import "../config"

Item {
    id: root

    anchors.fill: parent

    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 10

        Text {
            text: "Modo de energía"
            color: Settings.fg
            font.family: Settings.fontFamily
            font.pixelSize: 15
            font.weight: Font.Bold
        }

        Text {
            text: "Controla el rendimiento frente a la autonomía. Todo se aplica al instante: rendimiento prioriza la velocidad, equilibrado es el punto medio y ahorro reduce el consumo para alargar la batería."
            color: Settings.subtext0
            font.family: Settings.fontFamily
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            width: parent.width
        }

        Repeater {
            model: Settings.powerProfiles

            delegate: Rectangle {
                id: opt
                required property var modelData
                readonly property bool active: Settings.powerProfile === modelData.id

                width: parent.width
                height: 48
                radius: 10
                color: opt.active ? Settings.accent : Settings.surface
                border {
                    width: 1
                    color: opt.active ? "transparent" : Settings.selectionBg
                }
                Behavior on color { ColorAnimation { duration: Settings.animationFast } }

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    SymbolicIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        path: modelData.icon
                        color: opt.active ? Settings.bg : Settings.fg
                        implicitSize: 20
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: opt.active ? Settings.bg : Settings.fg
                        font.family: Settings.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (Settings.setPowerProfile)
                            Settings.setPowerProfile(modelData.id);
                    }
                }
            }
        }
    }
}
