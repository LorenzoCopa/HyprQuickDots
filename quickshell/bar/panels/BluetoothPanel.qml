import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "../../config"

Item {
  id: root

  property var onBluetoothToggled: null

  property string _btPairAddr: ""
  property bool _btScanning: false
  property int _btScanCount: 0

  // ── Escaneo ────────────────────────────────────────────────────
  // Controlado con `adapter.discovering` (la sesión de Quickshell es
  // dueña del descubrimiento y lo detiene de forma fiable). NO usar
  // `bluetoothctl scan on/off`: con stdin cerrado el cliente sale al
  // instante y la discovery queda huérfana (no se detiene con scan off
  // de otro cliente, solo apagando el adaptador).
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

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 8
    spacing: 6

    Text {
      text: "Bluetooth"
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
        elide: Text.ElideRight
        Layout.fillWidth: true
      }

      Text {
        text: !Bluetooth.defaultAdapter ? "" : Bluetooth.defaultAdapter.state === BluetoothAdapterState.Blocked ? "Bloqueado" : Bluetooth.defaultAdapter.enabled ? "Encendido" : "Apagado"
        color: !Bluetooth.defaultAdapter ? Settings.subtext0
             : Bluetooth.defaultAdapter.state === BluetoothAdapterState.Blocked ? Settings.yellow
             : Bluetooth.defaultAdapter.enabled ? Settings.green
             : Settings.subtext0
        font.family: Settings.fontFamily
        font.pixelSize: 10
      }

      Rectangle {
        Layout.preferredWidth: 36
        Layout.preferredHeight: 18
        radius: 9
        color: !Bluetooth.defaultAdapter ? Settings.surface
             : Bluetooth.defaultAdapter.state === BluetoothAdapterState.Blocked ? Settings.yellow
             : Bluetooth.defaultAdapter.enabled ? Settings.green
             : Settings.surface
        Behavior on color { ColorAnimation { duration: 80 } }

        Rectangle {
          width: 14; height: 14; radius: 7
          color: Settings.bg
          anchors.verticalCenter: parent.verticalCenter
          x: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.state !== BluetoothAdapterState.Blocked && Bluetooth.defaultAdapter.enabled ? parent.width - width - 2 : 2
          Behavior on x { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (!Bluetooth.defaultAdapter) return;
            if (Bluetooth.defaultAdapter.state === BluetoothAdapterState.Blocked)
              unblockProcess.running = true;
            else {
              Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
              if (root.onBluetoothToggled)
                root.onBluetoothToggled(Bluetooth.defaultAdapter.enabled);
            }
          }
        }
      }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 1
      color: Settings.surface
    }

    Text {
      visible: !Bluetooth.defaultAdapter
      text: "No se detectó adaptador Bluetooth"
      color: Settings.subtext0
      font.family: Settings.fontFamily
      font.pixelSize: 11
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: 10
    }

    RowLayout {
      visible: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.state !== BluetoothAdapterState.Blocked && Bluetooth.defaultAdapter.enabled
      Layout.fillWidth: true
      Layout.topMargin: 4
      spacing: 6

      Rectangle {
        Layout.preferredWidth: 80
        Layout.preferredHeight: 24
        radius: 6
        color: root._btScanning ? Settings.red : Settings.accent
        Behavior on color { ColorAnimation { duration: 80 } }

        Text {
          anchors.centerIn: parent
          text: root._btScanning ? "Detener" : "Escanear"
          color: Settings.bg
          font.family: Settings.fontFamily
          font.pixelSize: 10
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
        text: "Escaneando... " + root._btScanCount + "s"
        color: Settings.subtext0
        font.family: Settings.fontFamily
        font.pixelSize: 9
      }

      Item { Layout.fillWidth: true }
    }

    Text {
      visible: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.state === BluetoothAdapterState.Blocked
      text: "Bluetooth bloqueado por rfkill. Haz clic en el interruptor para desbloquear."
      color: Settings.yellow
      font.family: Settings.fontFamily
      font.pixelSize: 10
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: 10
      Layout.maximumWidth: parent.width - 16
      wrapMode: Text.WordWrap
    }

    Text {
      visible: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.state !== BluetoothAdapterState.Blocked && !Bluetooth.defaultAdapter.enabled
      text: "Bluetooth apagado"
      color: Settings.subtext0
      font.family: Settings.fontFamily
      font.pixelSize: 11
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: 10
    }

    ListView {
      id: btDeviceList
      Layout.fillWidth: true
      Layout.fillHeight: true
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

      delegate: Item {
        id: btDevDelegate
        required property var modelData
        width: ListView.view.width
        implicitHeight: 32

        readonly property bool hovered: devHover.containsMouse

        Rectangle {
          anchors.fill: parent
          color: btDevDelegate.hovered ? Settings.surface : "transparent"
          radius: 6
          Behavior on color { ColorAnimation { duration: 80 } }
        }

        RowLayout {
          anchors.fill: parent
          anchors.margins: 4
          spacing: 6

          SymbolicIcon {
            path: Icons.bluetooth
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
              text: btDevDelegate.modelData.name || btDevDelegate.modelData.address
              color: Settings.fg
              font.family: Settings.fontFamily
              font.pixelSize: 11
              font.weight: Font.Bold
              elide: Text.ElideRight
            }

            Text {
              text: {
                const parts = [];
                if (btDevDelegate.modelData.connected) parts.push("Conectado");
                else if (btDevDelegate.modelData.paired) parts.push("Vinculado");
                if (btDevDelegate.modelData.batteryAvailable) parts.push(Math.round(btDevDelegate.modelData.battery * 100) + "%");
                return parts.length > 0 ? parts.join(" · ") : "";
              }
              color: Settings.accent
              font.family: Settings.fontFamily
              font.pixelSize: 9
              visible: text !== ""
            }
          }

          Rectangle {
            Layout.preferredWidth: 54
            Layout.preferredHeight: 20
            radius: 4
            color: btDevDelegate.modelData.connected ? Settings.red : btDevDelegate.modelData.paired ? Settings.green : Settings.yellow

            Text {
              anchors.centerIn: parent
              text: btDevDelegate.modelData.connected ? "Descon." : btDevDelegate.modelData.paired ? "Conectar" : root._btPairAddr === btDevDelegate.modelData.address ? "..." : "Vincular"
              color: Settings.bg
              font.family: Settings.fontFamily
              font.pixelSize: 9
              font.weight: Font.Bold
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (btDevDelegate.modelData.connected)
                  btDevDelegate.modelData.disconnect();
                else if (btDevDelegate.modelData.paired) {
                  btDevDelegate.modelData.connect();
                } else {
                  root._btPairAddr = btDevDelegate.modelData.address;
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
            visible: btDevDelegate.modelData.paired

            SymbolicIcon {
              anchors.centerIn: parent
              path: Icons.notifications
              color: Settings.bg
              implicitSize: 9
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: btDevDelegate.modelData.forget()
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
