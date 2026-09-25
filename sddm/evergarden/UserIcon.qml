import QtQuick

// Icono de usuario (cabeza + hombros) dibujado en Canvas para poder
// recolorearlo según el estado del campo (muted → accent al enfocar).
Canvas {
    id: root

    property color iconColor: "#5E7B73"

    implicitWidth: 16
    implicitHeight: 16

    onIconColorChanged: root.requestPaint()

    onPaint: {
        const ctx = root.getContext("2d");
        ctx.reset();
        ctx.strokeStyle = root.iconColor;
        ctx.fillStyle = root.iconColor;
        ctx.lineWidth = 1.8;
        ctx.lineJoin = "round";
        ctx.lineCap = "round";
        // cabeza
        ctx.beginPath();
        ctx.arc(8, 5.6, 3.1, 0, Math.PI * 2);
        ctx.stroke();
        // hombros (semicírculo superior)
        ctx.beginPath();
        ctx.arc(8, 14, 5.8, Math.PI, 0, false);
        ctx.stroke();
    }
}