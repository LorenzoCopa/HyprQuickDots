pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../config"
import "panels"

/* qmllint disable unresolved-type unqualified */
Rectangle {
  id: rootRect
  color: Settings.bg
  radius: 14
  border { width: 1; color: Settings.surface }

  implicitWidth: 762
  implicitHeight: 284

  focus: true

  required property var panelWindow
  property var onCloseRequested: null
  property var notifModel: null
  property bool showCalendar: false
  property bool showMedia: false
  property bool showBluetooth: false
  property bool showNetwork: false
  property bool showNightLight: false
  property bool dndEnabled: false
  property var onToggleDnd: null
  property var onToggleWlogout: null
  property var onClearAll: null
  // La luz nocturna la gestiona shell.qml (setNightLight); aquí solo se
  // refleja el estado en vivo y se notifican los cambios al shell.
  required property bool nightLightEnabled
  required property int nightLightTemp
  required property var onNightLightChange
  readonly property var screenshotManager: Settings.screenshotManager

  function hideAllPanels(exclude) {
    if (exclude !== "calendar") rootRect.showCalendar = false;
    if (exclude !== "media") rootRect.showMedia = false;
    if (exclude !== "bluetooth") rootRect.showBluetooth = false;
    if (exclude !== "network") rootRect.showNetwork = false;
    if (exclude !== "nightlight") rootRect.showNightLight = false;
  }

  onShowMediaChanged: {
    if (rootRect.showMedia) hideAllPanels("media");
  }

  onShowBluetoothChanged: {
    if (rootRect.showBluetooth) hideAllPanels("bluetooth");
  }

  onShowNetworkChanged: {
    if (rootRect.showNetwork) hideAllPanels("network");
  }

  onShowNightLightChanged: {
    if (rootRect.showNightLight) hideAllPanels("nightlight");
  }

  Item {
    id: leftPanel
    x: 12
    y: 12
    width: 200
    height: parent.height - 24

    SystemClock {
      id: clock
      precision: SystemClock.Minutes
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        rootRect.showCalendar = !rootRect.showCalendar;
        if (rootRect.showCalendar) rootRect.hideAllPanels("calendar");
      }
    }

    ColumnLayout {
      anchors.centerIn: parent
      spacing: 4

      Text {
        Layout.alignment: Qt.AlignHCenter
        text: {
          const d = clock.date;
          const days = ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"];
          return days[d.getDay()];
        }
        color: Settings.subtext0
        font.family: Settings.fontFamily
        font.pixelSize: 13
        font.weight: Font.Normal
      }

      Text {
        Layout.alignment: Qt.AlignHCenter
        text: {
          const hh = ("0" + clock.date.getHours()).slice(-2);
          const mm = ("0" + clock.date.getMinutes()).slice(-2);
          return hh + ":" + mm;
        }
        color: Settings.accent
        font.family: Settings.fontFamily
        font.pixelSize: 28
        font.weight: Font.Bold
      }

      Text {
        Layout.alignment: Qt.AlignHCenter
        text: clock.date.getDate().toString()
        color: Settings.fg
        font.family: Settings.fontFamily
        font.pixelSize: 48
        font.weight: Font.Bold
      }

      Text {
        Layout.alignment: Qt.AlignHCenter
        text: {
          const months = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
                        "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"];
          return months[clock.date.getMonth()];
        }
        color: Settings.subtext0
        font.family: Settings.fontFamily
        font.pixelSize: 14
        font.weight: Font.Normal
      }
    }
  }

  Rectangle {
    id: divider
    x: 224
    y: 12
    width: 1
    height: parent.height - 24
    color: Settings.surface
  }

  Column {
    id: rightPanel
    x: 224 + 1 + 12
    y: 12
    width: 300
    height: parent.height - 24
    clip: true
    spacing: 0

    Item {
      width: parent.width
      height: parent.height

      Rectangle {
        anchors.fill: parent
        color: "transparent"
        opacity: (rootRect.showCalendar || rootRect.showMedia || rootRect.showBluetooth || rootRect.showNetwork || rootRect.showNightLight) ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        enabled: !(rootRect.showCalendar || rootRect.showMedia || rootRect.showBluetooth || rootRect.showNetwork || rootRect.showNightLight)

        NotificationsPanel {
          anchors.fill: parent
          notifModel: rootRect.notifModel
          dndEnabled: rootRect.dndEnabled
          onToggleDnd: rootRect.onToggleDnd
          onClearAll: rootRect.onClearAll
        }
      }

      Rectangle {
        anchors.fill: parent
        color: "transparent"
        opacity: rootRect.showCalendar ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        enabled: rootRect.showCalendar

        Loader {
          anchors.fill: parent
          active: rootRect.showCalendar
          sourceComponent: CalendarPanel { anchors.fill: parent }
        }
      }

      Rectangle {
        anchors.fill: parent
        color: "transparent"
        opacity: rootRect.showBluetooth ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        enabled: rootRect.showBluetooth

        Loader {
          anchors.fill: parent
          active: rootRect.showBluetooth
          sourceComponent: BluetoothPanel {
            anchors.fill: parent
            onBluetoothToggled: function(enabled) {
              if (Settings.applyBluetooth)
                Settings.applyBluetooth(enabled);
            }
          }
        }
      }

      Rectangle {
        anchors.fill: parent
        color: "transparent"
        opacity: rootRect.showNetwork ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        enabled: rootRect.showNetwork

        Loader {
          anchors.fill: parent
          active: rootRect.showNetwork
          sourceComponent: NetworkPanel {
            anchors.fill: parent
            panelVisible: rootRect.showNetwork
          }
        }
      }

      Rectangle {
        anchors.fill: parent
        color: "transparent"
        opacity: rootRect.showNightLight ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        enabled: rootRect.showNightLight

        Loader {
          anchors.fill: parent
          active: rootRect.showNightLight
          sourceComponent: NightLightPanel {
            anchors.fill: parent
            nightLightEnabled: rootRect.nightLightEnabled
            nightLightTemp: rootRect.nightLightTemp
            enabledChangedCallback: function(enabled) {
              rootRect.onNightLightChange(enabled, rootRect.nightLightTemp);
            }
            tempChangedCallback: function(temp) {
              rootRect.onNightLightChange(rootRect.nightLightEnabled, temp);
            }
          }
        }
      }

      Rectangle {
        anchors.fill: parent
        color: "transparent"
        opacity: rootRect.showMedia ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        enabled: rootRect.showMedia

        Loader {
          anchors.fill: parent
          active: rootRect.showMedia
          sourceComponent: MediaPanel {
            anchors.fill: parent
            panelActive: rootRect.showMedia
          }
        }
      }
    }

  }

  Rectangle {
    id: divider2
    x: 549
    y: 12
    width: 1
    height: parent.height - 24
    color: Settings.surface
  }

  QuickPanel {
    id: quickPanel
    x: 562
    y: 12
    width: 200
    height: parent.height - 24

    showMedia: rootRect.showMedia
    showBluetooth: rootRect.showBluetooth
    showNetwork: rootRect.showNetwork
    showNightLight: rootRect.showNightLight
    nightLightEnabled: rootRect.nightLightEnabled
    screenshotManager: rootRect.screenshotManager
    onToggleWlogout: function() {
      if (rootRect.onCloseRequested) rootRect.onCloseRequested();
      if (rootRect.onToggleWlogout) rootRect.onToggleWlogout();
    }

    onToggleMediaRequested: {
      rootRect.showMedia = !rootRect.showMedia;
      if (rootRect.showMedia) rootRect.hideAllPanels("media");
    }

    onToggleBluetoothRequested: {
      rootRect.showBluetooth = !rootRect.showBluetooth;
      if (rootRect.showBluetooth) rootRect.hideAllPanels("bluetooth");
    }

    onToggleNetworkRequested: {
      rootRect.showNetwork = !rootRect.showNetwork;
      if (rootRect.showNetwork) rootRect.hideAllPanels("network");
    }

    onToggleNightLightRequested: {
      rootRect.showNightLight = !rootRect.showNightLight;
      if (rootRect.showNightLight) rootRect.hideAllPanels("nightlight");
    }

    onScreenshotRequested: {
      if (rootRect.screenshotManager) {
        if (rootRect.onCloseRequested) rootRect.onCloseRequested();
        rootRect.screenshotManager.requestModeSelector();
      }
    }

    onOpenSettingsRequested: {
      if (rootRect.onCloseRequested) rootRect.onCloseRequested();
      if (Settings.settingsWindow)
        Settings.settingsWindow.toggle();
    }
  }

  Keys.onPressed: event => {
    switch (event.key) {
      case Qt.Key_R:
        rootRect.showMedia = !rootRect.showMedia;
        if (rootRect.showMedia) rootRect.hideAllPanels("media");
        event.accepted = true;
        break;
      case Qt.Key_B:
        rootRect.showBluetooth = !rootRect.showBluetooth;
        if (rootRect.showBluetooth) rootRect.hideAllPanels("bluetooth");
        event.accepted = true;
        break;
      case Qt.Key_N:
        rootRect.showNetwork = !rootRect.showNetwork;
        if (rootRect.showNetwork) rootRect.hideAllPanels("network");
        event.accepted = true;
        break;
      case Qt.Key_L:
        rootRect.showNightLight = !rootRect.showNightLight;
        if (rootRect.showNightLight) rootRect.hideAllPanels("nightlight");
        event.accepted = true;
        break;
      case Qt.Key_C:
        rootRect.showCalendar = !rootRect.showCalendar;
        if (rootRect.showCalendar) rootRect.hideAllPanels("calendar");
        event.accepted = true;
        break;
      case Qt.Key_S:
        if (rootRect.onCloseRequested) rootRect.onCloseRequested();
        rootRect.screenshotManager.requestModeSelector();
        event.accepted = true;
        break;
      case Qt.Key_X:
        if (rootRect.onCloseRequested) rootRect.onCloseRequested();
        if (rootRect.onToggleWlogout) rootRect.onToggleWlogout();
        event.accepted = true;
        break;
      case Qt.Key_G:
        if (rootRect.onCloseRequested) rootRect.onCloseRequested();
        if (Settings.settingsWindow)
          Settings.settingsWindow.toggle();
        event.accepted = true;
        break;
      case Qt.Key_Q:
      case Qt.Key_Escape:
        if (rootRect.onCloseRequested) rootRect.onCloseRequested();
        event.accepted = true;
        break;
    }
  }
}
