import QtQuick
import Quickshell
import "../config"

// Caja del reloj (vive en el QuickAccess, SUPER+B; antes en el launcher):
// días de la semana (MON..SUN) agrupados al centro y reloj seven-segment
// con la hora (y los dos puntos parpadeantes), todo centrado. Solo se
// pintan los segmentos activos (SevenSegmentDigit); los dos puntos
// parpadean.
//
// `boxed: false` se usa dentro de un mosaico del QuickAccess (el reloj no
// dibuja su propia caja/sombra y comparte el marco del mosaico).
// `vertical: true` escala la hora para llenar un mosaico alto (el del
// centro del QuickAccess).

Item {
  id: root

  // ── Configuración ─────────────────────────────────────────
  property bool boxed: true
  property bool vertical: false

  // Escala de la hora seven-segment en modo vertical (la anchura de los
  // días de la semana limita cuánto se puede agrandar sin salirse).
  readonly property real ts: root.vertical ? 2.2 : 1.0

  readonly property real contentWidth: Math.max(weekdaysRow.implicitWidth, 136 * root.ts)
  readonly property real contentHeight: root.vertical ? 30 + 50 * root.ts : 70

  readonly property real padX: root.boxed ? 16 : 0
  readonly property real padTop: root.boxed ? 14 : 0
  readonly property real padBottom: root.boxed ? 14 : 0

  width: contentWidth + padX * 2
  height: padTop + contentHeight + padBottom
  implicitWidth: width
  implicitHeight: height

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  // Parpadeo de los dos puntos de la hora (estilo LED).
  property real colonOpacity: 1.0
  Timer {
    interval: 1000
    repeat: true
    running: true
    onTriggered: root.colonOpacity = root.colonOpacity === 1.0 ? 0.12 : 1.0
  }

  readonly property var weekdays: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

  // getDay(): 0=Domingo...6=Sábado -> índice en `weekdays` (MON=0).
  readonly property int todayIndex: (clock.date.getDay() + 6) % 7

  // ── Sombra flotante tras la caja (solo con boxed) ──────
  Item {
    visible: root.boxed
    anchors.centerIn: parent
    width: parent.width
    height: parent.height

    Rectangle { x: 0; y: 2; width: parent.width; height: parent.height; radius: 15; color: "#26000000" }
    Rectangle { x: 0; y: 5; width: parent.width; height: parent.height; radius: 16; color: "#18000000" }
    Rectangle { x: 0; y: 8; width: parent.width; height: parent.height; radius: 17; color: "#0E000000" }
  }

  // ── Fondo de la caja (solo con boxed) ─────────────────
  Rectangle {
    visible: root.boxed
    anchors.fill: parent
    radius: 14
    color: Settings.bg
    border {
      width: 1
      color: Settings.surface
    }
  }

  // ── Contenido, siempre centrado ────────────────────────
  Column {
    id: content
    anchors.centerIn: parent
    spacing: root.vertical ? 18 : 8

    // Días de la semana agrupados al centro (MON..SUN), resaltando
    // el actual, sin estirarlos a lo ancho de la caja.
    Row {
      id: weekdaysRow
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: root.vertical ? 12 : 16

      Repeater {
        model: root.weekdays

        delegate: Text {
          required property int index
          required property string modelData

          text: modelData
          color: root.todayIndex === index ? Settings.accent : "#4DB3E6DB"
          font.family: Settings.fontFamily
          font.pixelSize: 10
          font.weight: Font.Bold
        }
      }
    }

      // Hora (dos puntos parpadeantes), centrada.
      Row {
        visible: !root.vertical
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 2

        SevenSegmentDigit { value: Math.floor(clock.date.getHours() / 10) }
        SevenSegmentDigit { value: clock.date.getHours() % 10 }

        // Dos puntos parpadeantes, con aire a ambos lados.
        Item {
          width: 24
          height: 50

          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 13
            width: 6
            height: 6
            radius: 3
            color: Settings.accent
            opacity: root.colonOpacity
          }

          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 13
            width: 6
            height: 6
            radius: 3
            color: Settings.accent
            opacity: root.colonOpacity
          }
        }

        SevenSegmentDigit { value: Math.floor(clock.date.getMinutes() / 10) }
        SevenSegmentDigit { value: clock.date.getMinutes() % 10 }
      }

    // ── Modo vertical: hora grande ────────────────────────
    Column {
      visible: root.vertical
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 14

      // Hora seven-segment escalada para llenar el mosaico alto.
      // La escala no ocupa espacio en el layout: si el Row se escala a
      // secas, la hora dibujada a 2x desborda por arriba y por abajo de
      // su ranura de 50px y se solapa con los días. Por
      // eso se reserva el tamaño visual real en un contenedor (width/height
      // = 136*ts x 50*ts) y el Row escalado se centra dentro.
      Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 136 * root.ts
        height: 50 * root.ts

        Row {
          anchors.centerIn: parent
          transformOrigin: Item.Center
          scale: root.ts
          spacing: 2

          SevenSegmentDigit { value: Math.floor(clock.date.getHours() / 10) }
          SevenSegmentDigit { value: clock.date.getHours() % 10 }

          // Dos puntos parpadeantes, con aire a ambos lados.
          Item {
            width: 24
            height: 50

            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              y: 13
              width: 6
              height: 6
              radius: 3
              color: Settings.accent
              opacity: root.colonOpacity
            }

            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              anchors.bottomMargin: 13
              width: 6
              height: 6
              radius: 3
              color: Settings.accent
              opacity: root.colonOpacity
            }
          }

          SevenSegmentDigit { value: Math.floor(clock.date.getMinutes() / 10) }
          SevenSegmentDigit { value: clock.date.getMinutes() % 10 }
        }
      }
    }
  }
}
