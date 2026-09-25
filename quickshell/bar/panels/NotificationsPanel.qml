import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import "../../config"

Item {
  id: root

  property var notifModel: null
  property bool dndEnabled: false
  property var onToggleDnd: null
  property var onClearAll: null
  // Muestra los controles de volumen/luz al pie del panel (QuickAccess lo
  // activa; el popup del reloj los mantiene ocultos).
  property bool showControls: false

  ColumnLayout {
    anchors.fill: parent
    spacing: 6

    // ── Cabecera: título + botón de borrar todo ──
    RowLayout {
      Layout.fillWidth: true
      Layout.preferredHeight: 26
      Layout.leftMargin: 8
      Layout.rightMargin: 8
      spacing: 6

      Text {
        text: "Notificaciones"
        color: Settings.muted
        font.family: Settings.fontFamily
        font.pixelSize: 11
        font.weight: Font.Bold
        Layout.alignment: Qt.AlignVCenter
      }

      Text {
        text: "(" + notifList.count + ")"
        color: Settings.muted
        font.family: Settings.fontFamily
        font.pixelSize: 10
        Layout.alignment: Qt.AlignVCenter
      }

      Item { Layout.fillWidth: true }

      // Borrar todo: tile pequeño con hover, mismo lenguaje que el ✕
      // de cada notificación (fondo suave al pasar el ratón).
      Rectangle {
        Layout.preferredWidth: 24
        Layout.preferredHeight: 24
        radius: 7
        color: clearHover.containsMouse ? Settings.surface : "transparent"
        Behavior on color { ColorAnimation { duration: 80 } }

        SymbolicIcon {
          anchors.centerIn: parent
          path: Icons.trash
          color: clearHover.containsMouse ? Settings.fg : Settings.muted
          implicitSize: 13
        }

        MouseArea {
          id: clearHover
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: { if (root.onClearAll) root.onClearAll(); }
        }
      }
    }

    // ── Controles: volumen + luz nocturna (solo QuickAccess) ──
    // Ícono + slider horizontal, integrados arriba, bajo la cabecera del
    // panel de notificaciones. El estado del volumen viene de Pipewire
    // (sink por defecto); la luz de Settings.nightLightTemp con vista
    // previa en vivo. El popup del reloj los mantiene ocultos (showControls).
    ColumnLayout {
      Layout.fillWidth: true
      Layout.topMargin: 6
      spacing: 6
      visible: root.showControls

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Settings.surface
      }

      // ── Volumen ──
      RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 10
        Layout.rightMargin: 10
        spacing: 8

        property var sink: Pipewire.ready ? Pipewire.defaultAudioSink : null
        readonly property real volume: sink && sink.audio
          && Number.isFinite(sink.audio.volume) ? sink.audio.volume : 0
        readonly property bool muted: sink && sink.audio
          && typeof sink.audio.muted === "boolean" ? sink.audio.muted : false

        SymbolicIcon {
          path: parent.muted ? Icons.volumeMute
              : parent.volume <= 0.01 ? Icons.volumeOff
              : parent.volume < 0.34 ? Icons.volumeLow
              : parent.volume < 0.67 ? Icons.volumeMedium
              : Icons.volumeHigh
          color: parent.muted ? Settings.red : Settings.accent
          implicitSize: 16
          Layout.alignment: Qt.AlignVCenter

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (parent.parent.sink && parent.parent.sink.audio)
                parent.parent.sink.audio.muted = !parent.parent.sink.audio.muted;
            }
          }
        }

        Slider {
          id: notifVolSlider
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          from: 0
          to: 100
          value: Math.round(parent.volume * 100)
          hoverEnabled: true
          onMoved: {
            if (parent.sink && parent.sink.audio)
              parent.sink.audio.volume = value / 100;
          }

          background: Rectangle {
            x: notifVolSlider.leftPadding
            y: notifVolSlider.topPadding + notifVolSlider.availableHeight / 2 - height / 2
            width: notifVolSlider.availableWidth
            height: 4
            radius: 2
            color: Settings.surface

            Rectangle {
              anchors.left: parent.left
              width: parent.width * notifVolSlider.visualPosition
              height: parent.height
              radius: 2
              color: Settings.accent
            }
          }

          handle: Rectangle {
            x: notifVolSlider.leftPadding + notifVolSlider.visualPosition * (notifVolSlider.availableWidth - width)
            y: notifVolSlider.topPadding + notifVolSlider.availableHeight / 2 - height / 2
            implicitWidth: 12
            implicitHeight: 12
            radius: 6
            color: Settings.accent
            border {
              width: 2
              color: Settings.bg
            }
          }
        }

        Text {
          text: Math.round(parent.volume * 100) + "%"
          color: Settings.fg
          font.family: Settings.fontFamily
          font.pixelSize: 10
          font.weight: Font.Bold
          Layout.alignment: Qt.AlignVCenter
        }
      }

      // ── Brillo (solo si hay backlight) ──
      RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 10
        Layout.rightMargin: 10
        Layout.preferredHeight: Settings.hasBrightness ? implicitHeight : 0
        visible: Settings.hasBrightness
        spacing: 8

        SymbolicIcon {
          path: Icons.brightness
          color: Settings.accent
          implicitSize: 16
          Layout.alignment: Qt.AlignVCenter
        }

        Slider {
          id: notifBrightSlider
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          from: 5
          to: 100
          stepSize: 1
          value: Settings.brightness
          hoverEnabled: true
          onMoved: if (Settings.setBrightness) Settings.setBrightness(value)

          background: Rectangle {
            x: notifBrightSlider.leftPadding
            y: notifBrightSlider.topPadding + notifBrightSlider.availableHeight / 2 - height / 2
            width: notifBrightSlider.availableWidth
            height: 4
            radius: 2
            color: Settings.surface
            Rectangle {
              anchors.left: parent.left
              width: parent.width * notifBrightSlider.visualPosition
              height: parent.height
              radius: 2
              color: Settings.accent
            }
          }
          handle: Rectangle {
            x: notifBrightSlider.leftPadding + notifBrightSlider.visualPosition * (notifBrightSlider.availableWidth - width)
            y: notifBrightSlider.topPadding + notifBrightSlider.availableHeight / 2 - height / 2
            implicitWidth: 12
            implicitHeight: 12
            radius: 6
            color: Settings.accent
            border { width: 2; color: Settings.bg }
          }
        }

        Text {
          text: Settings.brightness + "%"
          color: Settings.fg
          font.family: Settings.fontFamily
          font.pixelSize: 10
          font.weight: Font.Bold
          Layout.alignment: Qt.AlignVCenter
        }
      }

      // ── Luz nocturna (temperatura) ──
      RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 10
        Layout.rightMargin: 10
        spacing: 8

        SymbolicIcon {
          path: Icons.nightlight
          color: Settings.nightLightEnabled ? Settings.accent : Settings.muted
          implicitSize: 16
          Layout.alignment: Qt.AlignVCenter
        }

        Slider {
          id: notifNlSlider
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          from: 1000
          to: 6500
          stepSize: 100
          enabled: Settings.nightLightEnabled
          hoverEnabled: true
          value: Settings.nightLightTemp
          onMoved: {
            Settings.nightLightTemp = value;
            if (Settings.previewNightLightTemp)
              Settings.previewNightLightTemp(value);
          }
          onPressedChanged: {
            if (!pressed && Settings.applyNightLight)
              Settings.applyNightLight();
          }

          background: Rectangle {
            x: notifNlSlider.leftPadding
            y: notifNlSlider.topPadding + notifNlSlider.availableHeight / 2 - height / 2
            width: notifNlSlider.availableWidth
            height: 4
            radius: 2
            color: Settings.surface

            Rectangle {
              anchors.left: parent.left
              width: parent.width * notifNlSlider.visualPosition
              height: parent.height
              radius: 2
              color: Settings.nightLightEnabled ? Settings.accent : Settings.surface
            }
          }

          handle: Rectangle {
            x: notifNlSlider.leftPadding + notifNlSlider.visualPosition * (notifNlSlider.availableWidth - width)
            y: notifNlSlider.topPadding + notifNlSlider.availableHeight / 2 - height / 2
            implicitWidth: 12
            implicitHeight: 12
            radius: 6
            color: Settings.nightLightEnabled ? Settings.accent : Settings.surface
            border {
              width: 2
              color: Settings.bg
            }
          }
        }

        Text {
          text: Settings.nightLightTemp + "K"
          color: Settings.nightLightEnabled ? Settings.accent : Settings.muted
          font.family: Settings.fontFamily
          font.pixelSize: 10
          font.weight: Font.Bold
          Layout.alignment: Qt.AlignVCenter
        }
      }
    }

    // ── No molestar + switch ──
    // Activo = acento (mismo lenguaje que el resto de toggles); el estado
    // OFF usaba surface para el track y quedaba invisible sobre el fondo
    // negro, así que el knob pasa a muted para distinguirse siempre.
    RowLayout {
      Layout.fillWidth: true
      Layout.preferredHeight: 24
      Layout.leftMargin: 8
      Layout.rightMargin: 8
      spacing: 8

      SymbolicIcon {
        path: Icons.notifications
        color: root.dndEnabled ? Settings.accent : Settings.muted
        implicitSize: 14
        Layout.alignment: Qt.AlignVCenter
      }

      Text {
        text: "No molestar"
        color: root.dndEnabled ? Settings.accent : Settings.muted
        font.family: Settings.fontFamily
        font.pixelSize: 10
        font.weight: Font.Bold
        Layout.alignment: Qt.AlignVCenter
      }

      Item { Layout.fillWidth: true }

      Item {
        Layout.preferredWidth: 34
        Layout.preferredHeight: 18

        Rectangle {
          anchors.fill: parent
          radius: height / 2
          color: root.dndEnabled ? Settings.accent : Settings.surface
          Behavior on color { ColorAnimation { duration: 80 } }

          Rectangle {
            width: 14
            height: 14
            radius: 7
            color: root.dndEnabled ? Settings.bg : Settings.muted
            anchors.verticalCenter: parent.verticalCenter
            x: root.dndEnabled ? parent.width - width - 2 : 2
            Behavior on x { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: { if (root.onToggleDnd) root.onToggleDnd(); }
        }
      }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 1
      color: Settings.surface
    }

    ListView {
      id: notifList
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: 4
      clip: true
      model: root.notifModel

      delegate: Item {
        id: notifDelegate
        required property var modelData
        width: ListView.view.width
        implicitHeight: bodyLayout.implicitHeight + 12

        readonly property bool hovered: cellHover.containsMouse

        Rectangle {
          anchors.fill: parent
          color: notifDelegate.hovered ? Settings.surface : "transparent"
          radius: 6
          Behavior on color { ColorAnimation { duration: 100 } }
        }

        RowLayout {
          id: bodyLayout
          anchors.fill: parent
          anchors.margins: 6
          spacing: 6
          z: 1

          Rectangle {
            id: notifIconBg
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            Layout.alignment: Qt.AlignTop
            radius: 13
            color: notifDelegate.modelData.urgency === NotificationUrgency.Critical ? Settings.red : Settings.selectionBg
            layer.enabled: notifImg.visible

            Image {
              id: notifImg
              anchors.fill: parent
              source: Settings.notifIconUrl(notifDelegate.modelData)
              fillMode: Image.PreserveAspectCrop
              visible: status === Image.Ready
            }

            Text {
              anchors.centerIn: parent
              text: {
                const name = Settings.notifAppName(notifDelegate.modelData);
                return name !== "" ? name.charAt(0).toUpperCase() : "?";
              }
              color: Settings.bg
              font.family: Settings.fontFamily
              font.pixelSize: 12
              font.weight: Font.Bold
              visible: !notifImg.visible
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
              Layout.fillWidth: true
              text: {
                const name = Settings.notifAppName(notifDelegate.modelData);
                return name !== "" ? name : "notify-send";
              }
              color: Settings.fg
              font.family: Settings.fontFamily
              font.pixelSize: 11
              font.weight: Font.Bold
              elide: Text.ElideRight
              maximumLineCount: 1
            }

            Text {
              id: notifBody
              Layout.fillWidth: true
              text: {
                const s = notifDelegate.modelData.summary ? notifDelegate.modelData.summary : "";
                const b = notifDelegate.modelData.body ? notifDelegate.modelData.body : "";
                return s + (s && b ? " — " : "") + b;
              }
              color: Settings.muted
              font.family: Settings.fontFamily
              font.pixelSize: 10
              elide: Text.ElideRight
              maximumLineCount: 2
              wrapMode: Text.Wrap
            }
          }

          Item {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignTop

            Rectangle {
              anchors.fill: parent
              radius: 6
              color: dismissMouse.containsMouse ? Settings.surface : "transparent"
              Behavior on color { ColorAnimation { duration: 80 } }
            }

            Text {
              anchors.centerIn: parent
              text: "✕"
              color: Settings.muted
              font.family: Settings.fontFamily
              font.pixelSize: 12
            }

            MouseArea {
              id: dismissMouse
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: notifDelegate.modelData.tracked = false
            }
          }
        }

        MouseArea {
          id: cellHover
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton
          z: -1
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            var n = notifDelegate.modelData;
            var handled = false;
            for (var i = 0; i < n.actions.length; i++) {
              if (n.actions[i].identifier === "default") {
                n.actions[i].invoke();
                handled = true;
                break;
              }
            }
            if (!handled && n.desktopEntry !== "") {
              var entry = DesktopEntries.heuristicLookup(n.desktopEntry);
              if (entry) entry.execute();
            }
          }
        }
      }
    }

    Text {
      Layout.alignment: Qt.AlignHCenter
      Layout.fillWidth: true
      Layout.topMargin: 20
      visible: !root.notifModel || notifList.count === 0
      text: "Sin notificaciones"
      color: Settings.muted
      font.family: Settings.fontFamily
      font.pixelSize: 12
    }
  }
}
