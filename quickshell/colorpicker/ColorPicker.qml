// ─── Selector de color (hyprpicker + OSD) ─────────────────────────────
// `qs ipc call colorpicker pick` lanza hyprpicker con la lupa congelada;
// al hacer clic, el color elegido se muestra en el OSD con sus códigos
// hex / rgb / hsl y botones para copiar. `hide` cierra el OSD.

import QtQuick
import Quickshell
import Quickshell.Io
import "."

Scope {
  id: root

  ColorPickerOsd {
    id: osd
  }

  Process {
    id: pickProc
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        var text = this.text.trim();
        if (text.length > 0) {
          var hex = text.toUpperCase();
          if (!hex.startsWith("#"))
            hex = "#" + hex;
          osd.hexColor = hex;
          osd.visible = true;
        }
      }
    }
  }

  function pick() {
    if (pickProc.running) return;
    osd.visible = false;
    // -f hex  → salida en hex (mayúsculas)
    // -b      → sin coloreado "fancy" en la salida (por si acaso)
    // -r      → congela también los monitores inactivos
    pickProc.command = ["hyprpicker", "-f", "hex", "-b", "-r"];
    pickProc.running = true;
  }

  IpcHandler {
    target: "colorpicker"

    function pick(): void { root.pick(); }
    function hide(): void { osd.visible = false; }
  }
}