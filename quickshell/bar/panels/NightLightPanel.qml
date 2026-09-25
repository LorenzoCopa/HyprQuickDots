import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../config"

Item {
    id: root

    property bool nightLightEnabled: false
    property int nightLightTemp: 3500
    property var enabledChangedCallback: null
    property var tempChangedCallback: null

    // El arranque/parada/cambio de temperatura de hyprsunset lo gestiona
    // shell.qml (setNightLight); aquí solo se notifican los cambios.

    function toggle() {
        root.nightLightEnabled = !root.nightLightEnabled;
        if (root.enabledChangedCallback)
            root.enabledChangedCallback(root.nightLightEnabled);
    }

    function setTemp(temp) {
        root.nightLightTemp = Math.max(1000, Math.min(6500, temp));
        if (root.tempChangedCallback)
            root.tempChangedCallback(root.nightLightTemp);
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        Text {
            text: "Luz Nocturna"
            color: Settings.subtext0
            font.family: Settings.fontFamily
            font.pixelSize: 11
            font.weight: Font.Bold
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            spacing: 6

            Text {
                text: root.nightLightEnabled ? "Encendido" : "Apagado"
                color: root.nightLightEnabled ? Settings.green : Settings.subtext0
                font.family: Settings.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 18
                radius: 9
                color: root.nightLightEnabled ? Settings.green : Settings.surface
                Behavior on color {
                    ColorAnimation {
                        duration: 80
                    }
                }

                Rectangle {
                    width: 14
                    height: 14
                    radius: 7
                    color: Settings.bg
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.nightLightEnabled ? parent.width - width - 2 : 2
                    Behavior on x {
                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.InOutQuad
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggle()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Settings.surface
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "1000K"
                color: Settings.subtext0
                font.family: Settings.fontFamily
                font.pixelSize: 9
            }

            Slider {
                id: tempSlider
                Layout.fillWidth: true
                from: 1000
                to: 6500
                stepSize: 100
                value: root.nightLightTemp
                onMoved: root.setTemp(value)

                background: Rectangle {
                    x: tempSlider.leftPadding
                    y: tempSlider.topPadding + tempSlider.availableHeight / 2 - height / 2
                    implicitWidth: 200
                    implicitHeight: 4
                    width: tempSlider.availableWidth
                    height: implicitHeight
                    radius: 2
                    color: Settings.surface

                    Rectangle {
                        width: tempSlider.visualPosition * parent.width
                        height: parent.height
                        radius: 2
                        color: Settings.yellow
                    }
                }

                handle: Rectangle {
                    x: tempSlider.leftPadding + tempSlider.visualPosition * (tempSlider.availableWidth - width)
                    y: tempSlider.topPadding + tempSlider.availableHeight / 2 - height / 2
                    implicitWidth: 16
                    implicitHeight: 16
                    radius: 8
                    color: root.nightLightEnabled ? Settings.yellow : Settings.selectionBg
                    border {
                        width: 2
                        color: Settings.bg
                    }
                }
            }

            Text {
                text: "6500K"
                color: Settings.subtext0
                font.family: Settings.fontFamily
                font.pixelSize: 9
            }
        }

        Text {
            text: root.nightLightTemp + "K"
            color: Settings.fg
            font.family: Settings.fontFamily
            font.pixelSize: 13
            font.weight: Font.Bold
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            Layout.preferredWidth: 80
            Layout.preferredHeight: 22
            radius: 4
            color: Settings.red
            Layout.alignment: Qt.AlignHCenter

            Text {
                anchors.centerIn: parent
                text: "Desactivar"
                color: Settings.bg
                font.family: Settings.fontFamily
                font.pixelSize: 9
                font.weight: Font.Bold
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.nightLightEnabled)
                        root.toggle();
                    root.nightLightTemp = 6500;
                    if (root.tempChangedCallback)
                        root.tempChangedCallback(6500);
                }
            }
        }
    }
}
