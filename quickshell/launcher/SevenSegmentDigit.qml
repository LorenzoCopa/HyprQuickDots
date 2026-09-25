import QtQuick
import "../config"

// Dígito de siete segmentos estilo despertador/calculadora.
// Los segmentos se dibujan con rectángulos redondeados (sin fuente):
// solo se muestran los encendidos; los apagados no son visibles.
Item {
  id: root

  property int value: 0

  readonly property int segW: 26
  readonly property int segH: 50
  readonly property int thickness: 4
  readonly property real margin: 2
  readonly property string onColor: Settings.accent
  readonly property string offColor: "transparent"

  implicitWidth: segW
  implicitHeight: segH

  // Segmentos activos por dígito (a=superior, f/b=superiores laterales,
  // g=central, e/c=inferiores laterales, d=inferior).
  readonly property var segmentMap: ({
    "0": "abcdef",
    "1": "bc",
    "2": "abged",
    "3": "abgcd",
    "4": "fgbc",
    "5": "afgcd",
    "6": "afgecd",
    "7": "abc",
    "8": "abcdefg",
    "9": "abcfgd",
  })

  readonly property string active: root.segmentMap["" + root.value] || ""

  function isOn(seg) {
    return root.active.indexOf(seg) !== -1;
  }

  Repeater {
    model: [
      { name: "a", x: root.margin, y: 0, w: root.segW - 2 * root.margin, h: root.thickness },
      { name: "f", x: 0, y: root.margin, w: root.thickness, h: root.segH / 2 - 2 * root.margin },
      { name: "b", x: root.segW - root.thickness, y: root.margin, w: root.thickness, h: root.segH / 2 - 2 * root.margin },
      { name: "g", x: root.margin, y: root.segH / 2 - root.thickness / 2, w: root.segW - 2 * root.margin, h: root.thickness },
      { name: "e", x: 0, y: root.segH / 2 + root.thickness / 2, w: root.thickness, h: root.segH / 2 - 2 * root.margin },
      { name: "c", x: root.segW - root.thickness, y: root.segH / 2 + root.thickness / 2, w: root.thickness, h: root.segH / 2 - 2 * root.margin },
      { name: "d", x: root.margin, y: root.segH - root.thickness, w: root.segW - 2 * root.margin, h: root.thickness },
    ]

    delegate: Rectangle {
      required property var modelData
      x: modelData.x
      y: modelData.y
      width: modelData.w
      height: modelData.h
      radius: root.thickness / 2
      color: root.isOn(modelData.name) ? root.onColor : root.offColor

      Behavior on color {
        ColorAnimation { duration: 80 }
      }
    }
  }
}
