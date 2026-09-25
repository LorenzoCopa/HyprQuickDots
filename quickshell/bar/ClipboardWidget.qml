pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

Item {
  id: root
  implicitHeight: Settings.barHeight
  implicitWidth: clipIcon.implicitWidth

  property bool hasContent: false
  signal requestShowClipboard()

  FileView {
    id: clipDbWatcher
    path: Quickshell.env("HOME") + "/.cache/cliphist/db"
    watchChanges: true
    onFileChanged: {
      clipProc.running = false
      clipProc.running = true
    }
  }

  Process {
    id: clipProc
    command: ["sh", "-c", "cliphist list 2>/dev/null | head -1"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        root.hasContent = text.trim().length > 0
      }
    }
  }

  Component.onCompleted: clipProc.running = true

  SymbolicIcon {
    id: clipIcon
    anchors.centerIn: parent
    path: Icons.clipboard
    color: Settings.accent
    implicitSize: 14
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.requestShowClipboard()
  }
}
