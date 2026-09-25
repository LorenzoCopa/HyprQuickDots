import QtQuick

// Icono de candado (cuerpo + grillete) dibujado en Canvas para poder
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
        ctx.lineWidth = 1.8;
        ctx.lineJoin = "round";
        ctx.lineCap = "round";
        // grillete (U invertida encima del cuerpo)
        ctx.beginPath();
        ctx.arc(8, 9.2, 3.5, Math.PI, 0, false);
        ctx.stroke();
        // cuerpo redondeado
        ctx.beginPath();
        ctx.moveTo(4, 9.2);
        ctx.lineTo(12, 9.2);
        ctx.quadraticCurveTo(13.2, 9.2, 13.2, 10.4);
        ctx.lineTo(13.2, 14);
        ctx.quadraticCurveTo(13.2, 15.2, 12, 15.2);
        ctx.lineTo(4, 15.2);
        ctx.quadraticCurveTo(2.8, 15.2, 2.8, 14);
        ctx.lineTo(2.8, 10.4);
        ctx.quadraticCurveTo(2.8, 9.2, 4, 9.2);
        ctx.stroke();
    }
}