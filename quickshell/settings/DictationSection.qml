// ─── Sección de dictado por voz ───────────────────────────────────────
// Configura el motor whisper.cpp: idioma, recorte de silencio, si el texto
// se pega solo en la ventana enfocada y el modelo de whisper. Los cambios
// se persisten en dictate.json vía Settings.applyDictation (gestionado en
// shell.qml) y se usan en la siguiente transcripción.
//
// Además de la ruta manual del modelo, muestra los modelos INSTALADOS en
// ~/.local/share/dictation/models/ (clic para activar al instante) y ofrece
// un listado curado de modelos para DESCARGAR directamente desde Hugging
// Face (ggerganov/whisper.cpp) sin tocar la terminal; al terminar, el modelo
// se activa automáticamente.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../config"

Item {
    id: root

    anchors.fill: parent

    // ── Directorio de modelos (default de dictate.json:modelPath) ──
    readonly property string modelsDir: Quickshell.env("HOME") + "/.local/share/dictation/models"
    readonly property string modelsDirTilde: modelsDir.replace(Quickshell.env("HOME"), "~")
    property var installed: []                 // [{ name, bytes }]
    property string downloading: ""            // nombre del modelo descargándose
    property string downloadMsg: ""            // feedback tras la descarga
    property string dlUrl: ""                  // URL origen de la descarga actual
    property string dlCmd: ""                  // comando shell que se ejecuta
    property string dlBytes: "0"               // bytes descargados (sondeo del .part)
    property real dlPct: 0                     // % descargado (lo calcula el shell)
    property string delPending: ""             // modelo con confirmación de borrado abierta
    property var syncLines: []                 // salida cruda de "Comprobar repo"
    property bool syncBusy: false              // comprobación del repo en curso
    property string syncStatus: ""             // resultado de la última comprobación
    property var newModels: []                 // modelos del repo sin reseña curada: [{ name, bytes }]
    property var goneModels: []                 // modelos curados que ya no están en el repo

    // Bytes esperados de un modelo (para el % de la barra). Cubre la lista
    // curada y los modelos del repo aún no curados.
    function downloadBytes(name: string): number {
        for (let i = 0; i < root.downloads.length; i++)
            if (root.downloads[i].name === name)
                return root.downloads[i].bytes;
        for (let i = 0; i < root.newModels.length; i++)
            if (root.newModels[i].name === name)
                return root.newModels[i].bytes;
        return 0;
    }

    // ── Modelos descargables (curados, no el catálogo completo del repo).
    // Todos vienen de huggingface.co/ggerganov/whisper.cpp. `bytes` es el
    // tamaño EXACTO del archivo (HEAD) para calcular el % de la barra y
    // `pros` lista las ventajas/pegas que se muestran con el botón ⓘ.
    readonly property var downloads: [
        { name: "ggml-large-v3.bin",              size: "~3.1 GB", bytes: 3095033483, note: "Máxima precisión (batch); el más lento para dictado", pros: [
            "Precisión máxima de todo Whisper: soporta ruido, acentos y jerga técnica mejor que los demás.",
            "Decodificador completo (32 capas): el más fiel en transcripciones largas.",
            "El más lento — pensado para transcripción por lotes/offline, no para dictado en vivo.",
            "Ocupa ~6 GB de RAM al cargar." ] },
        { name: "ggml-large-v3-turbo.bin",        size: "~1.6 GB", bytes: 1624555275, note: "Turbo f16 completo: velocidad sin cuantizar", pros: [
            "Turbo: destilado de large-v3 con decodificador de 4 capas.",
            "De 6 a 8× más rápido que large-v3 y más preciso que medium.",
            "Versión sin cuantizar: máxima calidad del turbo.",
            "Menos de la mitad de tamaño que large-v3 (~3 GB de RAM)." ] },
        { name: "ggml-large-v3-turbo-q8_0.bin",   size: "~874 MB", bytes: 874188075,  note: "Turbo q8: máximo detalle del turbo", pros: [
            "Turbo cuantizado q8: pérdida imperceptible frente al f16 en dictado.",
            "Casi la misma velocidad que el turbo-q5 con algo más de precisión.",
            "655 MB más ligero que el f16; ~2.4 GB de RAM." ] },
        { name: "ggml-large-v3-turbo-q5_0.bin",   size: "~574 MB", bytes: 574041195,  note: "Turbo cuantizado: rápido y preciso (recomendado)", pros: [
            "El mejor equilibrio tamaño/velocidad/precisión — el recomendado.",
            "Más rápido y más preciso que tu medium-q8 actual (destilado de large).",
            "Ideal para dictado en vivo con GPU Vulkan (SUPER+D).",
            "Pesa ~574 MB; ~1.6 GB de RAM." ] },
        { name: "ggml-medium.bin",                size: "~1.5 GB", bytes: 1533763059, note: "El f16 de tu modelo actual", pros: [
            "Tu modelo actual sin cuantizar.",
            "Precisión casi idéntica al medium-q8 a costa de ~2× RAM.",
            "En la práctica el q8 o el turbo-q5 rinden mejor por tamaño." ] },
        { name: "ggml-medium-q8_0.bin",           size: "~823 MB", bytes: 823369779,  note: "El que usas ahora (medium q8)", pros: [
            "Tu modelo activo: buen punto medio de tamaño/precisión.",
            "Buen español general; falla más con jerga técnica y frases muy largas.",
            "El turbo-q5 lo supera en velocidad y precisión por menos peso." ] },
        { name: "ggml-medium-q5_0.bin",           size: "~539 MB", bytes: 539212467,  note: "Medium q5: similar, algo más ligero", pros: [
            "Medium cuantizado q5: ~284 MB más ligero que el q8.",
            "Pierde un poco de precisión frente al q8; la velocidad es casi igual.",
            "Por el mismo ahorro, mejor el turbo-q5 (más rápido y preciso)." ] },
        { name: "ggml-small-q8_0.bin",            size: "~264 MB", bytes: 264464607,  note: "El más veloz con buena precisión", pros: [
            "Aprox. 2-3× más rápido que medium: dictado casi instantáneo.",
            "Bueno para frases cortas, comandos y audio limpio.",
            "Se equivoca más en frases largas, nombres técnicos y con ruido de fondo." ] },
        { name: "ggml-tiny-q8_0.bin",             size: "~44 MB",  bytes: 43537433,   note: "Ultra rápido; solo para probar el flujo", pros: [
            "El más veloz: responde al instante, ideal para probar SUPER+D.",
            "Precisión baja; solo apto para pruebas o audio muy limpio.",
            "No recomendado como modelo de uso diario." ] },
    ]

    // Conjunto de nombres instalados (para el listado de descarga).
    readonly property var installedNames: (() => {
        const s = new Set();
        for (let i = 0; i < root.installed.length; i++)
            s.add(root.installed[i].name);
        return s;
    })()

    // Expande `~/...` al home real (con comillas dobles `~` no se expande
    // en el shell, así que para comparar/activar hay que expandirlo aquí).
    function expandPath(p: string): string {
        return p.indexOf("~/") === 0 ? Quickshell.env("HOME") + p.substring(1) : p;
    }

    // Nombre del archivo en uso (basename del modelPath expandido).
    function activeName(): string {
        const p = root.expandPath(Settings.dictModelPath);
        const i = p.lastIndexOf("/");
        return i === -1 ? p : p.substring(i + 1);
    }

    // Un modelo instalado está activo si apunta exactamente a él.
    function isActive(name: string): bool {
        return root.expandPath(Settings.dictModelPath).toLowerCase()
            === (root.modelsDir + "/" + name).toLowerCase();
    }

    // Activa un modelo instalado (persistido vía applyDictation).
    function activate(name: string): void {
        Settings.dictModelPath = root.modelsDirTilde + "/" + name;
        if (Settings.applyDictation) Settings.applyDictation();
    }

    function formatBytes(n: string): string {
        const b = Number(n);
        if (b < 1024) return b.toFixed(0) + " B";
        if (b < 1048576) return (b / 1024).toFixed(1) + " KB";
        if (b < 1073741824) return (b / 1048576).toFixed(1) + " MB";
        return (b / 1073741824).toFixed(2) + " GB";
    }

    // Reescanea el directorio de modelos (se lanza al abrir la sección y
    // tras cada descarga). Sin forks mientras no se abra/recargue.
    function refreshModels(): void {
        root.installed = [];
        lsProc.running = true;
    }

    // Lanza la descarga de un modelo (curl a Hugging Face). Descarga a un
    // `.part` y solo lo mueve al nombre final si curl acaba bien (--fail),
    // así un fallo de red no deja un archivo corrupto en el listado.
    function startDownload(name: string): void {
        if (root.downloading !== "") return;
        root.downloading = name;
        root.downloadMsg = "";
        root.dlBytes = "0";
        root.dlPct = 0;
        const url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/" + name;
        const dir = "\"$HOME/.local/share/dictation/models\"";
        const cmd = "mkdir -p " + dir + " && curl -fL --retry 2 --max-time 3600 -o " + dir + "/" + name + ".part \"" + url + "\" && mv " + dir + "/" + name + ".part " + dir + "/" + name + " || { rm -f " + dir + "/" + name + ".part; exit 1; }";
        root.dlUrl = url;
        root.dlCmd = cmd;
        dlProc.command = ["sh", "-c", cmd];
        dlProc.running = true;
    }

    // ── Escaneo del directorio de modelos (tamaño en bytes + nombre) ─
    Process {
        id: lsProc
        command: ["sh", "-c", "ls -la \"$HOME/.local/share/dictation/models/\"*.bin 2>/dev/null | awk '$9 ~ /\\.bin$/ {n=$9; sub(\".*/\",\"\",n); print $5, n}'"]
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                const t = line.trim();
                const i = t.indexOf(" ");
                if (i >= 0) {
                    root.installed = root.installed.concat(
                        { name: t.substring(i + 1).trim(), bytes: t.substring(0, i) }
                    );
                }
            }
        }
    }

    // Lanza una petición de borrado (dos pasos: confirmar de nuevo).
    function delRequest(name: string): void {
        root.delPending = name;
        delConfirmTimer.restart();
    }

    // Borra un modelo instalado del disco. Nunca el activo.
    function deleteModel(name: string): void {
        root.delPending = "";
        if (root.isActive(name)) return;
        delProc.command = ["sh", "-c", "rm -f \"$HOME/.local/share/dictation/models/" + name + "\""];
        delProc.running = true;
    }

    // ── Descarga (curl). Un proceso a la vez. ─────────────────────────
    Process {
        id: dlProc
        command: ["true"]
        running: false
        onExited: function(exitCode) {
            if (root.downloading === "") return;
            if (exitCode === 0) {
                root.downloadMsg = "Descargado: " + root.downloading + ". Activando...";
                root.activate(root.downloading);
            } else {
                root.downloadMsg = "Error descargando " + root.downloading + " (comprueba la conexión).";
            }
            root.downloading = "";
            root.refreshModels();
        }
    }

    // ── Progreso: sondea el tamaño del `.part` cada segundo mientras hay
    // una descarga activa (un solo fork por segundo, solo durante ella).
    // El `.part` vive hasta que curl acaba y mv lo renombra, así que se
    // comprueba primero ese y después el archivo final. El shell calcula
    // además el % (bytes*100/total) para no llamar funciones en bindings
    // (evita el ruido de qmlsc de Qt ≥6.7).
    Timer {
        id: dlPollTimer
        interval: 1000
        repeat: true
        running: root.downloading !== ""
        onTriggered: {
            const n = root.downloading;
            if (n === "") return;
            const total = root.downloadBytes(n);
            if (total <= 0) return;
            statProc.command = ["sh", "-c",
                "p=\"$HOME/.local/share/dictation/models/" + n + "\"; s=$(stat -c %s \"$p.part\" 2>/dev/null || stat -c %s \"$p\" 2>/dev/null); s=${s:-0}; echo \"$s $(( s * 100 / " + total + " ))\""];
            statProc.running = true;
        }
    }

    Process {
        id: statProc
        command: ["true"]
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                const parts = line.trim().split(" ");
                if (parts.length >= 1 && parts[0] !== "" && parts[0] !== "0")
                    root.dlBytes = parts[0];
                if (parts.length >= 2)
                    root.dlPct = Math.min(100, Number(parts[1]) || 0);
            }
        }
    }

    // ── Borrado de modelos. ──────────────────────────────────────────
    Process {
        id: delProc
        command: ["true"]
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0) root.refreshModels();
        }
    }

    // La confirmación de borrado se auto-cancela si no se confirma a tiempo.
    Timer {
        id: delConfirmTimer
        interval: 4000
        onTriggered: root.delPending = ""
    }

    // ── Sincronización con el repo (solo red cuando se pulsa). ──────
    // Consulta la API pública de Hugging Face (?blobs=true trae el tamaño
    // exacto), actualiza los `bytes` de la lista curada y detecta archivos
    // `.bin` del repo que aún no están curados. Los `.en` se omiten: son
    // modelos solo-inglés y el dictado es en español.
    function startSync(): void {
        if (root.syncBusy || root.downloading !== "") return;
        root.syncBusy = true;
        root.syncStatus = "Comprobando el repositorio…";
        root.syncLines = [];
        syncProc.command = ["sh", "-c", "curl -fsSL --max-time 30 \"https://huggingface.co/api/models/ggerganov/whisper.cpp?blobs=true\" | jq -r '.siblings[] | select(.rfilename | (test(\"^ggml-.*\\\\.bin$\") and (contains(\".en\") | not))) | \"\\(.rfilename) \\(.size // .lfs.size // 0)\"'"];
        syncProc.running = true;
    }

    function applySync(): void {
        const repo = {};
        const order = [];
        const lines = root.syncLines;
        for (let i = 0; i < lines.length; i++) {
            const t = lines[i].trim();
            const sp = t.lastIndexOf(" ");
            if (sp <= 0) continue;
            const name = t.substring(0, sp).trim();
            const bytes = parseInt(t.substring(sp + 1), 10);
            if (name !== "" && bytes > 0 && !(name in repo)) {
                repo[name] = bytes;
                order.push(name);
            }
        }
        const total = Object.keys(repo).length;
        if (total === 0) {
            root.syncStatus = "No se pudo consultar el repositorio (¿sin conexión?).";
            root.newModels = [];
            root.goneModels = [];
            root.syncBusy = false;
            return;
        }
        let changed = [], gone = [], added = [];
        for (let i = 0; i < root.downloads.length; i++) {
            const d = root.downloads[i];
            const b = repo[d.name];
            if (b === undefined) { gone.push(d.name); continue; }
            if (b !== d.bytes) { changed.push(d.name); d.bytes = b; }
            delete repo[d.name];
        }
        root.goneModels = gone;
        for (const n of order)
            if (repo[n] !== undefined) added.push(n);
        if (added.length > 0) {
            const nm = [];
            for (const n of added) nm.push({ name: n, bytes: repo[n] });
            root.newModels = nm;
        } else {
            root.newModels = [];
        }
        const parts = [];
        if (changed.length) parts.push("tamaños actualizados (" + changed.join(", ") + ")");
        if (added.length)  parts.push(added.length + (added.length === 1 ? " modelo" : " modelos") + " del repo sin reseña curada");
        if (gone.length)   parts.push(gone.join(", ") + (gone.length === 1 ? " ya no está en el repo" : " ya no están en el repo"));
        root.syncStatus = parts.length > 0
            ? "Repo: " + parts.join(" · ")
            : "Lista al día · " + total + " modelos .bin en el repo.";
        root.syncBusy = false;
    }

    Process {
        id: syncProc
        command: ["true"]
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                const s = line.trim();
                if (s !== "") root.syncLines = root.syncLines.concat([s]);
            }
        }
        onExited: function(exitCode) {
            root.applySync();
            root.syncLines = [];
            root.syncBusy = false;
        }
    }

    Component.onCompleted: refreshModels()

    // ── Título + subtítulo (fijos) ──────────────────────────────────
    Text {
        id: titleText
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        text: "Dictado por voz"
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
        text: "Pulsa SUPER+D para grabar, habla, y vuelve a pulsar para transcribir con whisper.cpp (GPU Vulkan) y pegar el texto donde estés escribiendo. Si no hay ventana enfocada, se queda copiado en el portapapeles."
        color: Settings.subtext0
        font.family: Settings.fontFamily
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }

    // ── Cuerpo scrolleable ───────────────────────────────────────────
    Flickable {
        id: bodyFlick
        anchors.top: subtitleText.bottom
        anchors.topMargin: 8
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        contentWidth: width
        contentHeight: bodyCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: bodyCol
            width: bodyFlick.width
            spacing: 10

            // ── Pegar en la ventana enfocada ────────────────────
            Row {
                width: parent.width
                spacing: 10

                Rectangle {
                    width: 40
                    height: 22
                    radius: 11
                    color: Settings.dictPasteFocused ? Settings.green : Settings.surface
                    Behavior on color { ColorAnimation { duration: 80 } }

                    Rectangle {
                        width: 16
                        height: 16
                        radius: 8
                        color: Settings.bg
                        anchors.verticalCenter: parent.verticalCenter
                        x: Settings.dictPasteFocused ? parent.width - width - 3 : 3
                        Behavior on x { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Settings.dictPasteFocused = !Settings.dictPasteFocused;
                            if (Settings.applyDictation) Settings.applyDictation();
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Pegar automáticamente en la ventana enfocada"
                    color: Settings.fg
                    font.family: Settings.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }

            // ── Recortar silencio ────────────────────────────────
            Row {
                width: parent.width
                spacing: 10

                Rectangle {
                    width: 40
                    height: 22
                    radius: 11
                    color: Settings.dictTrimSilence ? Settings.green : Settings.surface
                    Behavior on color { ColorAnimation { duration: 80 } }

                    Rectangle {
                        width: 16
                        height: 16
                        radius: 8
                        color: Settings.bg
                        anchors.verticalCenter: parent.verticalCenter
                        x: Settings.dictTrimSilence ? parent.width - width - 3 : 3
                        Behavior on x { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Settings.dictTrimSilence = !Settings.dictTrimSilence;
                            if (Settings.applyDictation) Settings.applyDictation();
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Recortar silencio antes de transcribir"
                    color: Settings.fg
                    font.family: Settings.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }

            // ── Sonido al terminar ────────────────────────────────
            Row {
                width: parent.width
                spacing: 10

                Rectangle {
                    width: 40
                    height: 22
                    radius: 11
                    color: Settings.dictSoundOnFinish ? Settings.green : Settings.surface
                    Behavior on color { ColorAnimation { duration: 80 } }

                    Rectangle {
                        width: 16
                        height: 16
                        radius: 8
                        color: Settings.bg
                        anchors.verticalCenter: parent.verticalCenter
                        x: Settings.dictSoundOnFinish ? parent.width - width - 3 : 3
                        Behavior on x { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Settings.dictSoundOnFinish = !Settings.dictSoundOnFinish;
                            if (Settings.applyDictation) Settings.applyDictation();
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Sonido de aviso al terminar"
                    color: Settings.fg
                    font.family: Settings.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }

            // ── Idioma ───────────────────────────────────────────
            Text {
                text: "Idioma"
                color: Settings.subtext0
                font.family: Settings.fontFamily
                font.pixelSize: 11
                font.weight: Font.Bold
            }

            Row {
                width: parent.width
                spacing: 8

                Repeater {
                    model: Settings.dictLangs

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool active: Settings.dictLang === modelData.id

                        width: 90
                        height: 34
                        radius: 8
                        color: active ? Settings.accent : Settings.surface
                        border {
                            width: 1
                            color: active ? "transparent" : Settings.selectionBg
                        }
                        Behavior on color { ColorAnimation { duration: Settings.animationFast } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: active ? Settings.bg : Settings.fg
                            font.family: Settings.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Settings.dictLang = modelData.id;
                                if (Settings.applyDictation) Settings.applyDictation();
                            }
                        }
                    }
                }
            }

            // ── Ruta del modelo ──────────────────────────────────
            Text {
                text: "Modelo whisper"
                color: Settings.subtext0
                font.family: Settings.fontFamily
                font.pixelSize: 11
                font.weight: Font.Bold
            }

            TextField {
                id: modelField
                width: parent.width
                height: 34
                text: Settings.dictModelPath
                color: Settings.fg
                font.family: Settings.fontFamily
                font.pixelSize: 11
                selectByMouse: true
                verticalAlignment: Text.AlignVCenter
                padding: 8

                background: Rectangle {
                    radius: 8
                    color: Settings.surface
                    border {
                        width: 1
                        color: modelField.activeFocus ? Settings.accent : Settings.selectionBg
                    }
                }

                onEditingFinished: {
                    if (modelField.text.trim() !== Settings.dictModelPath) {
                        Settings.dictModelPath = modelField.text.trim();
                        if (Settings.applyDictation) Settings.applyDictation();
                    }
                }
            }

            Text {
                text: root.activeName()
                    ? "En uso: " + root.activeName() + " · los instalados se listan aquí abajo"
                    : "Modelos en " + root.modelsDirTilde + " · este campo acepta cualquier ruta"
                color: Settings.subtext0
                font.family: Settings.fontFamily
                font.pixelSize: 10
                wrapMode: Text.WordWrap
                width: parent.width
            }

            // ── Modelos instalados ───────────────────────────────
            Item {
                width: parent.width
                height: 26

                Text {
                    id: installedLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Modelos instalados"
                    color: Settings.subtext0
                    font.family: Settings.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }

                Rectangle {
                    id: refreshBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    radius: 7
                    color: lsProc.running ? Settings.selectionBg : "transparent"

                    SymbolicIcon {
                        anchors.centerIn: parent
                        path: Icons.refresh
                        color: Settings.subtext0
                        implicitSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: refreshModels()
                    }
                }

                Text {
                    anchors.right: refreshBtn.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Actualizar"
                    color: Settings.muted
                    font.family: Settings.fontFamily
                    font.pixelSize: 10
                }
            }

            Text {
                visible: root.installed.length === 0
                width: parent.width
                text: "No hay modelos en " + root.modelsDirTilde + ". Descarga uno abajo o copia el archivo manualmente."
                color: Settings.muted
                font.family: Settings.fontFamily
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: root.installed

                delegate: Rectangle {
                    required property var modelData
                    readonly property bool active: root.isActive(modelData.name)

                    width: parent.width
                    height: 40
                    radius: 8
                    color: active ? Settings.selectionBg : Settings.surface
                    Behavior on color { ColorAnimation { duration: Settings.animationFast } }

                    // Marca del modelo en uso
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12
                        width: 8
                        height: 8
                        radius: 4
                        color: active ? Settings.accent : "transparent"
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 28
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        color: active ? Settings.fg : Settings.subtext0
                        font.family: Settings.fontFamily
                        font.pixelSize: 12
                        font.weight: active ? Font.Bold : Font.Medium
                        elide: Text.ElideMiddle
                    }

                    Text {
                        id: sizeTextInst
                        anchors.right: delBtn.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: active ? formatBytes(modelData.bytes) + " · En uso" : formatBytes(modelData.bytes)
                        color: active ? Settings.accent : Settings.muted
                        font.family: Settings.fontFamily
                        font.pixelSize: 10
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 28
                        anchors.right: sizeTextInst.left
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        color: active ? Settings.fg : Settings.subtext0
                        font.family: Settings.fontFamily
                        font.pixelSize: 12
                        font.weight: active ? Font.Bold : Font.Medium
                        elide: Text.ElideMiddle
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activate(modelData.name)
                    }

                    // Botón de eliminar (pintado encima del row, así captura
                    // el clic antes que "activar"). Dos pasos para confirmar;
                    // el modelo EN USO no se puede borrar.
                    Rectangle {
                        id: delBtn
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 8
                        width: root.delPending === modelData.name ? 62 : 26
                        height: 24
                        radius: 6
                        color: root.delPending === modelData.name ? Settings.red
                             : (delBtnMa.containsMouse ? Settings.selectionBg : "transparent")
                        Behavior on color { ColorAnimation { duration: Settings.animationFast } }
                        Behavior on width { NumberAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: root.delPending === modelData.name ? "Eliminar" : Icons.trash
                            font.family: root.delPending === modelData.name ? Settings.fontFamily : Settings.iconFontFamily
                            font.pixelSize: root.delPending === modelData.name ? 10 : 13
                            font.weight: Font.Bold
                            color: root.delPending === modelData.name ? Settings.bg : Settings.muted
                            elide: Text.ElideRight
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                        }

                        MouseArea {
                            id: delBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !active
                            onClicked: {
                                if (root.delPending === modelData.name)
                                    root.deleteModel(modelData.name);
                                else
                                    root.delRequest(modelData.name);
                            }
                        }
                    }
                }
            }

            // ── Descargar modelo ─────────────────────────────────
            Item {
                width: parent.width
                height: 26

                Text {
                    text: "Descargar modelo"
                    color: Settings.subtext0
                    font.family: Settings.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Lista curada · ggerganov/whisper.cpp"
                    color: Settings.muted
                    font.family: Settings.fontFamily
                    font.pixelSize: 10
                }
            }

            Text {
                visible: downloading === "" && downloadMsg === ""
                width: parent.width
                text: "Todos los archivos se descargan de huggingface.co/ggerganov/whisper.cpp (repo oficial de whisper.cpp); la lista es curada, no el catálogo completo del repo."
                color: Settings.muted
                font.family: Settings.fontFamily
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            // ── Comprobar actualizaciones del repositorio ──────────
            // Consulta la API de HF: actualiza los tamaños exactos de la
            // lista curada y detecta modelos `.bin` nuevos (sin reseña).
            Row {
                visible: downloading === "" && downloadMsg === ""
                width: parent.width
                spacing: 8

                Rectangle {
                    id: syncBtn
                    height: 26
                    width: 150
                    radius: 8
                    color: syncMa.containsMouse ? Settings.selectionBg : Settings.surface

                    Text {
                        anchors.centerIn: parent
                        text: root.syncBusy ? "Comprobando…" : "Comprobar repo"
                        color: Settings.fg
                        font.family: Settings.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: syncMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !root.syncBusy && root.downloading === ""
                        onClicked: root.startSync()
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - syncBtn.width - 8
                    text: root.syncStatus
                    color: root.syncStatus === "" ? Settings.muted
                         : (root.syncStatus.indexOf("Comprobando") === 0 ? Settings.yellow
                         : (root.syncStatus.indexOf("No se pudo") === 0 ? Settings.red
                         : Settings.accent))
                    font.family: Settings.fontFamily
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }
            }

            // ── Tarjeta de estado de la descarga (progreso + origen) ──
            Rectangle {
                visible: downloading !== "" || downloadMsg !== ""
                width: parent.width
                height: statusCol.implicitHeight + 14
                radius: 8
                color: Settings.surface
                border {
                    width: 1
                    color: Settings.selectionBg
                }

                Column {
                    id: statusCol
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 8
                    spacing: 5

                    Text {
                        width: parent.width
                        text: downloading !== ""
                            ? "Descargando " + downloading
                            : downloadMsg
                        color: downloading !== "" ? Settings.yellow : (downloadMsg.indexOf("Error") === 0 ? Settings.red : Settings.green)
                        font.family: Settings.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        wrapMode: Text.WordWrap
                    }

                    // Barra de progreso + %
                    Row {
                        visible: downloading !== ""
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            id: progTrack
                            height: 8
                            width: parent.width - pctText.implicitWidth - parent.spacing
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 4
                            color: Settings.bg

                            Rectangle {
                                height: parent.height
                                width: Math.max(0, root.dlPct / 100 * parent.width)
                                radius: 4
                                color: Settings.accent
                                Behavior on width { NumberAnimation { duration: 300 } }
                            }
                        }

                        Text {
                            id: pctText
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.dlPct + "%"
                            color: Settings.fg
                            font.family: Settings.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                    }

                    Text {
                        visible: downloading !== ""
                        width: parent.width
                        text: root.formatBytes(root.dlBytes) + " de " + root.modelSizeLabel(downloading)
                        color: Settings.subtext0
                        font.family: Settings.fontFamily
                        font.pixelSize: 10
                    }

                    // De dónde se obtiene
                    Text {
                        visible: downloading !== ""
                        width: parent.width
                        text: "Origen: " + root.dlUrl
                        color: Settings.muted
                        font.family: Settings.fontFamily
                        font.pixelSize: 9
                        wrapMode: Text.WordWrap
                    }

                    // Qué se ejecuta por detrás
                    Text {
                        visible: downloading !== ""
                        width: parent.width
                        text: "Comando: " + root.dlCmd
                        color: Settings.muted
                        font.family: Settings.fontFamily
                        font.pixelSize: 9
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Repeater {
                model: root.downloads

                delegate: Rectangle {
                    required property var modelData
                    readonly property bool already: root.installedNames.has(modelData.name)
                    readonly property bool gone: root.goneModels.indexOf(modelData.name) >= 0
                    readonly property bool busy: root.downloading === modelData.name
                    readonly property bool anyDownloading: root.downloading !== ""
                    property bool openInfo: false

                    width: parent.width
                    height: 44 + (openInfo ? 6 + infoArea.height : 0)
                    radius: 8
                    color: busy ? Settings.selectionBg : Settings.surface
                    border {
                        width: 1
                        color: Settings.selectionBg
                    }

                    // ── Fila superior FIJA (44 px): nombre, ⓘ y descargar
                    // quedan centrados en ESTA fila, no en todo el rectángulo.
                    // Si se anclaran al rect del delegado, al expandir la
                    // tarjeta el `verticalCenter` se desplazaría y el nombre
                    // se pegaría/encimaría a las ventajas del panel ⓘ.
                    Item {
                        id: topRow
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 44

                        // Botón de descarga
                        Rectangle {
                            id: dlBtn
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.rightMargin: 8
                            width: 82
                            height: 28
                            radius: 8
                            color: (gone || already) ? "transparent" : (busy ? Settings.selectionBg : Settings.surface)

                            Text {
                                anchors.centerIn: parent
                                text: busy ? "Descargando…"
                                     : already ? "Descargado"
                                     : gone ? "No en repo"
                                     : "Descargar"
                                color: already ? Settings.muted
                                     : (busy ? Settings.accent
                                     : (gone ? Settings.muted : Settings.fg))
                                font.family: Settings.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: !gone && !already && !busy && !anyDownloading
                                onClicked: root.startDownload(modelData.name)
                            }
                        }

                        // Botón de información: despliega las ventajas del modelo
                        Rectangle {
                            id: infoBtn
                            anchors.right: dlBtn.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.rightMargin: 6
                            width: 26
                            height: 26
                            radius: 13
                            color: openInfo ? Settings.selectionBg
                                 : (infoMa.containsMouse ? Settings.selectionBg : "transparent")

                            Text {
                                anchors.centerIn: parent
                                text: Icons.info
                                color: openInfo ? Settings.accent : Settings.muted
                                font.family: Settings.iconFontFamily
                                font.pixelSize: 13
                            }

                            MouseArea {
                                id: infoMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: openInfo = !openInfo
                            }
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.right: infoBtn.left
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                text: modelData.name + "   (" + modelData.size + ")"
                                color: root.activeName() === modelData.name ? Settings.fg : Settings.subtext0
                                font.family: Settings.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                elide: Text.ElideMiddle
                                width: parent.width
                            }

                            Text {
                                text: modelData.note
                                color: Settings.muted
                                font.family: Settings.fontFamily
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }

                    // ── Panel expandible: qué aporta este modelo ──
                    Column {
                        id: infoArea
                        visible: openInfo
                        anchors.top: topRow.bottom
                        anchors.topMargin: 6
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 16
                        anchors.rightMargin: 12
                        spacing: 4

                        Text {
                            width: parent.width
                            text: modelData.pros.map(p => "·" + p).join("\n")
                            color: Settings.subtext0
                            font.family: Settings.fontFamily
                            font.pixelSize: 10
                            lineHeight: 1.3
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            width: parent.width
                            text: "Origen: https://huggingface.co/ggerganov/whisper.cpp/resolve/main/" + modelData.name
                            color: Settings.muted
                            font.family: Settings.fontFamily
                            font.pixelSize: 9
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            // ── Modelos del repo sin reseña curada ───────────────
            // Aparecen tras pulsar "Comprobar repo": mismo origen oficial,
            // pero aún no tienen reseña/ventajas propias en la lista curada.
            Item {
                visible: root.newModels.length > 0
                width: parent.width
                height: 26

                Text {
                    text: "Modelos del repo (sin reseña curada)"
                    color: Settings.subtext0
                    font.family: Settings.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.newModels.length + " · orígenes oficiales"
                    color: Settings.muted
                    font.family: Settings.fontFamily
                    font.pixelSize: 9
                }
            }

            Repeater {
                model: root.newModels

                delegate: Rectangle {
                    required property var modelData
                    readonly property bool already: root.installedNames.has(modelData.name)
                    readonly property bool anyDownloading: root.downloading !== ""

                    width: parent.width
                    height: 40
                    radius: 8
                    color: nmHover.containsMouse ? Settings.selectionBg : Settings.surface
                    border {
                        width: 1
                        color: Settings.selectionBg
                    }

                    Text {
                        id: nmSize
                        anchors.right: nmBtn.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.formatBytes(String(modelData.bytes))
                        color: Settings.muted
                        font.family: Settings.fontFamily
                        font.pixelSize: 10
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.right: nmSize.left
                        anchors.leftMargin: 12
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        color: Settings.subtext0
                        font.family: Settings.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideMiddle
                    }

                    Rectangle {
                        id: nmBtn
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 8
                        width: 76
                        height: 26
                        radius: 8
                        color: already ? "transparent" : Settings.surface

                        Text {
                            anchors.centerIn: parent
                            text: already ? "Descargado" : "Descargar"
                            color: already ? Settings.muted : Settings.fg
                            font.family: Settings.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: !already && !anyDownloading
                            onClicked: root.startDownload(modelData.name)
                        }
                    }

                    MouseArea {
                        id: nmHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }
    }

    // Etiqueta legible del tamaño para el feedback de descarga.
    function modelSizeLabel(name: string): string {
        for (let i = 0; i < root.downloads.length; i++)
            if (root.downloads[i].name === name)
                return root.downloads[i].size;
        for (let i = 0; i < root.newModels.length; i++)
            if (root.newModels[i].name === name)
                return root.formatBytes(String(root.newModels[i].bytes));
        return "?";
    }
}