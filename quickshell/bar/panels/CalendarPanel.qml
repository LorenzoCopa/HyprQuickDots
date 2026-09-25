import QtQuick
import QtQuick.Layouts
import "../../config"

Item {
  id: root

  property bool compact: false
  // Cuando es true, el contenido se centra verticalmente dentro de la caja
  // (dos espaciadores con Layout.fillHeight). El popup del reloj lo deja en
  // false y el calendario llena toda la caja como antes.
  property bool centerContent: false
  readonly property int headerPx: compact ? 13 : 15
  readonly property int cellW: compact ? 40 : 38
  readonly property int cellH: compact ? 26 : 32
  readonly property int cellSize: compact ? 24 : 30
  readonly property int dayPx: compact ? 12 : 14
  readonly property int weekPx: compact ? 11 : 12

  CalendarModel {
    id: calendarModel
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: root.compact ? 6 : 8

    // Espaciador superior (centrado vertical del contenido).
    Item { Layout.fillHeight: root.centerContent }

    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: headerRow.implicitHeight

      RowLayout {
        id: headerRow
        anchors.centerIn: parent
        width: grid.implicitWidth

        Text {
          text: "<"
          color: Settings.muted
          font.family: Settings.fontFamily
          font.pixelSize: root.headerPx
          font.weight: Font.Bold

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              const d = calendarModel.currentDate;
              d.setMonth(d.getMonth() - 1);
              calendarModel.currentDate = new Date(d);
            }
          }
        }

        Item { Layout.fillWidth: true }

        Text {
          text: {
            const months = ["January", "February", "March", "April", "May", "June",
                          "July", "August", "September", "October", "November", "December"];
            return months[calendarModel.month] + " " + calendarModel.year;
          }
          color: Settings.fg
          font.family: Settings.fontFamily
          font.pixelSize: root.headerPx
          font.weight: Font.Bold
          horizontalAlignment: Text.AlignHCenter
        }

        Item { Layout.fillWidth: true }

        Text {
          text: ">"
          color: Settings.muted
          font.family: Settings.fontFamily
          font.pixelSize: root.headerPx
          font.weight: Font.Bold

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              const d = calendarModel.currentDate;
              d.setMonth(d.getMonth() + 1);
              calendarModel.currentDate = new Date(d);
            }
          }
        }
      }
    }

    Item { Layout.preferredHeight: 2 }

    GridLayout {
      id: grid
      columns: 7
      rowSpacing: 2
      columnSpacing: 0
      Layout.preferredWidth: root.cellW * 7
      Layout.fillWidth: false
      Layout.alignment: Qt.AlignHCenter

      Repeater {
        model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

        delegate: Text {
          required property var modelData
          text: modelData
          color: Settings.muted
          font.family: Settings.fontFamily
          font.pixelSize: root.weekPx
          font.weight: Font.Bold
          horizontalAlignment: Text.AlignHCenter
          Layout.preferredWidth: root.cellW
        }
      }

      Repeater {
        model: calendarModel.dayCells

        delegate: Item {
          id: calCellDelegate
          required property var modelData
          Layout.preferredWidth: root.cellW
          Layout.preferredHeight: root.cellH

          Rectangle {
            id: cellBg
            anchors.centerIn: parent
            width: root.cellSize
            height: root.cellSize
            radius: 7
            color: calCellDelegate.modelData.today ? Settings.accent
                 : calCellDelegate.modelData.current ? Settings.selectionBg
                 : cellMouse.containsMouse ? Settings.surface
                 : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
          }

          Text {
            anchors.centerIn: parent
            text: calCellDelegate.modelData.day > 0 ? calCellDelegate.modelData.day : ""
            color: {
              if (calCellDelegate.modelData.day <= 0) return "transparent";
              if (calCellDelegate.modelData.today) return Settings.bg;
              if (calCellDelegate.modelData.current) return Settings.fg;
              return Settings.muted;
            }
            font.family: Settings.fontFamily
            font.pixelSize: root.dayPx
            font.weight: calCellDelegate.modelData.today ? Font.Bold : Font.Normal
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }

          MouseArea {
            id: cellMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (calCellDelegate.modelData.day > 0) {
                const d = new Date(calendarModel.year, calendarModel.month, calCellDelegate.modelData.day);
                calendarModel.selectedDate = d;
              }
            }
          }
        }
      }
    }

    // Espaciador inferior (centrado vertical del contenido).
    Item { Layout.fillHeight: root.centerContent }
  }
}
