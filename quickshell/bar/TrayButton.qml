pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../config"

Item {
  id: root
  required property var panelWindow
  implicitWidth: 28
  implicitHeight: Settings.barHeight

  readonly property bool hasItems: SystemTray.items.length > 0

  Item {
    id: btn
    width: 28
    height: 22
    anchors.verticalCenter: parent.verticalCenter

    SymbolicIcon {
      anchors.centerIn: parent
      path: Icons.trayArrow
      color: Settings.fg
      implicitSize: 14
    }

    MouseArea {
      id: btnMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        popup.visible = !popup.visible;
        if (popup.visible) popup.updatePosition();
      }
    }
  }

  PopupWindow {
    id: popup
    color: "transparent"
    visible: false
    grabFocus: true
    implicitWidth: popupContent.implicitWidth
    implicitHeight: popupContent.implicitHeight

    anchor.window: root.panelWindow

    QsMenuAnchor {
      id: contextMenu
      anchor.window: popup
    }

    Rectangle {
      id: popupContent
      focus: true
      color: Settings.bg
      radius: 10
      border { width: 1; color: Settings.surface }
      implicitWidth: Math.max(trayRow.implicitWidth + 16, 50)
      implicitHeight: Math.max(trayRow.implicitHeight + 16, 42)

      Row {
        id: trayRow
        anchors.centerIn: parent
        spacing: 4

        Repeater {
          model: SystemTray.items

          delegate: Item {
            required property SystemTrayItem modelData
            width: 26
            height: 26

            Rectangle {
              anchors.fill: parent
              radius: 6
              color: trayMouse.containsMouse ? Settings.selectionBg : "transparent"
              Behavior on color { ColorAnimation { duration: 80 } }
            }

            Image {
              anchors.centerIn: parent
              width: 18
              height: 18
              source: modelData.icon
              sourceSize { width: 18; height: 18 }
              asynchronous: true
              fillMode: Image.PreserveAspectFit
            }

            MouseArea {
              id: trayMouse
              anchors.fill: parent
              acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor

              onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                  if (modelData.hasMenu) {
                    const iconPos = trayMouse.mapToItem(
                      popup.contentItem,
                      trayMouse.width / 2,
                      trayMouse.height
                    );
                    contextMenu.anchor.rect.x = Math.round(iconPos.x);
                    contextMenu.anchor.rect.y = Math.round(iconPos.y + 6);
                    contextMenu.menu = modelData.menu;
                    contextMenu.open();
                  }
                } else if (mouse.button === Qt.LeftButton) {
                  modelData.activate();
                } else if (mouse.button === Qt.MiddleButton) {
                  modelData.secondaryActivate();
                }
              }

              onWheel: wheelEvent => {
                const delta = wheelEvent.angleDelta.y || wheelEvent.angleDelta.x;
                const horiz = Math.abs(wheelEvent.angleDelta.x) > Math.abs(wheelEvent.angleDelta.y);
                modelData.scroll(delta, horiz);
              }
            }
          }
        }
      }

      Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
          popup.visible = false;
          event.accepted = true;
        }
      }
    }

    function updatePosition() {
      var r = root.panelWindow.itemRect(btn);
      anchor.rect.x = r.x + r.width / 2 - popupContent.implicitWidth / 2;
      anchor.rect.y = r.y + r.height + 6;
    }

    onVisibleChanged: {
      if (visible) updatePosition();
    }
  }
}
