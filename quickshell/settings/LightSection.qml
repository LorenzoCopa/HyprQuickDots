// ─── Sección de luz nocturna ───────────────────────────────────────────
// Activa/desactiva la luz nocturna (hyprsunset) y ajusta la temperatura
// de color (1000-6500K). A diferencia de Barra/Suspensión, aquí NO hay
// botón "Aplicar": todo es en vivo. El toggle enciende/apaga al instante y
// el slider muestra el resultado mientras se desliza (para calibrar); al
// soltar se persiste. La gestión real (hyprsunset + nightstate.json) la
// hace shell.qml (Settings.applyNightLight / Settings.previewNightLightTemp).

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../config"

Item {
    id: root

    anchors.fill: parent

    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 10

        Text {
            text: "Luz nocturna"
            color: Settings.fg
            font.family: Settings.fontFamily
            font.pixelSize: 15
            font.weight: Font.Bold
        }

        Text {
            text: "Reduce la luz azul de la pantalla para las horas de la noche. Todo se aplica al instante: enciéndela y ajusta el deslizador hasta que te guste cómo queda."
            color: Settings.subtext0
            font.family: Settings.fontFamily
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            width: parent.width
        }

        // ── Activar / desactivar ─────────────────────────
        Row {
            width: parent.width
            spacing: 8

            Rectangle {
                id: toggleBg
                width: 40
                height: 22
                radius: 11
                color: Settings.nightLightEnabled ? Settings.green : Settings.surface
                Behavior on color { ColorAnimation { duration: 80 } }

                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    color: Settings.bg
                    anchors.verticalCenter: parent.verticalCenter
                    x: Settings.nightLightEnabled ? parent.width - width - 3 : 3
                    Behavior on x { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Settings.nightLightEnabled = !Settings.nightLightEnabled;
                        if (Settings.applyNightLight)
                            Settings.applyNightLight();
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Settings.nightLightEnabled ? "Encendido" : "Apagado"
                color: Settings.nightLightEnabled ? Settings.green : Settings.subtext0
                font.family: Settings.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }

        // ── Temperatura ──────────────────────────────────
        Text {
            text: "Temperatura"
            color: Settings.subtext0
            font.family: Settings.fontFamily
            font.pixelSize: 11
            font.weight: Font.Bold
        }

        Slider {
            id: tempSlider
            width: parent.width
            from: 1000
            to: 6500
            stepSize: 100
            value: Settings.nightLightTemp
            onMoved: {
                Settings.nightLightTemp = value;
                // Preview en vivo mientras se desliza: solo tiene efecto
                // si la luz nocturna está encendida.
                if (Settings.previewNightLightTemp)
                    Settings.previewNightLightTemp(value);
            }
            onPressedChanged: {
                // Al soltar, persistir la temperatura elegida.
                if (!pressed && Settings.applyNightLight)
                    Settings.applyNightLight();
            }

            background: Rectangle {
                x: tempSlider.leftPadding
                y: tempSlider.topPadding + tempSlider.availableHeight / 2 - height / 2
                implicitWidth: 200
                implicitHeight: 4
                width: tempSlider.availableWidth
                height: implicitHeight
                radius: 2
                color: Settings.surface

                Rectangle {
                    width: tempSlider.visualPosition * parent.width
                    height: parent.height
                    radius: 2
                    color: Settings.yellow
                }
            }

            handle: Rectangle {
                x: tempSlider.leftPadding + tempSlider.visualPosition * (tempSlider.availableWidth - width)
                y: tempSlider.topPadding + tempSlider.availableHeight / 2 - height / 2
                implicitWidth: 16
                implicitHeight: 16
                radius: 8
                color: Settings.nightLightEnabled ? Settings.yellow : Settings.selectionBg
                border {
                    width: 2
                    color: Settings.bg
                }
            }
        }

        Row {
            width: parent.width

            Text {
                text: "1000K"
                color: Settings.subtext0
                font.family: Settings.fontFamily
                font.pixelSize: 9
                width: parent.width / 2
            }

            Text {
                text: "6500K"
                color: Settings.subtext0
                font.family: Settings.fontFamily
                font.pixelSize: 9
                width: parent.width / 2
                horizontalAlignment: Text.AlignRight
            }
        }

        Text {
            text: Settings.nightLightTemp + "K"
            color: Settings.fg
            font.family: Settings.fontFamily
            font.pixelSize: 13
            font.weight: Font.Bold
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: "Nota: 6500K es luz neutra (sin filtro); cuanto más baja, más cálida la pantalla."
            color: Settings.subtext0
            font.family: Settings.fontFamily
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            width: parent.width
        }
    }
}
