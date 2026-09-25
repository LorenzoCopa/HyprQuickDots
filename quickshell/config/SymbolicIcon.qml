import QtQuick

// Icono monocromo de Nerd Font (set Material Design Icons, familia "Symbols Nerd Font"),
// teñible con cualquier color en tiempo de ejecución.
// Cada "path" es el glifo del icono (codepoint PUA) definido en Icons.qml.
Item {
  id: root

  property string path: ""
  property color color: Settings.fg
  property int implicitSize: 24

  implicitWidth: root.implicitSize
  implicitHeight: root.implicitSize

  Text {
    anchors.centerIn: parent
    text: root.path
    color: root.color
    font.family: Settings.iconFontFamily
    font.pixelSize: root.implicitSize
  }
}
