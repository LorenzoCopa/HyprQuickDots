import Quickshell
import QtQuick
import Quickshell.Services.Notifications
import Quickshell.Services.Mpris
import Quickshell.Io
import "."
import "../config"

Scope {
  id: root

  // El host de notificaciones (NotificationServer, DND) vive en la raíz de
  // shell.qml y se comparte por propiedades. El toast flotante también vive
  // en la raíz (NotificationToast), no aquí.
  required property var notifModel
  required property bool dndEnabled
  required property var onToggleDnd
  required property var onClearAll
  required property var onAutoDndOn
  required property var onAutoDndOff
  required property bool nightLightEnabled
  required property int nightLightTemp
  required property var onNightLightChange
  property var toggleWlogout: function() {}

  /* qmllint disable uncreatable-type */
  PanelWindow {
    id: panel

    anchors {
      top: true
      left: true
      right: true
    }

    implicitHeight: Settings.barHeight
    color: Settings.bg

    Item {
      anchors {
        fill: parent
        leftMargin: 8
        rightMargin: 8
      }

      ClockWidget {
        id: clockWidget
        anchors.centerIn: parent
        panelWindow: panel
        notifModel: root.notifModel
        dndEnabled: root.dndEnabled
        onToggleDnd: root.onToggleDnd
        onClearAll: root.onClearAll
        onToggleWlogout: root.toggleWlogout
        nightLightEnabled: root.nightLightEnabled
        nightLightTemp: root.nightLightTemp
        onNightLightChange: root.onNightLightChange
      }

      WorkspaceWidget {
        id: workspaceWidget
        anchors {
          left: parent.left
          verticalCenter: parent.verticalCenter
        }
      }

      MediaWidget {
        anchors {
          left: workspaceWidget.right
          leftMargin: 12
          verticalCenter: parent.verticalCenter
        }
        onRequestShowMedia: clockWidget.showMediaPanel()
      }

      Row {
        anchors {
          right: parent.right
          verticalCenter: parent.verticalCenter
        }
        spacing: 2

        MultiWindowIndicator {
          id: multiWindowIndicator
        }

        TrayButton {
          id: trayButton
          panelWindow: panel
        }
      }
    }
  }
  /* qmllint enable uncreatable-type */

  IpcHandler {
    target: "clock-popup"
    function toggle(): void { clockWidget.togglePopup(); }
    function hide(): void { clockWidget.hidePopup(); }
  }

  IpcHandler {
    target: "notif-dnd"
    function autoDndOn(): void { root.onAutoDndOn(); }
    function autoDndOff(): void { root.onAutoDndOff(); }
  }
}
