// ─── Navegador de aplicaciones por categorías (rejilla) ──────────
// Ventana flotante con una barra de búsqueda, unas pocas categorías
// curadas en chips (Todas/Internet/Oficina/Multimedia/Juegos/Sistema/
// Desarrollo/Otros) y una vista de cuadrícula con el icono y el nombre
// de cada app. Cada app se asigna a una categoría según las categorías
// XDG de su .desktop (mapeo hacia las curadas). No tiene atajo propio:
// solo se abre desde el launcher (buscando "Aplicaciones") o vía IPC
// `qs ipc call appbrowser toggle`.

pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../config"

// ─── Ventana flotante del navegador ─────────────────────────────
FloatingWindow {
    id: appBrowser
    color: "transparent"
    implicitWidth: 880
    implicitHeight: 680
    title: "qs-appbrowser"
    visible: false

    // ── Categoría seleccionada ──────────────────────────────────
    property string selectedCategory: "Todas"

    // ── Búsqueda actual ─────────────────────────────────────────
    property string searchText: ""

    // ── Categorías curadas (orden de los chips) ─────────────────
    readonly property var curatedCategories: [
        "Todas", "Internet", "Oficina", "Multimedia",
        "Juegos", "Sistema", "Desarrollo", "Otros"
    ]

    // ── Asigna una app a una categoría curada según sus XDG ─────
    function curatedFor(app): string {
        const cats = (app.categories || []).map(c => c.toLowerCase());
        const has = (...words) => words.some(w => cats.includes(w.toLowerCase()));

        if (has("network", "webbrowser", "web", "chat", "email", "instantmessaging",
                 "news", "feed", "p2p", "remoteaccess", "videochat", "browser"))
            return "Internet";
        if (has("office", "spreadsheet", "wordprocessor", "presentation", "calculator",
                 "finance", "calendar", "pim", "database", "documentviewer", "pdf"))
            return "Oficina";
        if (has("audio", "video", "music", "player", "recorder", "photography",
                 "graphics", "viewer", "media", "audioediting", "videoediting", "tv"))
            return "Multimedia";
        if (has("game", "actiongame", "adventuregame", "arcadegame", "boardgame",
                 "cardgame", "simulation", "roleplaying", "sportsgame", "strategygame",
                 "puzzlegame", "amusement"))
            return "Juegos";
        if (has("system", "utility", "settings", "monitor", "security",
                 "terminalemulator", "filemanager", "core", "archiving", "accessibility"))
            return "Sistema";
        if (has("development", "ide", "texteditor", "building", "debugger",
                 "revisioncontrol", "computerscience", "profiling", "packaging"))
            return "Desarrollo";
        return "Otros";
    }

    // ── Comunicación IPC: activa/desactiva el navegador ─────────
    IpcHandler {
        target: "appbrowser"
        function toggle(): void {
            if (!appBrowser.visible) {
                appBrowser.selectedCategory = "Todas";
                appBrowser.searchText = "";
                appBrowser.visible = true;
                Qt.callLater(() => searchInput.forceActiveFocus());
            } else {
                appBrowser.visible = false;
            }
        }
        function hide(): void { appBrowser.visible = false; }
    }

    // ── Sin FocusGrab: la ventana vive en el mosaico como una app
    // cualquiera; no se cierra al perder el foco (ESC, ✕ o SUPER+X).

    // Sobre un juego fullscreen el foco inicial puede quedarse en el juego
    // (constraint del puntero); pedirlo por dispatcher rompe el bloqueo.
    SelfFocus {
        targetTitle: "qs-appbrowser"
        active: appBrowser.visible
    }

    // El preview de captura se pinnea por encima (juegos fullscreen); al abrir
    // el navegador lo bajamos y lo volvemos a pinner al cerrar.
    onVisibleChanged: {
        if (appBrowser.visible) {
            if (Settings.screenshotManager) Settings.screenshotManager.suspendPin();
        } else {
            if (Settings.screenshotManager) Settings.screenshotManager.resumePin();
        }
    }

    // ── Lanza la app del índice dado SIN cerrar el navegador ────
    function launchIndex(idx: int): void {
        const entry = gridModel.values[idx];
        if (entry)
            entry.execute();
    }

    // ─── Fondo (esquinas rectas: la ventana va en mosaico) ────
    Rectangle {
        anchors.fill: parent
        color: Settings.bg
        radius: 0

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── Título + buscador + cerrar ───────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Aplicaciones"
                    color: Settings.fg
                    font.family: Settings.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: 16
                }

                // ── Barra de búsqueda ─────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    radius: 9
                    color: Settings.surface
                    border {
                        width: 1
                        color: searchInput.activeFocus ? Settings.accent : "transparent"
                    }

                    SymbolicIcon {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        path: Icons.search
                        color: Settings.subtext0
                        implicitSize: 14
                    }

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        anchors.leftMargin: 30
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        color: Settings.fg
                        font.family: Settings.fontFamily
                        font.pixelSize: 13
                        text: appBrowser.searchText
                        onTextChanged: appBrowser.searchText = searchInput.text

                        Keys.onEscapePressed: appBrowser.visible = false
                        Keys.onReturnPressed: {
                            const idx = grid.currentIndex;
                            if (idx >= 0)
                                appBrowser.launchIndex(idx);
                        }
                        Keys.onUpPressed: grid.moveCurrentIndexUp()
                        Keys.onDownPressed: grid.moveCurrentIndexDown()
                        Keys.onLeftPressed: grid.moveCurrentIndexLeft()
                        Keys.onRightPressed: grid.moveCurrentIndexRight()
                        Keys.onPressed: event => {
                            if (event.modifiers & Qt.ControlModifier) {
                                if (event.key === Qt.Key_P) {
                                    grid.moveCurrentIndexUp();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_N) {
                                    grid.moveCurrentIndexDown();
                                    event.accepted = true;
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: 6
                    color: Settings.surface

                    Text {
                        anchors.centerIn: parent
                        text: "\u2715"   // ✕ cerrar
                        color: Settings.subtext0
                        font.pixelSize: 12
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: appBrowser.visible = false
                    }
                }
            }

            // ── Chips de categorías (scroll horizontal) ──────────
            Rectangle {
                id: chipViewport
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                clip: true
                color: "transparent"

                Flickable {
                    id: chipFlick
                    anchors.fill: parent
                    contentWidth: chipRow.implicitWidth
                    contentHeight: chipViewport.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickDeceleration: 4000

                    // Rueda del ratón => scroll horizontal
                    WheelHandler {
                        onWheel: event => {
                            if (chipFlick.contentWidth > chipFlick.width) {
                                const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                                chipFlick.contentX = Math.max(0, Math.min(chipFlick.contentWidth - chipFlick.width, chipFlick.contentX - delta));
                                event.accepted = true;
                            }
                        }
                    }

                    Row {
                        id: chipRow
                        spacing: 6

                        Repeater {
                            model: appBrowser.curatedCategories

                            delegate: Rectangle {
                                id: chipDelegate
                                required property string modelData

                                width: chipText.implicitWidth + 28
                                height: 26
                                radius: 13
                                color: appBrowser.selectedCategory === chipDelegate.modelData ? Settings.accent : Settings.surface

                                Text {
                                    id: chipText
                                    anchors.centerIn: parent
                                    text: chipDelegate.modelData
                                    // Chip seleccionado = fondo accent: la letra
                                    // pasa a oscura para seguir siendo legible.
                                    color: appBrowser.selectedCategory === chipDelegate.modelData ? Settings.bg : Settings.fg
                                    font.family: Settings.fontFamily
                                    font.weight: Font.DemiBold
                                    font.pixelSize: 12
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: appBrowser.selectedCategory = chipDelegate.modelData
                                }
                            }
                        }
                    }
                }

                // ── Barra de scroll horizontal ─────────────────────
                ScrollBar {
                    id: chipBar
                    orientation: Qt.Horizontal
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 4
                    policy: chipFlick.contentWidth > chipFlick.width ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                    size: chipFlick.contentWidth > 0 ? chipFlick.width / chipFlick.contentWidth : 1
                    position: chipFlick.contentWidth > chipFlick.width
                              ? chipFlick.contentX / (chipFlick.contentWidth - chipFlick.width)
                              : 0
                }
            }

            // ── Contador de apps de la categoría + búsqueda ──────
            Text {
                Layout.fillWidth: true
                text: {
                    if (appBrowser.searchText !== "")
                        return grid.count + " resultados para \u201C" + appBrowser.searchText + "\u201D";
                    return grid.count + " aplicación" + (grid.count === 1 ? "" : "es");
                }
                color: Settings.subtext0
                font.family: Settings.fontFamily
                font.weight: Font.Normal
                font.pixelSize: 12
            }

            // ── Contenedor con foco para navegar la rejilla ───────
            FocusScope {
                id: gridFocus
                Layout.fillWidth: true
                Layout.fillHeight: true
                focus: appBrowser.visible

                Keys.onEscapePressed: appBrowser.visible = false
                Keys.onReturnPressed: {
                    const idx = grid.currentIndex;
                    if (idx >= 0)
                        appBrowser.launchIndex(idx);
                }
                Keys.onUpPressed: grid.moveCurrentIndexUp()
                Keys.onDownPressed: grid.moveCurrentIndexDown()
                Keys.onLeftPressed: grid.moveCurrentIndexLeft()
                Keys.onRightPressed: grid.moveCurrentIndexRight()
                Keys.onPressed: event => {
                    if (event.modifiers & Qt.ControlModifier) {
                        if (event.key === Qt.Key_P) {
                            grid.moveCurrentIndexUp();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_N) {
                            grid.moveCurrentIndexDown();
                            event.accepted = true;
                        }
                    }
                }

                // ── Rejilla de apps ──────────────────────────────
                GridView {
                    id: grid
                    anchors.fill: parent
                    clip: true
                    // El nº de columnas se calcula según el ancho real y el
                    // sobrante se reparte entre las celdas: así la rejilla
                    // cierra justa a la derecha (con cellWidth fijo de 96
                    // quedaba una columna vacía de ~88px al final).
                    readonly property int columns: Math.max(1, Math.floor(width / 96))
                    cellWidth: Math.floor(width / columns)
                    cellHeight: 92
                    boundsBehavior: Flickable.StopAtBounds

                    model: ScriptModel {
                        id: gridModel
                        objectProp: "id"
                        values: {
                            const q = appBrowser.searchText.toLowerCase();
                            const cat = appBrowser.selectedCategory;
                            const all = DesktopEntries.applications.values;
                            return all.filter(app => {
                                if (cat !== "Todas" && appBrowser.curatedFor(app) !== cat)
                                    return false;
                                if (q === "")
                                    return true;
                                return (app.name || "").toLowerCase().includes(q)
                                    || (app.genericName || "").toLowerCase().includes(q)
                                    || (app.keywords || []).some(k => k.toLowerCase().includes(q));
                            });
                        }
                        onValuesChanged: grid.currentIndex = 0
                    }

                    delegate: Rectangle {
                        id: gridDelegate
                        required property int index
                        required property var modelData

                        // Sin esto el Rectangle pinta blanco por defecto
                        // y se ve un marco claro alrededor de cada celda.
                        color: "transparent"
                        width: grid.cellWidth
                        height: grid.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 3
                            radius: 12
                            color: grid.currentIndex === gridDelegate.index ? Settings.selectionBg
                                 : gridMouse.containsMouse ? Settings.surface
                                 : "transparent"
                            Behavior on color { ColorAnimation { duration: 80 } }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                width: 44
                                height: 44
                                anchors.horizontalCenter: parent.horizontalCenter
                                radius: 10
                                color: Settings.surface

                                IconImage {
                                    id: gridIcon
                                    anchors.centerIn: parent
                                    width: 28
                                    height: 28
                                    source: Quickshell.iconPath(gridDelegate.modelData.icon, true)
                                    asynchronous: true
                                }

                                SymbolicIcon {
                                    anchors.centerIn: parent
                                    path: Icons.glyphForClass(gridDelegate.modelData.name)
                                    color: Settings.accent
                                    implicitSize: 18
                                    visible: gridIcon.status !== Image.Ready
                                }
                            }

                            Text {
                                width: grid.cellWidth - 14
                                horizontalAlignment: Text.AlignHCenter
                                text: gridDelegate.modelData.name
                                color: Settings.fg
                                font.family: Settings.fontFamily
                                font.weight: Font.Medium
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }

                        MouseArea {
                            id: gridMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: grid.currentIndex = gridDelegate.index
                            onClicked: appBrowser.launchIndex(gridDelegate.index)
                        }
                    }
                }
            }
        }
    }
}