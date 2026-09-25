// ─── Sección de aplicaciones ──────────────────────────────────────────
// Dos bloques:
//  1) Predeterminadas: qué app abre cada tipo de contenido (navegador,
//     imágenes, video...). Escribe en ~/.config/mimeapps.list vía
//     `xdg-mime default`, el mecanismo estándar que consultan todas las
//     apps (no es cosa de Hyprland). Se aplica al instante, sin "Aplicar".
//  2) Autoinicio: entradas XDG de ~/.config/autostart/*.desktop. El
//     listado/toggle/añadir/borrar gestiona esos ficheros; Hyprland los
//     lanza con `systemctl --user start xdg-desktop-autostart.target`
//     (exec-once en hyprland.lua). Cada cambio corre además
//     `systemctl --user daemon-reload`: el generador xdg-autostart solo
//     re-lee los .desktop en login/daemon-reload, sin esto una entrada
//     añadida a mitad de sesión no existiría para systemd.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../config"

Item {
    id: root

    anchors.fill: parent

    // ── Estado ────────────────────────────────────────────────
    property var allApps: []        // {id, name, icon, mime} instaladas
    property var autostartApps: []  // {id, name, icon, hidden}
    property var defaultsMap: ({})  // categoryId -> desktop id ("")

    // Candidatos del buscador de autoinicio: coinciden con lo escrito en
    // addSearch (se lee directo del TextInput para que el binding re-
    // evalúe en cada tecla; NUNCA una copia desincronizada). Las que YA
    // están en la lista aparecen IGUAL pero marcadas (added) con un ✓:
    // así un resultado nunca queda a dudas entre "no existe" y "ya está".
    function addCandidates(): var {
        const q = addSearch.text.trim().toLowerCase();
        if (q === "")
            return [];
        return allApps
            .filter(a =>
                (a.name || "").toLowerCase().indexOf(q) !== -1 ||
                a.id.toLowerCase().indexOf(q) !== -1)
            .slice(0, 6)
            .map(a => Object.assign({}, a, {
                added: autostartApps.some(e => e.id === a.id)
            }));
    }

    // Categoría → mimes representativos. La primera mime es la que se
    // consulta para mostrar el valor actual. "terminal" no usa mimes:
    // sus candidatos son las apps con Categories=TerminalEmulator y el
    // valor se guarda en ~/.config/xdg-terminals.list (especificación
    // freedesktop que consume xdg-terminal-exec; Hyprland también la lee
    // para el bind SUPER+RETURN).
    readonly property var categories: [
        { id: "browser",  label: "Navegador",          mimes: ["text/html", "x-scheme-handler/http", "x-scheme-handler/https"] },
        { id: "files",    label: "Gestor de archivos", mimes: ["inode/directory"] },
        { id: "image",    label: "Imágenes",           mimes: ["image/png", "image/jpeg", "image/gif", "image/webp"] },
        { id: "video",    label: "Video",              mimes: ["video/mp4", "video/x-matroska", "video/webm"] },
        { id: "audio",    label: "Audio",              mimes: ["audio/mpeg", "audio/flac"] },
        { id: "text",     label: "Editor de texto",    mimes: ["text/plain"] },
        { id: "terminal", label: "Terminal",           mimes: [] },
    ]

    function candidatesFor(cat): var {
        const out = [];
        for (let i = 0; i < allApps.length; i++) {
            const a = allApps[i];
            if (cat.id === "terminal") {
                // TerminalEmulator en Categories (el estándar identifica
                // así a las terminales). El escaneo baja las categorías.
                if (a.cat && (";" + a.cat.toLowerCase() + ";").indexOf(";terminalemulator;") !== -1)
                    out.push(a);
                continue;
            }
            if (!a.mime) continue;
            const mimes = a.mime.split(";");
            for (let j = 0; j < cat.mimes.length; j++) {
                if (mimes.indexOf(cat.mimes[j]) !== -1) { out.push(a); break; }
            }
        }
        out.sort((x, y) => x.name.toLowerCase() < y.name.toLowerCase() ? -1 : 1);
        return out;
    }

    function refresh(): void {
        scanProc.running = true;
        defaultsProc.running = true;
        autostartProc.running = true;
    }

    Component.onCompleted: refresh()

    // ── Procesos ──────────────────────────────────────────────
    // Escanea los .desktop del sistema (dirs de usuario primero: ganan).
    Process {
        id: scanProc
        command: ["bash", "-c",
            'for d in "$HOME/.local/share/applications" "/usr/local/share/applications" "/usr/share/applications"; do\n' +
            '  [ -d "$d" ] || continue\n' +
            '  for f in "$d"/*.desktop; do\n' +
            '    [ -f "$f" ] || continue\n' +
            "    awk -F= '\n" +
            "      /^\\[/ { ing = ($0 == \"[Desktop Entry]\") }\n" +
            "      ing && /^Name=/      { if (n == \"\") n = $2 }\n" +
            "      ing && /^Icon=/      { i = $2 }\n" +
            "      ing && /^MimeType=/  { m = $2 }\n" +
            "      ing && /^Categories=/{ c = $2 }\n" +
            // Exec completo (puede contener "=" en env vars), no solo $2
            "      ing && /^Exec=/      { if (e == \"\") { e = $0; sub(/^[^=]*=/, \"\", e) } }\n" +
            "      ing && /^Hidden=/    { h = $2 }\n" +
            "      ing && /^NoDisplay=/{ nd = $2 }\n" +
            "      END {\n" +
            "        if (h == \"true\" || nd == \"true\") exit\n" +
            "        id = FILENAME; sub(/.*\\//, \"\", id); sub(/\\.desktop$/, \"\", id)\n" +
            "        printf \"%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n\", id, n, i, m, e, c\n" +
            "      }' \"$f\"\n" +
            '  done\n' +
            'done']
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                const seen = {};
                // Sin trim() por línea cruda: el último campo vacío
                // (Categories/Mime ausentes) es legítimo, no basura.
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    if (lines[i].trim() === "") continue;
                    const p = lines[i].split("\t");
                    if (p.length < 5 || seen[p[0]]) continue;
                    seen[p[0]] = true;
                    out.push({ id: p[0], name: p[1] || p[0], icon: p[2] || "", mime: p[3] || "", exec: p[4] || "", cat: p[5] || "" });
                }
                out.sort((x, y) => x.name.toLowerCase() < y.name.toLowerCase() ? -1 : 1);
                root.allApps = out;
            }
        }
    }

    // Valor actual de cada categoría según xdg-mime (fuente real). Para
    // "terminal" se lee ~/.config/xdg-terminals.list (primera línea que
    // sea un ID, ignorando comentarios/directivas).
    Process {
        id: defaultsProc
        command: ["bash", "-c",
            'for m in text/html inode/directory image/png video/mp4 audio/mpeg text/plain; do\n' +
            '  printf \'%s\\t%s\\n\' "$m" "$(xdg-mime query default "$m" 2>/dev/null)"\n' +
            'done\n' +
            'printf \'%s\\t%s\\n\' "terminal" "$(grep -m1 -E \'^[a-zA-Z0-9]\' "$HOME/.config/xdg-terminals.list" 2>/dev/null | tr -d \'[:space:]\')"']
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const d = {};
                const cats = root.categories;
                const lines = text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const p = lines[i].split("\t");
                    if (p.length < 2) continue;
                    if (p[0] === "terminal") {
                        d["terminal"] = (p[1] || "").replace(/\.desktop$/, "");
                        continue;
                    }
                    for (let j = 0; j < cats.length; j++) {
                        if (cats[j].mimes[0] === p[0]) {
                            // OJO: xdg-mime responde "app.desktop" y nuestro
                            // escaneo usa ids SIN extensión; normalizar o el
                            // combo muestra "Sin definir" aunque sí esté aplicado.
                            d[cats[j].id] = (p[1] || "").replace(/\.desktop$/, "");
                            break;
                        }
                    }
                }
                root.defaultsMap = d;
            }
        }
    }

    // Aplica una elección. El comando se construye aquí (no como binding)
    // porque depende de la categoría y app elegidas en el momento.
    Process {
        id: setProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: defaultsProc.running = true
        }
    }

    function setDefault(cat, appId): void {
        // Terminal: escribe ~/.config/xdg-terminals.list (formato del
        // estándar xdg-terminal-exec: el ID CON extensión) y recarga
        // Hyprland para que SUPER+RETURN apunte a la nueva terminal.
        if (cat.id === "terminal") {
            const dt = Object.assign({}, defaultsMap);
            dt["terminal"] = appId;
            defaultsMap = dt;
            setProc.command = ["bash", "-c",
                'printf "%s\\n" "' + appId + '.desktop" > "$HOME/.config/xdg-terminals.list"\n' +
                'hyprctl reload >/dev/null 2>&1 || true'];
            setProc.running = true;
            return;
        }
        const d = Object.assign({}, defaultsMap);
        d[cat.id] = appId;
        defaultsMap = d;
        // OJO: xdg-mime exige el id CON extensión ("nvim.desktop"); con el
        // id recortado falla ("malformed argument, expected *.desktop") y
        // el re-query devuelve el fallback, pareciendo que "revierte".
        // El escaneo guarda ids sin extensión y la query los normaliza de
        // vuelta, así que aquí se recompone.
        setProc.command = ["xdg-mime", "default", appId + ".desktop"].concat(cat.mimes);
        setProc.running = true;
    }

    // Lista ~/.config/autostart/*.desktop con su estado Hidden.
    Process {
        id: autostartProc
        command: ["bash", "-c",
            'for f in "$HOME/.config/autostart"/*.desktop; do\n' +
            '  [ -f "$f" ] || continue\n' +
            "    awk -F= '\n" +
            "      /^\\[/ { ing = ($0 == \"[Desktop Entry]\") }\n" +
            "      ing && /^Name=/   { if (n == \"\") n = $2 }\n" +
            "      ing && /^Icon=/   { i = $2 }\n" +
            "      ing && /^Exec=/   { e = $2 }\n" +
            "      ing && /^Hidden=/{ h = $2 }\n" +
            "      END {\n" +
            "        id = FILENAME; sub(/.*\\//, \"\", id); sub(/\\.desktop$/, \"\", id)\n" +
            "        printf \"%s\\t%s\\t%s\\t%s\\t%s\\n\", id, n, i, e, h\n" +
            "      }' \"$f\"\n" +
            'done']
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                // OJO: NO text.trim(): sin campo Hidden la línea acaba en
                // \t y trim() dejaba 4 campos => el length<5 descartaba
                // TODA entrada añadida por esta UI (lista siempre vacía).
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    if (lines[i].trim() === "") continue;
                    const p = lines[i].split("\t");
                    if (p.length < 5) continue;
                    out.push({ id: p[0], name: p[1] || p[0], icon: p[2] || "", hidden: p[4] === "true" });
                }
                out.sort((x, y) => x.name.toLowerCase() < y.name.toLowerCase() ? -1 : 1);
                root.autostartApps = out;
            }
        }
    }

    // Activa/desactiva una entrada sin borrarla (Hidden=true/false).
    Process {
        id: toggleProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: autostartProc.running = true
        }
    }

    function setAutostartEnabled(entryId, enabled): void {
        // SOLO escribe el disco. El estado visual lo lleva el delegado con
        // su propiedad local (entry.enabledState): el remapeo optimista de
        // antes reasignaba root.autostartApps, el Repeater RECIBÍA otro
        // array y recreaba todos los delegados ya en el estado final, así
        // que la animación del switch (Behavior on x/color) nunca corría.
        const val = enabled ? "false" : "true";
        toggleProc.command = ["bash", "-c",
            'f="$HOME/.config/autostart/' + entryId + '.desktop"\n' +
            '[ -f "$f" ] || exit 0\n' +
            'if grep -q "^Hidden=" "$f"; then\n' +
            '  sed -i "s/^Hidden=.*/Hidden=' + val + '/" "$f"\n' +
            'else\n' +
            '  sed -i "/^\\[Desktop Entry\\]/a Hidden=' + val + '" "$f"\n' +
            'fi\n' +
            // Regenera las unidades app-*@autostart: systemd solo pasa el
            // generador xdg-autostart en login/daemon-reload, sin esto un
            // cambio hecho ahora no existe para systemd hasta reiniciar.
            'systemctl --user daemon-reload >/dev/null 2>&1 || true'];
        toggleProc.running = true;
    }

    // Crea una entrada nueva copiando Name/Exec/Icon de la app elegida.
    Process {
        id: addProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                addSearch.text = "";   // limpia el buscador tras añadir
                autostartProc.running = true;
            }
        }
    }

    function addAutostart(appId): void {
        let app = null;
        for (let i = 0; i < allApps.length; i++)
            if (allApps[i].id === appId) { app = allApps[i]; break; }
        if (!app) return;
        // Los códigos de campo (%f %F %u %U...) son para lanzadores de
        // escritorio; en autostart (systemd xdg-desktop-autostart) sobran y
        // se pasarían como argumentos literales ("nvim %F").
        const exec = (app.exec || "").replace(
            /(^|\s)%(f|F|u|U|d|D|n|N|i|c|k|v|m)(?=\s|$)/g, "$1").trim();
        addProc.command = ["bash", "-c",
            'printf "[Desktop Entry]\\nType=Application\\nName=%s\\nExec=%s\\nIcon=%s\\nTerminal=false\\n" "$1" "$2" "$3" > "$HOME/.config/autostart/$4.desktop"\n' +
            // daemon-reload: genera ya la unidad app-*@autostart (si no,
            // systemd ignoraría la entrada hasta el próximo login).
            'systemctl --user daemon-reload >/dev/null 2>&1 || true',
            "bash", app.name || app.id, exec, app.icon || "", app.id];
        addProc.running = true;
    }

    Process {
        id: removeProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: autostartProc.running = true
        }
    }

    function removeAutostart(entryId): void {
        removeProc.command = ["bash", "-c",
            'rm -f "$HOME/.config/autostart/' + entryId + '.desktop"\n' +
            // Sin reload systemd conservaría la unidad de una entrada borrada.
            'systemctl --user daemon-reload >/dev/null 2>&1 || true'];
        removeProc.running = true;
    }

    // ── ComboBox de apps (inline component) ───────────────────
    component AppCombo: ComboBox {
        id: combo

        property var candidates: []
        property string currentId: ""
        signal picked(string appId)

        height: 32
        model: candidates
        textRole: "name"
        currentIndex: {
            for (var i = 0; i < candidates.length; i++)
                if (candidates[i].id === currentId) return i;
            return -1;
        }
        displayText: currentIndex === -1 ? "Sin definir" : combo.currentText

        font.family: Settings.fontFamily

        onActivated: idx => picked(candidates[idx].id)

        indicator: Text {
            text: Icons.chevronDown
            color: Settings.subtext0
            font.family: Settings.iconFontFamily
            font.pixelSize: 12
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
        }

        contentItem: Text {
            leftPadding: 12
            rightPadding: 28
            verticalAlignment: Text.AlignVCenter
            text: combo.displayText
            color: combo.currentIndex === -1 ? Settings.subtext0 : Settings.fg
            font.family: Settings.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        background: Rectangle {
            radius: 8
            color: Settings.surface
            border {
                width: 1
                color: Settings.selectionBg
            }
        }

        delegate: ItemDelegate {
            id: del
            required property var model
            required property int index
            width: ListView.view.width
            height: 30
            highlighted: combo.highlightedIndex === index

            contentItem: Text {
                text: del.model[combo.textRole]
                color: del.highlighted || del.hovered ? Settings.accent : Settings.fg
                font.family: Settings.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                verticalAlignment: Text.AlignVCenter
                leftPadding: 12
                rightPadding: 12
                elide: Text.ElideRight
            }

            background: Rectangle {
                radius: 6
                color: del.highlighted || del.hovered ? Settings.selectionBg : "transparent"
            }
        }

        popup: Popup {
            y: combo.height + 4
            width: combo.width
            padding: 4

            background: Rectangle {
                radius: 10
                color: Settings.surface
                border {
                    width: 1
                    color: Settings.selectionBg
                }
            }

            contentItem: ListView {
                clip: true
                implicitHeight: Math.min(contentHeight, 240)
                model: combo.delegateModel
                currentIndex: combo.highlightedIndex
                highlightMoveDuration: 0
            }
        }
    }

    // Interruptor pequeño para las filas del autoinicio.
    // Diseño: el track DEBE verse sobre la tarjeta (#1A1A1A) en ambos
    // estados — apagado: negro con borde tenue y knob gris apagado;
    // encendido: verde de estado con knob oscuro. La zona de clic es
    // más grande que el dibujo para fallar menos al puntero.
    component MiniToggle: Rectangle {
        id: tog

        property bool checked: false
        property var requestToggle: null

        width: 40
        height: 22
        radius: 11
        color: tog.checked ? Settings.green : Settings.bg
        border.width: 1
        border.color: tog.checked ? Settings.green : Settings.selectionBg
        Behavior on color { ColorAnimation { duration: 80 } }

        Rectangle {
            width: 16
            height: 16
            radius: 8
            color: tog.checked ? Settings.bg : Settings.muted
            anchors.verticalCenter: parent.verticalCenter
            x: tog.checked ? parent.width - width - 3 : 3
            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.InOutQuad } }
        }

        MouseArea {
            anchors.centerIn: parent
            width: 48
            height: 30
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (tog.requestToggle) tog.requestToggle()
        }
    }

    // ── Contenido (con scroll: la lista puede no caber) ───────
    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
            id: col
            width: flick.width
            spacing: 10

            Text {
                text: "Aplicaciones"
                color: Settings.fg
                font.family: Settings.fontFamily
                font.pixelSize: 15
                font.weight: Font.Bold
            }

            Text {
                width: parent.width
                text: "Elige qué aplicación abre cada tipo de contenido y cuáles arrancan con el sistema. Los cambios se guardan al instante; las apps del autoinicio se lanzan en el próximo inicio de sesión."
                color: Settings.subtext0
                font.family: Settings.fontFamily
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            // ── Predeterminadas ───────────────────────────────
            Text {
                text: "Predeterminadas"
                color: Settings.subtext0
                font.family: Settings.fontFamily
                font.pixelSize: 11
                font.weight: Font.Bold
            }

            Repeater {
                model: root.categories

                delegate: Row {
                    id: catRow
                    required property var modelData

                    width: parent.width
                    height: 36
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 232
                        text: catRow.modelData.label
                        color: Settings.fg
                        font.family: Settings.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    AppCombo {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 224
                        candidates: root.candidatesFor(catRow.modelData)
                        currentId: root.defaultsMap[catRow.modelData.id] || ""
                        onPicked: appId => root.setDefault(catRow.modelData, appId)
                    }
                }
            }

            // ── Autoinicio ────────────────────────────────────
            // RowLayout: la línea separadora es flexible (Layout.fillWidth).
            // Con el ancho fijo de antes (parent.width - 200) la fila
            // desbordaba y el botón de refrescar quedaba fuera del borde.
            RowLayout {
                width: parent.width
                spacing: 8

                Text {
                    text: "Autoinicio" + (root.autostartApps.length > 0
                          ? " (" + root.autostartApps.length + ")" : "")
                    color: Settings.subtext0
                    font.family: Settings.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }

                Text {
                    text: "(~/.config/autostart)"
                    color: Settings.muted
                    font.family: Settings.fontFamily
                    font.pixelSize: 10
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Settings.surface
                }

                Rectangle {
                    id: refreshBtn
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: 6
                    color: refreshMa.containsMouse ? Settings.selectionBg : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: Icons.refresh
                        color: refreshMa.containsMouse ? Settings.accent : Settings.muted
                        font.family: Settings.iconFontFamily
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: refreshMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.refresh()
                    }
                }
            }

            // ── Buscador de aplicaciones (ARRIBA) ─────────────
            // Buscas, aparecen los resultados debajo del cuadro y un
            // clic añade la app al autoinicio. Las que ya están salen
            // con ✓ "(ya en autoinicio)" y sin clic.
            Rectangle {
                width: parent.width
                height: 34
                radius: 8
                color: Settings.surface
                border {
                    width: 1
                    color: addSearch.activeFocus ? Settings.accent : "transparent"
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
                    id: addSearch
                    anchors.fill: parent
                    anchors.leftMargin: 30
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: Settings.fg
                    font.family: Settings.fontFamily
                    font.pixelSize: 12
                }

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 30
                    anchors.rightMargin: 10
                    verticalAlignment: Text.AlignVCenter
                    visible: addSearch.text === ""
                    text: "Buscar aplicación para añadir al autoinicio..."
                    color: Settings.subtext0
                    font.family: Settings.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

            Repeater {
                model: root.addCandidates()

                delegate: Rectangle {
                    id: candRow
                    required property int index
                    required property var modelData

                    width: parent.width
                    height: 34
                    radius: 8
                    color: candMa.containsMouse ? Settings.selectionBg : Settings.surface

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: plusBtn.left
                        anchors.rightMargin: 10
                        text: candRow.modelData.name + (candRow.modelData.added ? "  (ya en autoinicio)" : "")
                        color: candRow.modelData.added ? Settings.muted : Settings.fg
                        font.family: Settings.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        id: plusBtn
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        width: 26
                        height: 26
                        radius: 6
                        color: candRow.modelData.added ? "transparent"
                             : candMa.containsMouse ? Settings.accent : Settings.bg

                        Text {
                            anchors.centerIn: parent
                            // ✓ = ya está en el autoinicio; + = clic para añadir
                            text: candRow.modelData.added ? "\u2713" : "+"
                            color: candRow.modelData.added ? Settings.green
                                 : candMa.containsMouse ? Settings.bg : Settings.muted
                            font.pixelSize: 15
                            font.weight: Font.Bold
                        }
                    }

                    MouseArea {
                        id: candMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: candRow.modelData.added ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: {
                            if (!candRow.modelData.added)
                                root.addAutostart(candRow.modelData.id);
                        }
                    }
                }
            }

            Text {
                width: parent.width
                visible: addSearch.text !== "" && root.addCandidates().length === 0
                text: "Sin resultados."
                color: Settings.muted
                font.family: Settings.fontFamily
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            // ── Lista de apps EN el autoinicio (debajo) ───────
            Text {
                text: "En el autoinicio"
                color: Settings.subtext0
                font.family: Settings.fontFamily
                font.pixelSize: 11
                font.weight: Font.Bold
            }

            Text {
                visible: root.autostartApps.length === 0
                width: parent.width
                text: "No hay aplicaciones de autoinicio. Busca arriba y haz clic para añadirla."
                color: Settings.muted
                font.family: Settings.fontFamily
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: root.autostartApps

                delegate: Rectangle {
                    id: entry
                    required property var modelData

                    // Estado visual LOCAL del switch. NO bindear directo a
                    // modelData.hidden: al reasignarse root.autostartApps (tras
                    // cada relistado) el Repeater recrea los delegados ya en su
                    // estado final y los Behavior no animan nada. Aquí el
                    // cambio ocurre con la fila viva, así que la animación sí
                    // corre; el relistado posterior reconcilia con el disco.
                    property bool enabledState: !modelData.hidden

                    width: parent.width
                    height: 34
                    radius: 8
                    color: Settings.surface

                    MiniToggle {
                        id: entryToggle
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        checked: entry.enabledState
                        requestToggle: () => {
                            const nowEnabled = !entry.enabledState;
                            entry.enabledState = nowEnabled;
                            root.setAutostartEnabled(entry.modelData.id, nowEnabled);
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: entryToggle.right
                        anchors.leftMargin: 10
                        anchors.right: delBtn.left
                        anchors.rightMargin: 10
                        text: entry.modelData.name + (!entry.enabledState ? "  (desactivada)" : "")
                        color: entry.enabledState ? Settings.fg : Settings.muted
                        font.family: Settings.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        id: delBtn
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        width: 26
                        height: 26
                        radius: 6
                        // Siempre visible (círculo oscuro sobre la tarjeta);
                        // en hover se pone rojo para avisar del borrado.
                        color: delMa.containsMouse ? Settings.red : Settings.bg

                        Text {
                            anchors.centerIn: parent
                            text: Icons.trash
                            color: delMa.containsMouse ? "#FFFFFF" : Settings.muted
                            font.family: Settings.iconFontFamily
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: delMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.removeAutostart(entry.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
