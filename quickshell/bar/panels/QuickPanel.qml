import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell.Io
import "../../config"

Item {
    id: root

    property bool showMedia: false
    property bool showBluetooth: false
    property bool showNetwork: false
    property bool showNightLight: false
    property bool nightLightEnabled: false
    property var screenshotManager: null
    property var onToggleWlogout: null

    signal toggleMediaRequested
    signal toggleBluetoothRequested
    signal toggleNetworkRequested
    signal toggleNightLightRequested
    signal screenshotRequested
    signal openSettingsRequested

    GridLayout {
        anchors.centerIn: parent
        columns: 2
        rowSpacing: 12
        columnSpacing: 14

        Repeater {
            model: [
                {
                    icon: Icons.music,
                    shortcut: "R",
                    activeProp: "root.showMedia",
                    activeColor: "Settings.selectionBg",
                    onClicked: function () {
                        root.toggleMediaRequested();
                    }
                },
                {
                    icon: Icons.bluetooth,
                    shortcut: "B",
                    activeProp: "root.showBluetooth",
                    activeColor: "Settings.selectionBg",
                    onClicked: function () {
                        root.toggleBluetoothRequested();
                    }
                },
                {
                    icon: Icons.wifi,
                    shortcut: "N",
                    activeProp: "root.showNetwork",
                    activeColor: "Settings.selectionBg",
                    onClicked: function () {
                        root.toggleNetworkRequested();
                    }
                },
                {
                    icon: Icons.nightlight,
                    shortcut: "L",
                    activeProp: "root.showNightLight",
                    activeColor: "Settings.selectionBg",
                    onClicked: function () {
                        root.toggleNightLightRequested();
                    }
                },
                {
                    icon: Icons.camera,
                    shortcut: "S",
                    activeProp: "",
                    activeColor: "",
                    onClicked: function () {
                        root.screenshotRequested();
                    }
                },
                {
                    icon: Icons.power,
                    shortcut: "X",
                    activeProp: "",
                    activeColor: "",
                    onClicked: function () {
                        if (root.onToggleWlogout)
                            root.onToggleWlogout();
                    }
                },
                {
                    icon: Icons.settings,
                    shortcut: "G",
                    activeProp: "",
                    activeColor: "",
                    onClicked: function () {
                        root.openSettingsRequested();
                    }
                },
            ]

            delegate: Item {
                required property var modelData
                Layout.preferredWidth: 40
                Layout.preferredHeight: 52

                readonly property bool isActive: {
                    if (modelData.activeProp === "")
                        return false;
                    try {
                        return eval(modelData.activeProp);
                    } catch (e) {
                        return false;
                    }
                }

                Rectangle {
                    id: iconBg
                    width: 40
                    height: 40
                    radius: 10
                    color: itemMouse.containsMouse ? Settings.surface : "transparent"
                    visible: modelData.activeProp === "" || !isActive

                    SymbolicIcon {
                        anchors.centerIn: parent
                        path: modelData.icon
                        color: itemMouse.containsMouse ? Settings.fg : Settings.subtext0
                        implicitSize: 28
                    }
                }

                Rectangle {
                    id: iconBgActive
                    width: 40
                    height: 40
                    radius: 10
                    color: Settings.selectionBg
                    visible: modelData.activeProp !== "" && isActive

                    SymbolicIcon {
                        anchors.centerIn: parent
                        path: modelData.icon
                        color: Settings.fg
                        implicitSize: 28
                    }
                }

                Text {
                    id: tooltip
                    anchors {
                        top: iconBg.bottom
                        topMargin: 2
                        horizontalCenter: parent.horizontalCenter
                    }
                    text: modelData.shortcut !== "" ? "[" + modelData.shortcut + "]" : ""
                    color: Settings.subtext0
                    font.family: Settings.fontFamily
                    font.pixelSize: 8
                    font.weight: Font.Bold
                    visible: itemMouse.containsMouse && text !== ""
                }

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: modelData.onClicked()
                }
            }
        }
    }
}
