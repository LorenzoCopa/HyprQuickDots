pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import "../config"

Item {
  id: root
  implicitWidth: appsRow.implicitWidth
  implicitHeight: Settings.barHeight
  visible: wsWindows.length > 0

  property var openWindows: []
  readonly property var wsWindows: {
    if (!Hyprland.focusedWorkspace) return [];
    var wsId = Hyprland.focusedWorkspace.id;
    var result = [];
    for (var i = 0; i < root.openWindows.length; i++) {
      if (root.openWindows[i].workspace === wsId)
        result.push(root.openWindows[i]);
    }
    return result;
  }

  Process {
    id: clientsProc
    command: ["hyprctl", "clients", "-j"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(text);
          var result = [];
          for (var i = 0; i < data.length; i++) {
            var c = data[i];
            if (!c.mapped || c.hidden) continue;
            var title = c.title || "";
            if (title.indexOf("qs-") === 0) continue;
            result.push({
              address: c.address,
              class: c.class || "",
              title: c.title || "",
              workspace: c.workspace ? c.workspace.id : 0,
            });
          }
          root.openWindows = result;
        } catch (e) {
          root.openWindows = [];
        }
      }
    }
  }

  Timer {
    interval: 2000
    repeat: true
    running: true
    onTriggered: clientsProc.running = true
  }

  function resolveIconName(appClass) {
    var entries = DesktopEntries.applications.values;
    var lower = appClass.toLowerCase();
    for (var i = 0; i < entries.length; i++) {
      var e = entries[i];
      var name = e.name.toLowerCase();
      var desktop = e.desktopFile || "";
      if (name === lower || name.includes(lower) || lower.includes(name) || desktop.toLowerCase().includes(lower))
        return e.icon;
    }
    return "";
  }

  function papirusPath(iconName) {
    if (iconName === "") return "";
    return "file:///usr/share/icons/Papirus/16x16/apps/" + iconName + ".svg";
  }

  function papirusFallback(appClass) {
    var lower = appClass.toLowerCase();
    if (lower.includes("discord") || lower.includes("vesktop")) return "file:///usr/share/icons/Papirus/16x16/apps/com.discordapp.Discord.svg";
    if (lower.includes("spotify")) return "file:///usr/share/icons/Papirus/16x16/apps/com.spotify.Client.svg";
    if (lower.includes("steam")) return "file:///usr/share/icons/Papirus/16x16/apps/com.valvesoftware.Steam.svg";
    if (lower.includes("slack")) return "file:///usr/share/icons/Papirus/16x16/apps/com.slack.Slack.svg";
    return "";
  }

  Row {
    id: appsRow
    anchors.verticalCenter: parent.verticalCenter
    spacing: 2

    Repeater {
      model: root.wsWindows

      delegate: Item {
        required property var modelData
        width: 22
        height: 22

        readonly property string iconName: root.resolveIconName(modelData.class)
        readonly property string fallbackPapirus: root.papirusFallback(modelData.class)
        readonly property url iconUrl: {
          var p = root.papirusPath(iconName);
          if (p !== "") return p;
          return fallbackPapirus;
        }

        Rectangle {
          anchors.fill: parent
          radius: 5
          color: appMouse.containsMouse ? Settings.selectionBg : "transparent"
          Behavior on color { ColorAnimation { duration: 80 } }
        }

        Image {
          id: iconImg
          anchors.centerIn: parent
          width: 16
          height: 16
          source: parent.iconUrl
          sourceSize { width: 16; height: 16 }
          asynchronous: true
          fillMode: Image.PreserveAspectFit
        }

        SymbolicIcon {
          anchors.centerIn: parent
          path: Icons.window
          color: appMouse.containsMouse ? Settings.fg : Settings.subtext0
          implicitSize: 14
          visible: iconImg.status !== Image.Ready
        }

        MouseArea {
          id: appMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: Hyprland.dispatch("hl.dsp.focus({ window = 'address:" + modelData.address + "' })")
        }
      }
    }
  }
}
