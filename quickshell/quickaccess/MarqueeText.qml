pragma ComponentBehavior: Bound

// Texto con deslizamiento horizontal (marquee) cuando el contenido no cabe.
// Comportamiento:
//   - Si el texto cabe en `maxLines` líneas (ajustado a maxLines con wrap),
//     se muestra estático (hasta maxLines líneas, con elide por si acaso).
//   - Si necesita más de `maxLines` líneas, se muestra como UNA línea que se
//     desliza suavemente de un lado a otro, con pausa en cada extremo.
// La altura es la del propio texto (1 línea en modo marquee).

import QtQuick

Item {
    id: root

    // ── API ──
    property string text: ""
    property string color: "#ffffff"
    property string fontFamily: ""
    property int fontPixelSize: 12
    property int fontWeight: Font.Normal
    property int maxLines: 2
    property int gap: 32
    property int pauseMs: 1400

    implicitHeight: textEl.implicitHeight
    clip: true

    // Medición: texto ajustado a maxLines. Si se elide, es que desborda.
    Text {
        id: measure
        width: root.width
        visible: false
        text: root.text
        color: root.color
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.weight: root.fontWeight
        wrapMode: Text.Wrap
        maximumLineCount: root.maxLines
        elide: Text.ElideRight
    }

    readonly property bool overflow:
        root.text !== "" && measure.elidedText !== measure.text

    readonly property real scrollRange: overflow
        ? Math.max(0, textEl.implicitWidth - width)
        : 0

    Text {
        id: textEl
        width: root.width
        text: root.text
        color: root.color
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.weight: root.fontWeight
        wrapMode: root.overflow ? Text.NoWrap : Text.Wrap
        maximumLineCount: root.overflow ? 1 : root.maxLines
        elide: root.overflow ? Text.ElideNone : Text.ElideRight
        x: 0
    }

    // ── Deslizamiento tipo "cartel de anuncios" ──
    // Pausa mostrando el inicio → desliza hasta que el final del texto sale
    // por la izquierda → pausa → vuelve rápido al inicio y se repite. Así
    // nunca se pierde el nombre completo (siempre se llega a leer entero).
    function restart() {
        if (root.overflow) {
            textEl.x = 0;
            anim.restart();
        }
    }

    onOverflowChanged: {
        if (root.overflow) {
            textEl.x = 0;
            anim.start();
        } else {
            anim.stop();
            textEl.x = 0;
        }
    }

    onTextChanged: restart()
    onWidthChanged: restart()

    SequentialAnimation {
        id: anim
        running: root.overflow
        loops: Animation.Infinite
        PauseAnimation { duration: root.pauseMs }
        NumberAnimation {
            target: textEl
            property: "x"
            from: 0
            to: -root.scrollRange - root.gap
            duration: Math.max(800, (root.scrollRange + root.gap) / 40 * 1000)
            easing.type: Easing.Linear
        }
        PauseAnimation { duration: root.pauseMs * 0.7 }
        NumberAnimation {
            target: textEl
            property: "x"
            from: -root.scrollRange - root.gap
            to: 0
            duration: 350
            easing.type: Easing.InOutQuad
        }
    }
}