// ─── Sección de audio (mixer por app) ────────────────────────────────
// Lista salidas y entradas con volumen por-app vía Pipewire.
// Hardware-adaptativo: si no hay streams muestra "Sin reproducción".
// El sink por defecto se controla ya desde Notificaciones/QuickAccess.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import "../config"

Item {
    id: root
    anchors.fill: parent

    readonly property var sink: Pipewire.ready ? Pipewire.defaultAudioSink : null
    readonly property real outVol: sink && sink.audio && Number.isFinite(sink.audio.volume) ? sink.audio.volume : 0
    readonly property bool outMuted: sink && sink.audio && typeof sink.audio.muted === "boolean" ? sink.audio.muted : false
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    // Streams de reproducción: solo Stream/Output/Audio activos.
    // Pipewire solo crea nodos mientras la app reproduce/captura; Brave
    // sin audio no aparece (es normal, igual que pavucontrol).
    //
    // OJO — los nodos SIN trackear llegan con `properties` vacío y con la
    // heurística `isSink` en true (quickshell mapea "Output" del media.class
    // a sink aunque sea un stream de app): NO se puede filtrar por isSink ni
    // por properties en el primer pase. Hay que bindearlos con un
    // PwObjectTracker (pobla properties/audio) y filtrar por el
    // media.class real ya trackeado.
    property var rawStreams: []
    property var streams: []
    // Grupos expandidos (clave de grupo -> bool). Objeto reasignado para
    // que el binding de los delegates reaccione. Por defecto los grupos
    // llegan DESPLEGADOS (ausente = expandido; solo `false` colapsa).
    property var expandedKeys: ({})
    function toggleExpanded(key: string): void {
        var e = Object.assign({}, root.expandedKeys);
        e[key] = !(e[key] !== false);
        root.expandedKeys = e;
    }
    PwObjectTracker { id: streamTracker; objects: root.rawStreams }
    function refreshStreams(): void {
        if (!Pipewire.ready || !Pipewire.nodes) { root.rawStreams = []; root.streams = []; return; }
        const vals = Pipewire.nodes.values;
        const raw = [];
        for (let i=0;i<vals.length;i++) {
            const n = vals[i];
            if (!n || !n.isStream) continue;
            // Exclusiones por nombre (único fiable sin trackear):
            // captura del filtro de mic y el propio quickshell.
            if (n.name && n.name.indexOf("capture.") === 0) continue;
            if (n.name === "quickshell") continue;
            raw.push(n);
        }
        root.rawStreams = raw;
        applyStreamFilter();
    }
    function applyStreamFilter(): void {
        const raw = root.rawStreams || [];
        // Agrupar por aplicación (estilo mixer de Windows): Brave/Chromium
        // al arrancar reproducción crea un stream y luego lo recrea desde
        // su audio service; el viejo queda vivo un rato. Con UNA entrada
        // por app (controlando todos sus streams a la vez) ese solape es
        // invisible para el usuario.
        const groups = {};
        const order = [];
        var seen = {};
        for (let i=0;i<raw.length;i++) {
            const n = raw[i];
            if (!n) continue;
            // OJO — zombis: nodos que nunca llegan a bindearse tienen
            // properties vacías para siempre; fuera.
            const mc = n.properties ? String(n.properties["media.class"] || "") : "";
            if (mc === "") continue;
            if (mc.indexOf("Input") !== -1) continue;
            if (seen[n.id]) continue;
            seen[n.id] = true;
            const props = n.properties || {};
            const bin = String(props["application.process.binary"] || "");
            const appName = String(props["application.name"] || "");
            const key = bin !== "" ? bin : (appName !== "" ? appName : "n" + n.id);
            if (!groups[key]) {
                // Etiqueta: application.name suele servir, pero hay apps
                // genéricas (juegos SDL → "SDL Application") que se ven
                // mejor con el binario real ("dota2" → "Dota 2").
                const GENERIC = ["sdl application", "sdl_app", "game"];
                const binPretty = bin.replace(/-bin$/, "");
                const PRETTY = { "dota2": "Dota 2" };
                var label = appName !== "" ? appName : (n.nickname || n.description || n.name || "App");
                if (GENERIC.indexOf(label.toLowerCase()) !== -1 && binPretty !== "")
                    label = PRETTY[binPretty] || (binPretty.charAt(0).toUpperCase() + binPretty.slice(1));
                groups[key] = {
                    key: key,
                    label: label,
                    bin: bin,
                    // Icono del tema (Papirus/hicolor) por binario; el
                    // delegate muestra un glifo si no existe.
                    iconName: binPretty !== "" ? binPretty : "",
                    nodes: []
                };
                order.push(key);
            }
            groups[key].nodes.push(n);
        }
        const out = [];
        for (let k=0;k<order.length;k++) out.push(groups[order[k]]);
        // Solo reasignar si cambió de verdad: reemplazar el array cada tick
        // reconstruiría los delegates y cortaría los sliders a mitad de drag.
        var same = out.length === root.streams.length;
        if (same) for (var j=0;j<out.length;j++) {
            if (out[j].key !== root.streams[j].key) { same = false; break; }
            if (out[j].nodes.length !== root.streams[j].nodes.length) { same = false; break; }
            for (var m=0;m<out[j].nodes.length;m++)
                if (out[j].nodes[m] !== root.streams[j].nodes[m]) { same = false; break; }
            if (!same) break;
        }
        if (!same) root.streams = out;
    }
    Connections { target: Pipewire; function onReadyChanged(): void { root.refreshStreams(); } }
    Timer { interval: 800; running: true; repeat: true; onTriggered: root.refreshStreams() }
    Component.onCompleted: root.refreshStreams()

    Flickable {
        anchors.fill: parent
        anchors.margins: 8
        contentWidth: width
        contentHeight: mainCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: mainCol
            width: parent.width
            spacing: 10

        Text {
            text: "Audio"
            color: Settings.fg
            font.family: Settings.fontFamily
            font.pixelSize: 15
            font.weight: Font.Bold
        }
        Text {
            Layout.fillWidth: true
            text: "Volumen de salida y mezcla por aplicación. Los cambios son en vivo vía Pipewire (wpctl)."
            color: Settings.subtext0
            font.family: Settings.fontFamily
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        // ── Salida por defecto ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            SymbolicIcon {
                path: root.outMuted ? Icons.volumeMute : root.outVol < 0.01 ? Icons.volumeOff : root.outVol < 0.34 ? Icons.volumeLow : root.outVol < 0.67 ? Icons.volumeMedium : Icons.volumeHigh
                color: root.outMuted ? Settings.red : Settings.accent
                implicitSize: 16
                Layout.alignment: Qt.AlignVCenter
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted }
            }
            Slider {
                id: outSlider
                Layout.fillWidth: true
                from: 0; to: 100; value: Math.round(root.outVol*100)
                onMoved: if (root.sink && root.sink.audio) root.sink.audio.volume = value/100
                background: Rectangle {
                    x: outSlider.leftPadding; y: outSlider.topPadding + outSlider.availableHeight/2 - height/2
                    width: outSlider.availableWidth; height: 4; radius: 2; color: Settings.surface
                    Rectangle { anchors.left: parent.left; width: parent.width * outSlider.visualPosition; height: parent.height; radius: 2; color: root.outMuted ? Settings.red : Settings.accent }
                }
                handle: Rectangle {
                    x: outSlider.leftPadding + outSlider.visualPosition*(outSlider.availableWidth-width); y: outSlider.topPadding + outSlider.availableHeight/2 - height/2
                    implicitWidth: 12; implicitHeight: 12; radius: 6; color: root.outMuted ? Settings.red : Settings.accent; border { width: 2; color: Settings.bg }
                }
            }
            Text { text: Math.round(root.outVol*100)+"%"; color: Settings.fg; font.family: Settings.fontFamily; font.pixelSize: 11; font.weight: Font.Bold; Layout.alignment: Qt.AlignVCenter }
        }

        Text {
            text: "Aplicaciones"
            color: Settings.muted
            font.family: Settings.fontFamily
            font.pixelSize: 11
            font.weight: Font.Bold
        }

        // Lista de streams (apps con audio activo)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: root.streams
                delegate: Item {
                    id: del
                    required property var modelData
                    required property int index
                    // modelData es un GRUPO { key, label, bin, iconName, nodes[] }:
                    // una entrada por app (fila padre) + sus streams (filas hijo).
                    readonly property var gnodes: del.modelData ? del.modelData.nodes : []
                    readonly property bool exp: del.modelData ? root.expandedKeys[del.modelData.key] !== false : false
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44 + (del.exp ? del.gnodes.length * 36 + 8 : 0)
                    // Audio de referencia (primer nodo con audio válido ya
                    // trackeado); el volumen se aplica a TODOS los nodos.
                    readonly property QtObject aud: {
                        for (var i=0;i<gnodes.length;i++)
                            if (gnodes[i].audio && Number.isFinite(gnodes[i].audio.volume)) return gnodes[i].audio;
                        return null;
                    }
                    readonly property real vol: del.aud ? del.aud.volume : 0
                    readonly property bool muted: del.aud ? del.aud.muted === true : false
                    function setGroupVolume(v: real): void {
                        for (var i=0;i<gnodes.length;i++)
                            if (gnodes[i].audio) gnodes[i].audio.volume = v;
                    }
                    function setGroupMuted(m: bool): void {
                        for (var i=0;i<gnodes.length;i++)
                            if (gnodes[i].audio) gnodes[i].audio.muted = m;
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: Settings.surface
                    }
                    // ── Fila padre: app completa ──
                    RowLayout {
                        id: headRow
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 44
                        anchors.margins: 6
                        spacing: 8
                        Item {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            Layout.alignment: Qt.AlignVCenter
                            // Icono real de la app (tema Papirus/hicolor por
                            // binario); si no existe, glifo de altavoz.
                            IconImage {
                                id: appIcon
                                anchors.centerIn: parent
                                width: 18; height: 18
                                source: del.modelData && del.modelData.iconName !== "" ? Quickshell.iconPath(del.modelData.iconName, true) : ""
                            }
                            SymbolicIcon {
                                anchors.centerIn: parent
                                path: del.muted ? Icons.volumeMute : Icons.volumeHigh
                                color: del.muted ? Settings.red : Settings.muted
                                implicitSize: 14
                                visible: appIcon.status !== Image.Ready
                            }
                        }
                        MouseArea {
                            Layout.preferredWidth: 210
                            Layout.preferredHeight: 34
                            Layout.alignment: Qt.AlignVCenter
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (del.modelData) root.toggleExpanded(del.modelData.key)
                            ColumnLayout {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                spacing: 0
                                Text {
                                    Layout.fillWidth: true
                                    text: del.modelData ? del.modelData.label : "App"
                                    color: Settings.fg
                                    font.family: Settings.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: {
                                        if (!del.modelData) return "";
                                        var parts = [];
                                        if (del.modelData.bin !== "") parts.push(del.modelData.bin);
                                        if (del.gnodes.length > 1) parts.push(del.gnodes.length + " streams");
                                        return parts.join(" · ");
                                    }
                                    color: Settings.muted
                                    font.family: Settings.fontFamily
                                    font.pixelSize: 9
                                    elide: Text.ElideRight
                                    visible: text !== ""
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
                        SymbolicIcon {
                            path: del.exp ? Icons.chevronUp : Icons.chevronDown
                            color: Settings.muted
                            implicitSize: 12
                            Layout.alignment: Qt.AlignVCenter
                            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: if (del.modelData) root.toggleExpanded(del.modelData.key) }
                        }
                        Slider {
                            id: s
                            Layout.preferredWidth: 110
                            from: 0; to: 100; value: Math.round(del.vol*100)
                            enabled: del.aud !== null
                            onMoved: del.setGroupVolume(value/100)
                            background: Rectangle {
                                x: s.leftPadding; y: s.topPadding + s.availableHeight/2 - height/2
                                width: s.availableWidth; height: 4; radius: 2; color: Settings.bg
                                Rectangle { width: parent.width * s.visualPosition; height: parent.height; radius: 2; color: del.muted ? Settings.red : Settings.accent }
                            }
                            handle: Rectangle {
                                x: s.leftPadding + s.visualPosition*(s.availableWidth-width); y: s.topPadding + s.availableHeight/2 - height/2
                                implicitWidth: 10; implicitHeight: 10; radius: 5; color: del.muted ? Settings.red : Settings.accent; border { width: 2; color: Settings.bg }
                            }
                        }
                        Text { text: Math.round(del.vol*100)+"%"; color: Settings.muted; font.family: Settings.fontFamily; font.pixelSize: 10; Layout.alignment: Qt.AlignVCenter; Layout.preferredWidth: 34; horizontalAlignment: Text.AlignRight }
                        Rectangle {
                            Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 6; color: ma.containsMouse ? Settings.selectionBg : "transparent"
                            SymbolicIcon { anchors.centerIn: parent; path: del.muted ? Icons.volumeMute : Icons.volumeHigh; color: del.muted ? Settings.red : Settings.muted; implicitSize: 14 }
                            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: del.setGroupMuted(!del.muted) }
                        }
                    }
                    // ── Filas hijo: un stream individual cada una ──
                    Column {
                        anchors.top: headRow.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 30
                        anchors.rightMargin: 10
                        anchors.bottomMargin: 6
                        spacing: 4
                        visible: del.exp
                        Repeater {
                            model: del.gnodes
                            delegate: Item {
                                id: child
                                required property var modelData
                                required property int index
                                width: parent ? parent.width : 0
                                height: 32
                                readonly property QtObject naud: child.modelData && child.modelData.audio && Number.isFinite(child.modelData.audio.volume) ? child.modelData.audio : null
                                readonly property bool nmuted: child.naud ? child.naud.muted === true : false
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 6
                                    color: Settings.bg
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 5
                                    spacing: 6
                                    Text {
                                        text: "Stream " + (child.index + 1)
                                        color: Settings.subtext0
                                        font.family: Settings.fontFamily
                                        font.pixelSize: 9
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Slider {
                                        id: cs
                                        Layout.fillWidth: true
                                        from: 0; to: 100; value: Math.round((child.naud ? child.naud.volume : 0)*100)
                                        enabled: child.naud !== null
                                        onMoved: if (child.modelData && child.modelData.audio) child.modelData.audio.volume = value/100
                                        background: Rectangle {
                                            x: cs.leftPadding; y: cs.topPadding + cs.availableHeight/2 - height/2
                                            width: cs.availableWidth; height: 3; radius: 1.5; color: Settings.surface
                                            Rectangle { width: parent.width * cs.visualPosition; height: parent.height; radius: 1.5; color: child.nmuted ? Settings.red : Settings.accent }
                                        }
                                        handle: Rectangle {
                                            x: cs.leftPadding + cs.visualPosition*(cs.availableWidth-width); y: cs.topPadding + cs.availableHeight/2 - height/2
                                            implicitWidth: 8; implicitHeight: 8; radius: 4; color: child.nmuted ? Settings.red : Settings.accent; border { width: 2; color: Settings.bg }
                                        }
                                    }
                                    Text { text: Math.round((child.naud ? child.naud.volume : 0)*100)+"%"; color: Settings.muted; font.family: Settings.fontFamily; font.pixelSize: 9; Layout.alignment: Qt.AlignVCenter; Layout.preferredWidth: 30; horizontalAlignment: Text.AlignRight }
                                    Rectangle {
                                        Layout.preferredWidth: 22; Layout.preferredHeight: 22; radius: 5; color: cma.containsMouse ? Settings.selectionBg : "transparent"
                                        SymbolicIcon { anchors.centerIn: parent; path: child.nmuted ? Icons.volumeMute : Icons.volumeHigh; color: child.nmuted ? Settings.red : Settings.muted; implicitSize: 11 }
                                        MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (child.modelData && child.modelData.audio) child.modelData.audio.muted = !child.modelData.audio.muted }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: root.streams.length === 0
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Sin reproducción activa"
                color: Settings.muted
                font.family: Settings.fontFamily
                font.pixelSize: 11
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "Solo apps que están sonando aparecen aquí (como pavucontrol). Abre YouTube/Spotify en Brave y dale play para verlo."
                color: Settings.muted
                font.family: Settings.fontFamily
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }
        }
        }
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
    }
}
