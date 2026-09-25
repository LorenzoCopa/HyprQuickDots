pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../config"

Item {
  id: root
  implicitHeight: Settings.barHeight
  clip: true

  property var activePlayer: null
  readonly property bool hasPlayer: activePlayer != null && activePlayer.trackTitle !== ""
  visible: hasPlayer
  implicitWidth: hasPlayer ? marqueeBox.width + 12 + peakRow.implicitWidth : 0

  readonly property var audioSink: Pipewire.defaultAudioSink || null

  signal requestShowMedia()
  property alias peakMon: peakMonitor

  PwObjectTracker {
    objects: root.audioSink ? [root.audioSink] : []
  }

  PwNodePeakMonitor {
    id: peakMonitor
    node: root.audioSink
    enabled: root.audioSink != null && root.hasPlayer
  }

  function updatePlayer() {
    root.activePlayer = Settings.findActiveMprisPlayer();
  }

  Timer {
    interval: 1000
    repeat: true
    running: true
    onTriggered: root.updatePlayer()
  }

  Component.onCompleted: {
    root.updatePlayer();
  }

  Row {
    anchors {
      left: parent.left
      verticalCenter: parent.verticalCenter
    }
    spacing: 6

    Item {
      id: marqueeBox
      width: 200
      height: parent.height
      clip: true

      Text {
        id: marqueeText
        property bool overflowing: implicitWidth > marqueeBox.width

        anchors.verticalCenter: parent.verticalCenter
        x: 0
        text: {
          if (!root.activePlayer) return "";
          const artist = root.activePlayer.trackArtist;
          const title = root.activePlayer.trackTitle;
          return artist ? artist + " \u2014 " + title : title;
        }
        color: Settings.fg
        font.family: Settings.fontFamily
        font.pixelSize: Settings.fontSize - 2
        font.weight: Font.Normal

        NumberAnimation on x {
          running: marqueeText.overflowing && root.hasPlayer
          from: 0
          to: marqueeBox.width - (marqueeText.implicitWidth || 0)
          duration: Math.max(5000, (marqueeText.implicitWidth || 100) * 40)
          loops: Animation.Infinite
          easing.type: Easing.Linear
        }

        onTextChanged: x = 0
      }
    }

    Row {
      id: peakRow
      anchors.verticalCenter: parent.verticalCenter
      spacing: 2
      height: 14

      readonly property real peak: root.peakMon ? (root.peakMon.peak || 0) : 0

        Repeater {
        model: [
          { mult: 0.5, speed: 60 },
          { mult: 0.8, speed: 80 },
          { mult: 1.2, speed: 100 },
          { mult: 0.8, speed: 80 },
          { mult: 0.5, speed: 60 },
        ]

        Item {
          id: delItem
          width: 3
          height: parent.height

          required property var modelData
          readonly property real barPeak: peakRow.peak * modelData.mult

          Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: Math.max(1.5, Math.min(parent.height * 0.95, delItem.barPeak * parent.height * 0.95))
            radius: 1.5
            color: Settings.accent
            Behavior on height { NumberAnimation { duration: delItem.modelData.speed; easing.type: Easing.OutQuad } }
            Behavior on color { ColorAnimation { duration: 120 } }
          }
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.requestShowMedia()
  }
}
