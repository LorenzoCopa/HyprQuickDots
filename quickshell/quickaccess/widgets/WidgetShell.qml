import QtQuick
import QtQuick.Layouts
import "../../config"

// Tarjeta base para los widgets de la columna derecha del QuickAccess.
// Misma gramática visual que el resto: relleno tenue (cardBg) + sombra
// suave, sin borde; el título en Settings.muted y el acento reservado a
// los estados activos. Los hijos declarados dentro del componente se
// apilan bajo el título (ColumnLayout). La altura se ajusta al contenido.
Item {
    id: root

    property string title: ""
    // Cuando es true la tarjeta se estira hasta el alto de su contenedor
    // (en vez de ajustarse al contenido) y el body se centra verticalmente.
    // Útil para cerrar el mosaico a un nivel fijo (p. ej. la GPU al ras de
    // Clima) sin dejar el contenido pegado arriba.
    property bool stretch: false

    width: parent ? parent.width : 0
    height: stretch ? (parent ? parent.height : 0) : body.implicitHeight + 20

    // Sombra suave bajo la caja (elevación sin tapar el fondo).
    Item {
        anchors.fill: parent
        Rectangle { x: 0; y: 2; width: parent.width; height: parent.height; radius: 16; color: "#26000000" }
        Rectangle { x: 0; y: 5; width: parent.width; height: parent.height; radius: 17; color: "#18000000" }
        Rectangle { x: 0; y: 8; width: parent.width; height: parent.height; radius: 18; color: "#0E000000" }
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: "#121212"
    }

    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: stretch ? undefined : parent.top
        anchors.verticalCenter: stretch ? parent.verticalCenter : undefined
        anchors.margins: 10
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: root.title
            color: Settings.muted
            font.family: Settings.fontFamily
            font.pixelSize: 12
            font.weight: Font.Bold
            elide: Text.ElideRight
        }
    }

    // Los hijos del componente se apilan bajo el título dentro del body.
    default property alias content: body.data
}