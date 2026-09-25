pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.SystemTray
import "../config"

Item {
  id: root

  required property var panelWindow

  implicitWidth: trayRow.implicitWidth
  implicitHeight: Settings.barHeight
  property var _tray: SystemTray

  Row {
    id: trayRow
    anchors.verticalCenter: parent.verticalCenter
    spacing: 4

    Repeater {
      model: SystemTray.items

      delegate: Item {
        id: trayDelegate
        required property SystemTrayItem modelData
        width: 26
        height: 26

        Rectangle {
          anchors.fill: parent
          radius: 6
          color: mouseArea.containsMouse ? Settings.selectionBg : "transparent"
          Behavior on color { ColorAnimation { duration: 80 } }
        }

        Image {
          anchors.centerIn: parent
          width: 18
          height: 18
          source: trayDelegate.modelData.icon
          sourceSize { width: 18; height: 18 }
          asynchronous: true
          fillMode: Image.PreserveAspectFit
        }

        MouseArea {
          id: mouseArea
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor

          onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
              if (trayDelegate.modelData.hasMenu) {
                const iconPos = mouseArea.mapToItem(
                  root.panelWindow.contentItem,
                  mouseArea.width / 2,
                  mouseArea.height
                )
                trayDelegate.modelData.display(root.panelWindow, Math.round(iconPos.x), Math.round(iconPos.y + 6))
              }
            } else if (mouse.button === Qt.LeftButton) {
              trayDelegate.modelData.activate()
            } else if (mouse.button === Qt.MiddleButton) {
              trayDelegate.modelData.secondaryActivate()
            }
          }

          onWheel: wheelEvent => {
            const delta = wheelEvent.angleDelta.y || wheelEvent.angleDelta.x
            const horiz = Math.abs(wheelEvent.angleDelta.x) > Math.abs(wheelEvent.angleDelta.y)
            trayDelegate.modelData.scroll(delta, horiz)
          }
        }
      }
    }
  }
}
