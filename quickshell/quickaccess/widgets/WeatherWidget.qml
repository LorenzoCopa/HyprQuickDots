pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../config"
import "WidgetShell.qml"

// Clima: open-meteo (gratis, sin API key). Resuelve la ubicación por IP
// (ipwho.is) y consulta la previsión actual. Muestra icono según el código
// de tiempo, temperatura, sensación y humedad.
WidgetShell {
    id: weatherWidget
    title: "Clima"

    // Solo consulta mientras el panel está visible (`panelActive` lo inyecta
    // QuickAccess.qml): fetch inmediato al abrir SOLO si los datos tienen
    // más de 15 min, y refresco periódico cada 15 min mientras siga abierto.
    property bool panelActive: false

    property string location: ""
    property string temp: "--"
    property string feels: "--"
    property int humidity: -1
    property string icon: "\uDB81\uDD95"
    property real lastFetchMs: 0

    // ── Resolver ubicación por IP ──
    Process {
        id: geoProc
        command: ["curl", "-s", "--max-time", "6", "https://ipwho.is/"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    const city = d.city || d.region || "";
                    weatherWidget.location = city;
                    if (d.latitude && d.longitude)
                        weatherProc.command = [
                            "curl", "-s", "--max-time", "8",
                            "https://api.open-meteo.com/v1/forecast?latitude=" + d.latitude +
                            "&longitude=" + d.longitude +
                            "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code"];
                    weatherProc.running = false;
                    weatherProc.running = true;
                } catch (e) {
                    weatherWidget.temp = "--";
                }
            }
        }
    }

    // ── Previsión actual ──
    Process {
        id: weatherProc
        command: ["curl", "-s", "--max-time", "8", ""]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    const c = d.current;
                    if (!c) return;
                    weatherWidget.lastFetchMs = Date.now();
                    weatherWidget.temp = Math.round(c.temperature_2m) + "°";
                    weatherWidget.feels = Math.round(c.apparent_temperature) + "°";
                    weatherWidget.humidity = c.relative_humidity_2m;
                    weatherWidget.icon = weatherWidget.iconForCode(c.weather_code);
                } catch (e) {
                    weatherWidget.temp = "--";
                }
            }
        }
    }

    Timer {
        id: weatherTimer
        interval: 15 * 60 * 1000
        running: weatherWidget.panelActive
        repeat: true
        onTriggered: {
            geoProc.running = false;
            geoProc.running = true;
        }
    }
    onPanelActiveChanged: {
        if (!panelActive) return;
        // Al abrir: refresca solo si pasaron ya 15 min desde la última
        // consulta (evita un fetch por cada apertura). El reinicio del timer
        // reancla el ciclo de 15 min desde ahora y el fetch se lanza YA.
        if (lastFetchMs <= 0 || Date.now() - lastFetchMs > 15 * 60 * 1000) {
            weatherTimer.restart();
            geoProc.running = false;
            geoProc.running = true;
        }
    }

    // Mapea el WMO weather_code a un glifo Nerd Font de clima (MDI,
    // codepoints U+F0590-U+F0599 que sí existen en "Symbols Nerd Font").
    function iconForCode(code: int): string {
        if (code === 0) return "\uDB81\uDD99"; // md-weather_sunny (despejado)
        if (code <= 2) return "\uDB81\uDD95";  // md-weather_partly_cloudy
        if (code <= 3) return "\uDB81\uDD90";  // md-weather_cloudy
        if (code <= 48) return "\uDB81\uDD91"; // md-weather_fog
        if (code <= 67) return "\uDB81\uDD97"; // md-weather_rainy
        if (code <= 82) return "\uDB81\uDD96"; // md-weather_pouring
        if (code <= 86) return "\uDB81\uDD98"; // md-weather_snowy
        if (code <= 99) return "\uDB81\uDD93"; // md-weather_lightning
        return "\uDB81\uDD95";
    }

    // Cuadro compacto: icono + temp/sensación + ubicación en dos líneas,
    // sin estirar la ciudad hasta el borde (el wrapper en QuickAccess le
    // da la mitad de ancho de la columna).
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        SymbolicIcon {
            path: weatherWidget.icon
            color: Settings.accent
            implicitSize: 28
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    text: weatherWidget.temp
                    color: Settings.fg
                    font.family: Settings.fontFamily
                    font.pixelSize: 18
                    font.weight: Font.Bold
                }
                Text {
                    text: "s/ " + weatherWidget.feels
                    color: Settings.muted
                    font.family: Settings.fontFamily
                    font.pixelSize: 10
                }
            }

            Text {
                Layout.fillWidth: true
                text: weatherWidget.location
                  + (weatherWidget.humidity >= 0 ? "  ·  " + weatherWidget.humidity + "%" : "")
                color: Settings.muted
                font.family: Settings.fontFamily
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
    }
}