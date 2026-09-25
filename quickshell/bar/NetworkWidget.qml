import QtQuick
import Quickshell.Networking
import "../config"

Item {
  id: root
  implicitHeight: Settings.barHeight
  implicitWidth: netIcon.implicitWidth + 12

  signal requestShowNetwork()

  readonly property bool connected: {
    var vals = Networking.devices.values;
    if (!vals) return false;
    for (var i = 0; i < vals.length; i++) {
      if (vals[i].connected) return true;
    }
    return false;
  }

  readonly property bool isWifi: {
    var vals = Networking.devices.values;
    if (!vals) return false;
    for (var i = 0; i < vals.length; i++) {
      if (vals[i].connected && vals[i].type === DeviceType.Wifi) return true;
    }
    return false;
  }

  SymbolicIcon {
    id: netIcon
    anchors.centerIn: parent
    path: {
      if (!root.connected) return Icons.networkOffline;
      if (root.isWifi) return Icons.wifi;
      return Icons.ethernet;
    }
    color: Settings.accent
    implicitSize: 14
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.requestShowNetwork()
  }
}
