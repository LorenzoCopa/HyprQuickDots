pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../config"

FloatingWindow {
  id: root
  title: "qs-screenshot-mode"
  color: "transparent"
  implicitWidth: 360
  implicitHeight: 130
  visible: false

  signal modeSelected(string mode)

  onVisibleChanged: {
    if (visible) Qt.callLater(function() { keyCatcher.forceActiveFocus(); });
  }

  Rectangle {
    anchors.fill: parent
    color: Settings.bg
    radius: 12

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 12
      spacing: 8

      Text {
        Layout.alignment: Qt.AlignHCenter
        text: "Capturar pantalla"
        color: Settings.fg
        font.family: Settings.fontFamily
        font.pixelSize: 13
        font.weight: Font.Bold
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
          model: [
            { icon: Icons.monitor, label: "Pantalla", mode: "output", key: "P" },
            { icon: Icons.region, label: "Región", mode: "region", key: "R" },
            { icon: Icons.window, label: "Ventana", mode: "window", key: "W" },
            { icon: Icons.active, label: "Activa", mode: "active", key: "A" },
          ]

          delegate: Rectangle {
            id: modeBtn
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            radius: 8
            color: btnMouse.containsMouse ? Settings.selectionBg : Settings.surface
            Behavior on color { ColorAnimation { duration: 80 } }

            ColumnLayout {
              anchors.centerIn: parent
              spacing: 4

              SymbolicIcon {
                Layout.alignment: Qt.AlignHCenter
                path: modeBtn.modelData.icon
                color: Settings.fg
                implicitSize: 20
              }

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: modeBtn.modelData.label
                color: Settings.fg
                font.family: Settings.fontFamily
                font.pixelSize: 9
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.2
              }

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: "[" + modeBtn.modelData.key + "]"
                color: Settings.subtext0
                font.family: Settings.fontFamily
                font.pixelSize: 8
                font.weight: Font.Bold
              }
            }

            MouseArea {
              id: btnMouse
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              hoverEnabled: true
              onClicked: {
                root.modeSelected(modeBtn.modelData.mode);
                root.visible = false;
              }
            }
          }
        }
      }

      Text {
        Layout.alignment: Qt.AlignHCenter
        text: "Esc para cancelar"
        color: Settings.subtext0
        font.family: Settings.fontFamily
        font.pixelSize: 9
        font.weight: Font.Bold
      }
    }
  }

  HyprlandFocusGrab {
    windows: [root]
    active: root.visible
  }

  // Sobre un juego fullscreen el foco inicial puede quedarse en el juego
  // (constraint del puntero); pedirlo por dispatcher rompe el bloqueo.
  SelfFocus {
    targetTitle: "qs-screenshot-mode"
    active: root.visible
  }

  Item {
    id: keyCatcher
    anchors.fill: parent
    focus: true

    Keys.onPressed: function(event) {
      switch (event.key) {
        case Qt.Key_Escape:
          root.visible = false;
          event.accepted = true;
          break;
        case Qt.Key_P:
          root.modeSelected("output");
          root.visible = false;
          event.accepted = true;
          break;
        case Qt.Key_R:
          root.modeSelected("region");
          root.visible = false;
          event.accepted = true;
          break;
        case Qt.Key_W:
          root.modeSelected("window");
          root.visible = false;
          event.accepted = true;
          break;
        case Qt.Key_A:
          root.modeSelected("active");
          root.visible = false;
          event.accepted = true;
          break;
      }
    }
  }
}
