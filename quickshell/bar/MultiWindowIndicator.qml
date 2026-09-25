pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import "../config"

Item {
  id: root
  width: 20
  height: Settings.barHeight
  visible: hiddenCount > 0

  property var openWindows: []

  readonly property int hiddenCount: {
    if (!Hyprland.focusedWorkspace) return 0;
    var wsId = Hyprland.focusedWorkspace.id;
    var count = 0;
    for (var i = 0; i < root.openWindows.length; i++) {
      if (root.openWindows[i].workspace === wsId)
        count++;
    }
    return Math.max(0, count - 1);
  }

  // Event-driven: en vez de lanzar `hyprctl clients -j` cada 2s sin parar
  // (~30 forks/min en idle), el poll se dispara SOLO cuando Hyprland emite
  // un evento que puede cambiar la lista de ventanas (abrir/cerrar/mover/
  // minimizar/título), con un debounce de 300ms para agrupar ráfagas, más
  // una re-sincronización lenta de 15s como red de seguridad por si se
  // escapa algún evento.
  Process {
    id: clientsProc
    command: ["hyprctl", "clients", "-j"]
    running: false
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

  function refetchClients() {
    if (!clientsProc.running)
      clientsProc.running = true;
  }

  Timer {
    id: refetchDebounce
    interval: 300
    onTriggered: root.refetchClients()
  }

  // Red de seguridad: re-lee aunque no llegue ningún evento.
  Timer {
    interval: 15000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refetchClients()
  }

  Connections {
    target: Hyprland
    function onRawEvent(ev) {
      switch (ev.name) {
        case "openwindow":
        case "closewindow":
        case "movewindow":
        case "movewindowv2":
        case "windowtitle":
        case "windowtitlev2":
        case "minimize":
        case "fullscreen":
        case "configreloaded":
          refetchDebounce.restart();
          break;
      }
    }
  }

  SymbolicIcon {
    id: stackIcon
    anchors.centerIn: parent
    path: Icons.stack
    color: Settings.fg
    implicitSize: 14
  }

  Item {
    id: countBadge
    width: 14
    height: 14
    anchors {
      right: parent.right
      top: parent.top
      rightMargin: -2
      topMargin: -2
    }
    visible: root.hiddenCount > 1

    Rectangle {
      anchors.fill: parent
      radius: 7
      color: Settings.bg
      border { width: 1; color: Settings.surface }
    }

    Text {
      anchors.centerIn: parent
      text: root.hiddenCount
      color: Settings.fg
      font.family: Settings.fontFamily
      font.pixelSize: 9
      font.bold: true
    }
  }
}
