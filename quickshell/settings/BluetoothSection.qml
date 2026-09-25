// ─── Sección de Bluetooth ──────────────────────────────────────────────
// Activa/desactiva el adaptador, escanea, vincula/conecta dispositivos y
// muestra su estado (batería, conectado). El volumen por dispositivo NO se
// ajusta aquí: se auto-recuerda en shell.qml — cualquier cambio manual del
// volumen (teclas, wpctl, OSD) queda grabado como "último volumen" y se
// restaura al conectar. La misma lógica del popup de la barra
// (BluetoothPanel): `adapter.discovering` para escanear (NO bluetoothctl),
// bluetoothctl para vincular, rfkill para desbloquear. El estado persistido
// (bluetoothEnabled + btVolumeMap) lo gestiona shell.qml vía
// Settings.applyBluetooth / Settings.setBtVolumeMap; la restauración y el
// auto-record del volumen viven también en shell.qml (funciona con cualquier
// forma de conexión, no solo desde esta sección).

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "../config"

Item {
    id: root

    anchors.fill: parent

    property string _btPairAddr: ""
    property bool _btScanning: false
    property int _btScanCount: 0

    // ── Escaneo ────────────────────────────────────────────────────
    // Se controla con la propiedad `discovering` del adaptador (la misma
    // sesión de Quickshell es la dueña del descubrimiento, así arranca y
    // se detiene de forma fiable). NO usar `bluetoothctl scan on/off`:
    // con stdin cerrado el cliente sale al instante dejando la discovery
    // huérfana, y `scan off` de un cliente nuevo falla (org.bluez.Error.
    // Failed) — solo se detiene apagando/encendiendo el adaptador.
    function _startScan() {
        if (!Bluetooth.defaultAdapter) return;
        root._btScanCount = 0;
        Bluetooth.defaultAdapter.discovering = true;
        root._btScanning = true;
    }

    function _stopScan() {
        if (Bluetooth.defaultAdapter)
            Bluetooth.defaultAdapter.discovering = false;
        root._btScanning = false;
    }

    Connections {
        target: Bluetooth.defaultAdapter
        function onDiscoveringChanged() {
            if (Bluetooth.defaultAdapter && !Bluetooth.defaultAdapter.discovering)
                root._btScanning = false;
        }
    }

    Connections {
        target: Bluetooth
        function onDefaultAdapterChanged() {
            if (Bluetooth.defaultAdapter)
                root._btScanning = Bluetooth.defaultAdapter.discovering;
        }
    }

    Process {
        id: btPairProc
        command: root._btPairAddr ? ["bluetoothctl", "connect", root._btPairAddr] : []
        onRunningChanged: if (!running && root._btPairAddr) root._btPairAddr = ""
    }

    Timer {
        id: btScanTimer
        interval: 1000
        repeat: true
        running: root._btScanning
        onTriggered: {
            root._btScanCount++;
            if (root._btScanCount >= 18) {
                root._stopScan();
            }
        }
    }

    Process {
        id: unblockProcess
        command: ["rfkill", "unblock", "bluetooth"]
        onRunningChanged: if (!running && Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = true
    }

    function _toggleAdapter() {
        if (!Bluetooth.defaultAdapter) return;
        if (Bluetooth.defaultAdapter.state === BluetoothAdapterState.Blocked) {
            unblockProcess.running = true;
        } else {
            Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
            if (Settings.applyBluetooth)
                Settings.applyBluetooth(Bluetooth.defaultAdapter.enabled);
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 10

        Text {
            text: "Bluetooth"
            color: Settings.fg
            font.family: Settings.fontFamily
            font.pixelSize: 15
            font.weight: Font.Bold
        }

        Text {
            text: "Activa el adaptador, escanea y vincula tus dispositivos. El volumen de cada uno se recuerda por separado."
            color: Settings.subtext0
            font.family: Settings.fontFamily
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            width: parent.width
        }

        // ── Estado del adaptador + interruptor ────────────────
        Row {
            width: parent.width
            spacing: 8

            Rectangle {
                width: 40
                height: 22
                radius: 11
                color: !Bluetooth.defaultAdapter ? Settings.surface
                     : Bluetooth.defaultAdapter.state === BluetoothAdapterState.Blocked ? Settings.yellow
                     : Bluetooth.defaultAdapter.enabled ? Settings.green
                     : Settings.surface
                Behavior on color { ColorAnimation { duration: 80 } }

                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    color: Settings.bg
                    anchors.verticalCenter: parent.verticalCenter
                    x: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.state !== BluetoothAdapterState.Blocked && Bluetooth.defaultAdapter.enabled ? parent.width - width - 3 : 3
                    Behavior on x { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root._toggleAdapter()
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    text: {
                        if (!Bluetooth.defaultAdapter) return "Sin adaptador";
                        if (Bluetooth.defaultAdapter.state === BluetoothAdapterState.Blocked) return "Bloqueado por rfkill";
                        return Bluetooth.defaultAdapter.name;
                    }
                    color: !Bluetooth.defaultAdapter ? Settings.subtext0
                         : Bluetooth.defaultAdapter.state === BluetoothAdapterState.Blocked ? Settings.yellow
                         : Bluetooth.defaultAdapter.enabled ? Settings.fg
                         : Settings.subtext0
                    font.family: Settings.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }

                Text {
                    text: !Bluetooth.defaultAdapter ? "" : Bluetooth.defaultAdapter.state === BluetoothAdapterState.Blocked ? "Haz clic en el interruptor para desbloquear" : Bluetooth.defaultAdapter.enabled ? "Encendido" : "Apagado"
                    color: Settings.subtext0
                    font.family: Settings.fontFamily
                    font.pixelSize: 10
                    visible: text !== ""
                }
            }
        }

        // ── Escaneo ──────────────────────────────────────────
        Row {
            visible: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.state !== BluetoothAdapterState.Blocked && Bluetooth.defaultAdapter.enabled
            width: parent.width
            spacing: 8

            Rectangle {
                width: 96
                height: 26
                radius: 6
                color: root._btScanning ? Settings.red : Settings.accent
                Behavior on color { ColorAnimation { duration: 80 } }

                Text {
                    anchors.centerIn: parent
                    text: root._btScanning ? "Detener" : "Escanear"
                    color: Settings.bg
                    font.family: Settings.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root._btScanning) {
                            root._stopScan();
                        } else {
                            root._startScan();
                        }
                    }
                }
            }

            Text {
                visible: root._btScanning
                anchors.verticalCenter: parent.verticalCenter
                text: "Escaneando... " + root._btScanCount + "s"
                color: Settings.subtext0
                font.family: Settings.fontFamily
                font.pixelSize: 10
            }
        }

        Text {
            visible: !Bluetooth.defaultAdapter
            text: "No se detectó adaptador Bluetooth"
            color: Settings.subtext0
            font.family: Settings.fontFamily
            font.pixelSize: 11
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            visible: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.state !== BluetoothAdapterState.Blocked && !Bluetooth.defaultAdapter.enabled
            text: "Bluetooth apagado. Enciéndelo para ver y vincular dispositivos."
            color: Settings.subtext0
            font.family: Settings.fontFamily
            font.pixelSize: 11
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // ── Lista de dispositivos ────────────────────────────
        ListView {
            id: btDeviceList
            width: parent.width
            height: Math.min(220, parent.height - 200)
            spacing: 4
            clip: true
            visible: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.state !== BluetoothAdapterState.Blocked && Bluetooth.defaultAdapter.enabled
            model: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices : null

            Text {
                anchors.centerIn: parent
                visible: btDeviceList.count === 0
                text: "Sin dispositivos"
                color: Settings.subtext0
                font.family: Settings.fontFamily
                font.pixelSize: 11
            }

            delegate: Column {
                id: devColumn
                required property var modelData
                width: btDeviceList.width
                spacing: 2

                readonly property bool hovered: devHover.containsMouse

                Rectangle {
                    width: parent.width
                    implicitHeight: 34
                    radius: 6
                    color: devColumn.hovered ? Settings.surface : "transparent"
                    Behavior on color { ColorAnimation { duration: 80 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 6

                        SymbolicIcon {
                            path: modelData.connected ? Icons.bluetooth : Icons.bluetoothOff
                            color: modelData.connected ? Settings.accent : Settings.subtext0
                            implicitSize: 14
                            Layout.preferredWidth: 20
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: modelData.name || modelData.address
                                color: Settings.fg
                                font.family: Settings.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                            }

                            Text {
                                text: {
                                    const parts = [];
                                    if (modelData.connected) parts.push("Conectado");
                                    else if (modelData.paired) parts.push("Vinculado");
                                    if (modelData.batteryAvailable) parts.push(Math.round(modelData.battery * 100) + "%");
                                    return parts.length > 0 ? parts.join(" · ") : "";
                                }
                                color: Settings.accent
                                font.family: Settings.fontFamily
                                font.pixelSize: 9
                                visible: text !== ""
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 56
                            Layout.preferredHeight: 20
                            radius: 4
                            color: modelData.connected ? Settings.red : modelData.paired ? Settings.green : Settings.yellow

                            Text {
                                anchors.centerIn: parent
                                text: modelData.connected ? "Descon." : modelData.paired ? "Conectar" : root._btPairAddr === modelData.address ? "..." : "Vincular"
                                color: Settings.bg
                                font.family: Settings.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.connected)
                                        modelData.disconnect();
                                    else if (modelData.paired) {
                                        modelData.connect();
                                    } else {
                                        root._btPairAddr = modelData.address;
                                        btPairProc.running = true;
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            radius: 4
                            color: Settings.selectionBg
                            visible: modelData.paired

                            SymbolicIcon {
                                anchors.centerIn: parent
                                path: Icons.trash
                                color: Settings.bg
                                implicitSize: 9
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: modelData.forget()
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
    }
}
