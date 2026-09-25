// ─── Sección de atajos de teclado ─────────────────────────────────────
// Lista LOS BINDS REALES de Hyprland, no una copia. La fuente es
// hypr/modules/shortcuts.lua: cada bind registrado con `shortcuts.bind()`
// se vuelca a shortcuts.json en cada `hyprctl reload`, y esta sección
// muestra ese JSON (con watchChanges, se refresca solo al recargar).
//
// El buscador filtra por descripción, combinación o categoría ("zoom",
// "SUPER", "captura"...). Con búsqueda vacía se muestra todo agrupado por
// categorías. Cada combinación se pinta como chips estilo tecla; el botón
// "Recargar" re-ejecuta hyprctl reload para regenerar el JSON tras editar
// la configuración.

pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import "../config"

Item {
    id: root

    anchors.fill: parent

    // Nombres bonitos para teclas/multimedia/ratón al pintar los chips.
    readonly property var keyNames: ({
        "SUPER": "SUPER", "CTRL": "CTRL", "SHIFT": "SHIFT", "ALT": "ALT",
        "RETURN": "Enter", "SPACE": "Espacio", "GRAVE": "`", "COMMA": ",",
        "PRINT": "PrtSc", "LEFT": "←", "RIGHT": "→", "UP": "↑", "DOWN": "↓",
        "mouse:272": "Click izq.", "mouse:273": "Click der.",
        "mouse_down": "Rueda ↓", "mouse_up": "Rueda ↑",
        "XF86AudioRaiseVolume": "Vol +", "XF86AudioLowerVolume": "Vol −",
        "XF86AudioMute": "Silenciar", "XF86AudioMicMute": "Mic silencio",
        "XF86MonBrightnessUp": "Brillo +", "XF86MonBrightnessDown": "Brillo −",
        "XF86AudioNext": "Siguiente", "XF86AudioPrev": "Anterior",
        "XF86AudioPlay": "Play", "XF86AudioPause": "Play/Pausa",
    })

    // Parte una combinación en chips ("SUPER + SHIFT + CTRL + Print" → 4).
    // Las teclas XF86* y los nombres completos quedan como un único chip.
    function chipTexts(keys: string): var {
        const t = (keys || "").trim();
        if (t === "")
            return [];
        if (t.indexOf("XF86") === 0 || t.indexOf(" ") === -1)
            return [keyNames[t] || t];
        return t.split(" + ").map(k => keyNames[k] || k);
    }

    // Coincidencia de búsqueda (descripción, combinación o categoría).
    function matches(it: var, q: string): bool {
        if (q === "")
            return true;
        const needle = q.toLowerCase();
        const parts = [it.desc, it.keys, it.cat].concat(root.chipTexts(it.keys));
        const hay = parts.join(" ").toLowerCase();
        return hay.indexOf(needle) !== -1;
    }

    // Orden de las categorías en la lista (las desconocidas van al final).
    readonly property var catOrder: [
        "General", "Ventanas", "Navegación", "Escritorios", "Sistema",
        "Quickshell", "Capturas", "Zoom", "Gestos", "Otros",
    ]

    // Filas planas para el Repeater: cabecera de categoría + entradas.
    function buildRows(): var {
        const items = shortcutsData.items || [];
        const q = searchInput.text.trim();
        const matched = items.filter(it => root.matches(it, q));

        const groups = {};
        matched.forEach(it => {
            (groups[it.cat] = groups[it.cat] || []).push(it);
        });

        const cats = root.catOrder.filter(c => groups[c] && groups[c].length);
        Object.keys(groups).forEach(c => {
            if (cats.indexOf(c) === -1) cats.push(c);
        });

        const rows = [];
        cats.forEach(c => {
            rows.push({ type: "header", title: c, n: groups[c].length });
            groups[c].forEach(it =>
                rows.push({ type: "entry", keys: it.keys, desc: it.desc, chips: root.chipTexts(it.keys) })
            );
        });
        return rows;
    }

    readonly property var rows: root.buildRows()
    readonly property bool empty: (shortcutsData.items || []).length === 0

    // ── Datos: shortcuts.json, generado por Hyprland (modules/shortcuts.lua) ──
    FileView {
        id: shortcutsFile
        path: Qt.resolvedUrl("../shortcuts.json")
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: shortcutsData
            property var items: []
        }
    }

    // Recarga la config de Hyprland: regenere shortcuts.json y el FileView
    // (watchChanges) lo re-lee solo. Sin forks mientras no se pulse.
    Process {
        id: reloadProc
        command: ["hyprctl", "reload"]
        running: false
    }

    // ── Título + subtítulo ────────────────────────────────────
    Text {
        id: titleText
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        text: "Atajos de teclado"
        color: Settings.fg
        font.family: Settings.fontFamily
        font.pixelSize: 15
        font.weight: Font.Bold
    }

    Text {
        id: subtitleText
        anchors.top: titleText.bottom
        anchors.topMargin: 2
        anchors.left: parent.left
        anchors.right: parent.right
        text: "Los atajos activos de Hyprland, agrupados y buscables. Se regeneran con cada `hyprctl reload`."
        color: Settings.subtext0
        font.family: Settings.fontFamily
        font.pixelSize: 11
        wrapMode: Text.WordWrap
    }

    // ── Buscador + botón de recarga ─────────────────────────────
    Rectangle {
        id: searchBg
        anchors.top: subtitleText.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        height: 32
        radius: 9
        color: Settings.surface
        border {
            width: 1
            color: Settings.selectionBg
        }

        SymbolicIcon {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            path: Icons.search
            color: Settings.subtext0
            implicitSize: 15
        }

        Text {
            anchors.fill: parent
            anchors.leftMargin: 32
            anchors.rightMargin: 8
            verticalAlignment: Text.AlignVCenter
            color: Settings.muted
            font.family: Settings.fontFamily
            font.pixelSize: 12
            text: "Buscar atajos (p. ej. zoom)..."
            visible: searchInput.text.length === 0
        }

        TextInput {
            id: searchInput
            anchors.fill: parent
            anchors.leftMargin: 32
            anchors.rightMargin: loadBtn.width + 12
            verticalAlignment: TextInput.AlignVCenter
            color: Settings.fg
            font.family: Settings.fontFamily
            font.pixelSize: 12

            Keys.onEscapePressed: searchInput.text = ""
        }

        Rectangle {
            id: loadBtn
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: 4
            width: 24
            radius: 6
            color: reloadProc.running ? Settings.selectionBg : "transparent"

            SymbolicIcon {
                anchors.centerIn: parent
                path: Icons.refresh
                color: Settings.subtext0
                implicitSize: 14
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: reloadProc.running = true
            }
        }
    }

    // ── Lista (agrupada por categorías, scrolleable) ────────────
    Rectangle {
        id: listBg
        anchors.top: searchBg.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 8
        color: "transparent"
        clip: true

        Flickable {
            id: listFlick
            anchors.fill: parent
            contentWidth: width
            contentHeight: listCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: listCol
                width: listFlick.width
                spacing: 2

                Repeater {
                    model: root.rows

                    delegate: Item {
                        required property var modelData

                        width: listCol.width
                        height: {
                            if (modelData.type === "header")
                                return 26;
                            // chips de 18px + desc: la fila saca su alto de los chips
                            return Math.max(22, 18 + 6);
                        }

                        // ── Cabecera de categoría ──────────────
                        Text {
                            visible: modelData.type === "header"
                            anchors.fill: parent
                            anchors.leftMargin: 4
                            anchors.rightMargin: 4
                            verticalAlignment: Text.AlignBottom
                            color: Settings.muted
                            font.family: Settings.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            text: modelData.type === "header" ? modelData.title + "  (" + modelData.n + ")" : ""
                        }

                        // ── Fila de atajo ───────────────────────
                        Row {
                            id: chipsRow
                            visible: modelData.type === "entry"
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Repeater {
                                model: modelData.type === "entry" ? modelData.chips : []

                                delegate: Rectangle {
                                    required property var modelData
                                    property string chipText: modelData

                                    height: 18
                                    width: chipLabel.implicitWidth + 10
                                    radius: 5
                                    color: Settings.surface

                                    Text {
                                        id: chipLabel
                                        anchors.centerIn: parent
                                        text: parent.chipText
                                        color: Settings.fg
                                        font.family: Settings.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                    }
                                }
                            }
                        }

                        Text {
                            id: descText
                            visible: modelData.type === "entry"
                            anchors.left: parent.left
                            anchors.right: chipsRow.left
                            anchors.leftMargin: 4
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.type === "entry" ? modelData.desc : ""
                            color: Settings.fg
                            font.family: Settings.fontFamily
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        }

        // ── Estados vacíos ─────────────────────────────────────
        Text {
            anchors.centerIn: parent
            visible: root.rows.length === 0
            text: root.empty
                ? "La lista se genera desde Hyprland. Pulsa el icono de recarga (o ejecuta `hyprctl reload`)."
                : "Sin coincidencias."
            color: Settings.muted
            font.family: Settings.fontFamily
            font.pixelSize: 12
            width: parent.width - 24
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }
}