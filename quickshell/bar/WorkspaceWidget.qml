import Quickshell.Hyprland
import QtQuick
import "../config"

Item {
  id: root
  implicitHeight: Settings.barHeight
  implicitWidth: wsRow.implicitWidth

  Row {
    id: wsRow
    anchors {
      left: parent.left
      verticalCenter: parent.verticalCenter
    }
    spacing: 4

    Repeater {
      model: Settings.workspaceCount

      Rectangle {
        id: indicator
        required property int index
        readonly property int wsId: index + 1
        readonly property var ws: Hyprland.workspaces.values.find(function(w) { return w.id === wsId })
        readonly property bool isFocused: Hyprland.focusedWorkspace != null && Hyprland.focusedWorkspace.id === wsId
        readonly property bool exists: ws != null

        width: isFocused ? 24 : 6
        height: 6
        radius: 3
        color: isFocused ? Settings.accent : (exists ? Settings.subtext0 : Settings.surface)

        Behavior on width {
          NumberAnimation { duration: Settings.animationFast; easing.type: Easing.OutCubic }
        }
        Behavior on color {
          ColorAnimation { duration: Settings.animationFast; easing.type: Easing.OutCubic }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + indicator.wsId + " })")
        }
      }
    }
  }
}
