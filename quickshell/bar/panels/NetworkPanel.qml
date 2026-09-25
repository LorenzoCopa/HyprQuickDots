import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import "../../config"

Item {
    id: root

    property bool panelVisible: false

    readonly property bool _hasWifi: {
        var vals = Networking.devices.values;
        if (!vals) return false;
        for (var i = 0; i < vals.length; i++) {
            if (vals[i].type === DeviceType.Wifi) return true;
        }
        return false;
    }
    readonly property var _wifiDevice: {
        var vals = Networking.devices.values;
        if (!vals) return null;
        for (var i = 0; i < vals.length; i++) {
            if (vals[i].type === DeviceType.Wifi) return vals[i];
        }
        return null;
    }
    readonly property var _wiredDevice: {
        var vals = Networking.devices.values;
        if (!vals) return null;
        for (var i = 0; i < vals.length; i++) {
            if (vals[i].type === DeviceType.Wired) return vals[i];
        }
        return null;
    }

    property bool _scanning: false
    property int _scanCount: 0

    function _startScan() {
        if (!_wifiDevice) return;
        _scanning = true;
        _scanCount = 0;
        _wifiDevice.scannerEnabled = true;
    }

    function _stopScan() {
        if (!_wifiDevice) return;
        _scanning = false;
        _wifiDevice.scannerEnabled = false;
    }

    Connections {
        target: _wifiDevice
        function onScannerEnabledChanged() {
            if (_wifiDevice && !_wifiDevice.scannerEnabled && _scanning) {
                _scanning = false;
            }
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 8
        contentHeight: mainCol.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: mainCol
            width: parent.width
            spacing: 6

            RowLayout {
                visible: root._hasWifi
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                spacing: 6

                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 22
                    radius: 5
                    color: root._scanning ? Settings.red : Settings.accent

                    Text {
                        anchors.centerIn: parent
                        text: root._scanning ? "Detener" : "Escanear"
                        color: Settings.bg
                        font.family: Settings.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root._scanning) {
                                root._stopScan();
                            } else {
                                root._startScan();
                            }
                        }
                    }
                }

                Text {
                    visible: root._scanning
                    text: "Escaneando... " + root._scanCount + "s"
                    color: Settings.subtext0
                    font.family: Settings.fontFamily
                    font.pixelSize: 9
                }

                Item { Layout.fillWidth: true }
            }

            ColumnLayout {
                visible: root._hasWifi && root._wifiDevice && root._wifiDevice.networks && root._wifiDevice.networks.values && root._wifiDevice.networks.values.length > 0
                Layout.fillWidth: true
                spacing: 2

                Repeater {
                    model: root._wifiDevice ? root._wifiDevice.networks : null

                    delegate: Rectangle {
                        id: wifiDelegate
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: 6
                        color: wifiHover.containsMouse ? Settings.surface : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 6

                            SymbolicIcon {
                                path: Icons.wifi
                                color: Settings.accent
                                implicitSize: 12
                                Layout.preferredWidth: 20
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: wifiDelegate.modelData.name || "Red oculta"
                                    color: Settings.fg
                                    font.family: Settings.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                }

                                RowLayout {
                                    spacing: 4
                                    visible: wifiDelegate.modelData.security !== WifiSecurityType.Open && wifiDelegate.modelData.security !== WifiSecurityType.Unknown

                                    Rectangle {
                                        Layout.preferredHeight: 12
                                        Layout.preferredWidth: secRow.implicitWidth + 6
                                        radius: 2
                                        color: Settings.surface

                                        RowLayout {
                                            id: secRow
                                            anchors.centerIn: parent
                                            spacing: 2

                                            SymbolicIcon {
                                                path: Icons.lock
                                                color: Settings.subtext0
                                                implicitSize: 8
                                            }

                                            Text {
                                                text: {
                                                    var sec = wifiDelegate.modelData.security;
                                                    if (sec === WifiSecurityType.WpaPsk || sec === WifiSecurityType.Wpa2Psk || sec === WifiSecurityType.Sae) return "WPA";
                                                    if (sec === WifiSecurityType.WpaEap || sec === WifiSecurityType.Wpa2Eap) return "WPA-EAP";
                                                    if (sec === WifiSecurityType.StaticWep || sec === WifiSecurityType.DynamicWep) return "WEP";
                                                    if (sec === WifiSecurityType.Owe) return "OWE";
                                                    return "";
                                                }
                                                color: Settings.subtext0
                                                font.family: Settings.fontFamily
                                                font.pixelSize: 7
                                            }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                spacing: 1
                                Layout.preferredWidth: 30

                                Repeater {
                                    model: 4
                                    Rectangle {
                                        Layout.preferredWidth: 4
                                        Layout.preferredHeight: 4 + index * 3
                                        Layout.alignment: Qt.AlignBottom
                                        radius: 1
                                        color: (wifiDelegate.modelData.signal / 0.25) > index ? Settings.accent : Settings.surface
                                    }
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 54
                                Layout.preferredHeight: 20
                                radius: 4
                                color: wifiDelegate.modelData.connected ? Settings.green
                                     : wifiDelegate.modelData.signal > 0 ? Settings.accent
                                     : Settings.surface

                                Text {
                                    anchors.centerIn: parent
                                    text: wifiDelegate.modelData.connected ? "Activo" : "Conectar"
                                    color: Settings.bg
                                    font.family: Settings.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (wifiDelegate.modelData.connected) {
                                            wifiDelegate.modelData.disconnect();
                                        } else {
                                            wifiDelegate.modelData.connect();
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: wifiHover
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }
                    }
                }
            }

            ColumnLayout {
                visible: Networking.devices.values && Networking.devices.values.length > 0
                Layout.fillWidth: true
                spacing: 2

                Repeater {
                    model: Networking.devices

                    delegate: Rectangle {
                        id: devDelegate
                        required property var modelData
                        required property int index
                        visible: modelData.name !== "lo"

                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? 36 : 0
                        radius: 6
                        color: devHover.containsMouse ? Settings.surface : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 6

                            SymbolicIcon {
                                path: devDelegate.modelData.connected
                                    ? (devDelegate.modelData.type === DeviceType.Wifi ? Icons.wifi : Icons.ethernet)
                                    : Icons.networkOffline
                                color: Settings.accent
                                implicitSize: 14
                                Layout.preferredWidth: 20
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: {
                                        var name = devDelegate.modelData.name || "";
                                        if (devDelegate.modelData.type === DeviceType.Wifi) return "WiFi - " + name;
                                        if (devDelegate.modelData.type === DeviceType.Wired) return "Ethernet - " + name;
                                        return name;
                                    }
                                    color: Settings.fg
                                    font.family: Settings.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: {
                                        var state = devDelegate.modelData.state;
                                        if (state === ConnectionState.Connected) return "Conectado";
                                        if (state === ConnectionState.Connecting) return "Conectando...";
                                        if (state === ConnectionState.Disconnecting) return "Desconectando...";
                                        return "Desconectado";
                                    }
                                    color: Settings.accent
                                    font.family: Settings.fontFamily
                                    font.pixelSize: 9
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 54
                                Layout.preferredHeight: 20
                                radius: 4
                                color: devDelegate.modelData.connected ? Settings.red : Settings.green

                                Text {
                                    anchors.centerIn: parent
                                    text: devDelegate.modelData.connected ? "Descon." : "Conectar"
                                    color: Settings.bg
                                    font.family: Settings.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var dev = devDelegate.modelData;
                                        if (dev.type === DeviceType.Wired && dev.network) {
                                            if (dev.connected) {
                                                dev.network.disconnect();
                                            } else {
                                                dev.network.connect();
                                            }
                                        } else {
                                            var nets = dev.networks;
                                            if (nets && nets.values) {
                                                for (var i = 0; i < nets.values.length; i++) {
                                                    if (nets.values[i].connected) {
                                                        nets.values[i].disconnect();
                                                        return;
                                                    }
                                                }
                                                if (nets.values.length > 0) {
                                                    nets.values[0].connect();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: devHover
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }
                    }
                }
            }

            Text {
                visible: !Networking.devices.values || Networking.devices.values.length === 0
                text: "Sin dispositivos"
                color: Settings.subtext0
                font.family: Settings.fontFamily
                font.pixelSize: 11
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 10
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root._scanning
        onTriggered: root._scanCount++
    }
}
