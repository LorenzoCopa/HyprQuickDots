// ─── Comandos de voz (whisper.cpp + acciones) ─────────────────────────
// `qs ipc call voicecmd toggle` graba con pw-record (misma fuente y formato
// que el dictado), transcribe con whisper-cli y traduce el texto a una
// acción: abrir una app, abrir un servicio web en Brave, controlar la
// música (MPRIS) o el volumen (Pipewire). El estado visual es el OSD
// (qs-voicecmd), una superficie layer-shell que no roba el foco.
//
// `qs ipc call voicecmd stop`  → termina la grabación y procesa.
// `qs ipc call voicecmd cancel` → descarta la grabación (enrutado por ESC
// desde hypr/modules/quickshell/dictation.lua, que ya tiene el bind
// `non_consuming` de Escape).

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import "../config"

Scope {
    id: root

    // ── Estado visible en el OSD ────────────────────────────────
    property string vcState: "idle"      // idle|recording|thinking|executing|done|error
    property string vcElapsedText: "0:00"
    property string vcResultText: ""
    property string vcResultNote: ""
    property int _vcElapsedS: 0

    // ── Micro del comando de voz ─────────────────────────────────
    // Si el micro está silenciado se activa durante la grabación y se
    // restaura al terminar (igual que el dictado en shell.qml).
    readonly property var vcMicSource: Pipewire.ready ? Pipewire.defaultAudioSource : null

    PwObjectTracker {
        objects: root.vcMicSource ? [root.vcMicSource] : []
    }

    readonly property bool vcMicMuted: root.vcMicSource && root.vcMicSource.audio
        && typeof root.vcMicSource.audio.muted === "boolean" ? root.vcMicSource.audio.muted : false

    property bool _vcMicForcedOn: false

    // ── Grabación (mismo pipeline que el dictado) ───────────────
    Process {
        id: vcRecProc
        command: ["true"]
        running: false
    }

    // Recorte de silencio + transcripción en un solo paso (sh -c).
    Process {
        id: vcWorkProc
        command: ["sh", "-c", "true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._vcOnTranscript(text)
        }
    }

    // Lanzar apps / URLs (hyprctl dispatch exec).
    Process {
        id: vcExecProc
        command: ["true"]
        running: false
    }

    // Sonido de aviso al terminar (pw-play).
    Process {
        id: vcSoundProc
        command: ["true"]
        running: false
    }

    Timer {
        id: vcElapsedTimer
        interval: 500
        repeat: true
        onTriggered: {
            root._vcElapsedS++;
            root.vcElapsedText = root._vcFormatElapsed(root._vcElapsedS);
        }
    }

    Timer {
        id: vcHideTimer
        interval: 3200
        onTriggered: root.vcState = "idle"
    }

    // ── Servicios web conocidos (URL + alias) ───────────────────
    readonly property var vcServices: [
        { id: "youtube",   url: "https://youtube.com",       aliases: ["youtube", "yutu"] },
        { id: "musica",    url: "https://music.youtube.com", aliases: ["musica", "musik", "yt music"] },
        { id: "spotify",   url: "https://open.spotify.com",  aliases: ["spotify"] },
        { id: "google",    url: "https://google.com",        aliases: ["google", "google busqueda"] },
        { id: "maps",      url: "https://maps.google.com",   aliases: ["mapas", "maps", "google maps"] },
        { id: "whatsapp",  url: "https://web.whatsapp.com",  aliases: ["whatsapp", "wa"] },
        { id: "twitch",    url: "https://twitch.tv",         aliases: ["twitch"] },
        { id: "github",    url: "https://github.com",        aliases: ["github", "git hub"] },
        { id: "netflix",   url: "https://netflix.com",       aliases: ["netflix"] },
        { id: "prime",     url: "https://primevideo.com",    aliases: ["prime", "prime video", "amazon prime"] },
        { id: "disney",    url: "https://disneyplus.com",    aliases: ["disney", "disney plus"] },
        { id: "wikipedia", url: "https://es.wikipedia.org",  aliases: ["wikipedia"] },
        { id: "chatgpt",   url: "https://chat.openai.com",   aliases: ["chatgpt", "chat gpt"] },
        { id: "x",         url: "https://x.com",             aliases: ["x", "twitter"] },
        { id: "instagram", url: "https://instagram.com",     aliases: ["instagram"] },
        { id: "facebook",  url: "https://facebook.com",      aliases: ["facebook"] },
        { id: "tiktok",    url: "https://tiktok.com",        aliases: ["tiktok", "tik tok"] },
        { id: "reddit",    url: "https://reddit.com",        aliases: ["reddit"] },
        { id: "correo",    url: "https://mail.google.com",   aliases: ["correo", "mail", "gmail"] },
    ]

    function _vcFormatElapsed(s: int): string {
        var m = Math.floor(s / 60);
        var ss = (s % 60).toString();
        return m + ":" + (ss.length < 2 ? "0" : "") + ss;
    }

    // ── Script de grabación → recorte → transcripción ───────────
    function _vcScript(): string {
        var model = Settings.dictModelPath;
        if (model.indexOf("~/") === 0)
            model = "${HOME}/" + model.substring(2);
        model = model.replace(/"/g, '\\"');
        var lang = Settings.dictLang;
        var s = "SRC=/tmp/qs-voicecmd.wav; TGT=$SRC; MAXV=; ";
        s += "TGT=/tmp/qs-voicecmd-trim.wav; ";
        s += "ffmpeg -y -i $SRC -af \"silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.8:stop_periods='-1':stop_threshold=-45dB:stop_silence=0.5,volumedetect\" $TGT 2>/tmp/qs-voicecmd-vol.log || cp $SRC $TGT; ";
        s += "MAXV=`sed -n 's/.*max_volume: \\(-[0-9.]*\\) dB.*/\\1/p' /tmp/qs-voicecmd-vol.log`; ";
        s += "DUR=$(( `stat -c%s $TGT` / 32000 )); ";
        s += "if [ \"x$MAXV\" != x ] && awk -v v=\"$MAXV\" 'BEGIN{exit !(v < -45)}'; then ";
        s += "  echo ''; ";
        s += "elif [ \"$DUR\" -lt 1 ]; then ";
        s += "  echo ''; ";
        s += "else ";
        s += "  whisper-cli -m \"" + model + "\" -l \"" + lang + "\" -t 4 -nf -nt -np $TGT 2>/dev/null; ";
        s += "fi";
        return s;
    }

    // ── Flujo principal (toggle) ─────────────────────────────────
    function toggle(): void {
        if (root.vcState === "recording") {
            root.stop();
        } else if (root.vcState === "idle") {
            root.start();
        }
    }

    function start(): void {
        if (root.vcState !== "idle") return;
        if (vcWorkProc.running) return;
        root.vcResultText = "";
        root.vcResultNote = "";
        root._vcElapsedS = 0;
        root.vcElapsedText = "0:00";
        // Micro silenciado: activarlo durante la grabación y restaurarlo al
        // final (whisper recibe 0 bytes si el micro está muted).
        if (root.vcMicMuted && root.vcMicSource && root.vcMicSource.audio) {
            root.vcMicSource.audio.muted = false;
            root._vcMicForcedOn = true;
            root.vcResultNote = "Micro activado para el comando";
        }
        vcRecProc.command = ["pw-record", "--rate", "16000", "--channels", "1", "/tmp/qs-voicecmd.wav"];
        vcRecProc.running = true;
        root.vcState = "recording";
        vcElapsedTimer.start();
    }

    function stop(): void {
        if (root.vcState !== "recording") return;
        vcRecProc.running = false;
        vcElapsedTimer.stop();
        root.vcState = "thinking";
        root._vcRestoreMic();
        vcWorkProc.command = ["sh", "-c", root._vcScript()];
        vcWorkProc.running = true;
    }

    function cancel(): void {
        vcRecProc.running = false;
        vcElapsedTimer.stop();
        root.vcState = "idle";
        root._vcRestoreMic();
    }

    // Restaura el micro a su estado original si el comando lo forzó encendido.
    function _vcRestoreMic(): void {
        if (root._vcMicForcedOn && root.vcMicSource && root.vcMicSource.audio) {
            root.vcMicSource.audio.muted = true;
            root._vcMicForcedOn = false;
        }
    }

    // ── Sonido de aviso al terminar ──────────────────────────────
    function _vcPlaySound(file: string): void {
        vcSoundProc.command = ["pw-play", file];
        vcSoundProc.running = true;
    }

    // ── Transcripción → intención → ejecución ────────────────────
    function _vcOnTranscript(raw: string): void {
        var text = (raw || "").replace(/[ \t]*(\r?\n)[ \t]*/g, " ").replace(/\s+/g, " ").trim();
        if (text.length < 2) {
            root.vcResultNote = "No se detectó voz";
            root.vcState = "error";
            root._vcPlaySound("/usr/share/sounds/freedesktop/stereo/dialog-error.oga");
            vcHideTimer.restart();
            return;
        }
        root.vcResultText = text;
        var intent = root._vcParse(text);
        if (!intent) {
            root.vcResultNote = "No entendí el comando";
            root.vcState = "error";
            root._vcPlaySound("/usr/share/sounds/freedesktop/stereo/dialog-error.oga");
            vcHideTimer.restart();
            return;
        }
        root.vcState = "executing";
        var note = root._vcExecute(intent);
        root.vcResultNote = note || "Hecho";
        root.vcState = "done";
        root._vcPlaySound(Quickshell.shellPath("assets/dictation-success.wav"));
        vcHideTimer.restart();
    }

    // ── Normaliza el texto (minúsculas + sin acentos) ────────────
    function _vcNorm(t: string): string {
        return (t || "").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    }

    // ── Distancia de edición (Levenshtein) para match difuso ─────
    // whisper a veces transcribe distinto ("brave" → "breiv"/"braiv");
    // con distancia ≤ 1 se tolera esa variación sin falsos positivos.
    function _vcEditDist(a: string, b: string): int {
        var m = a.length, n = b.length;
        if (m === 0) return n;
        if (n === 0) return m;
        var prev = new Array(n + 1);
        var cur = new Array(n + 1);
        for (var j = 0; j <= n; j++) prev[j] = j;
        for (var i = 1; i <= m; i++) {
            cur[0] = i;
            for (var j = 1; j <= n; j++) {
                var cost = a[i - 1] === b[j - 1] ? 0 : 1;
                cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost);
            }
            var tmp = prev; prev = cur; cur = tmp;
        }
        return prev[n];
    }

    // Match difuso de una palabra contra un objetivo: exacto, substring o
    // con distancia de edición pequeña (≤1 para palabras de 3+ letras).
    function _vcFuzzyMatch(word: string, target: string): bool {
        var w = root._vcNorm(word);
        var t = root._vcNorm(target);
        if (!w || !t) return false;
        if (t === w) return true;
        if (t.indexOf(w) !== -1 || w.indexOf(t) !== -1) return true;
        if (w.length >= 4)
            return root._vcEditDist(w, t) <= 2;
        if (w.length === 3)
            return root._vcEditDist(w, t) <= 1;
        return false;
    }

    // Match difuso contra cada palabra de un nombre compuesto
    // ("Brave Browser" se reconoce aunque se diga solo "breiv").
    function _vcFuzzyTokens(word: string, target: string): bool {
        if (root._vcFuzzyMatch(word, target)) return true;
        var tokens = root._vcNorm(target).split(" ");
        for (var i = 0; i < tokens.length; i++)
            if (root._vcFuzzyMatch(word, tokens[i]))
                return true;
        return false;
    }

    // ── Busca un servicio web por nombre (o alias) ───────────────
    function _vcService(word: string) {
        var w = root._vcNorm(word).trim();
        if (!w) return null;
        for (var i = 0; i < root.vcServices.length; i++) {
            var svc = root.vcServices[i];
            if (root._vcFuzzyMatch(w, svc.id))
                return svc;
            for (var j = 0; j < svc.aliases.length; j++) {
                if (root._vcFuzzyMatch(w, svc.aliases[j]))
                    return svc;
            }
        }
        return null;
    }

    // ── Busca un navegador por palabra ───────────────────────────
    // Variantes que whisper puede producir al oír "brave" (palabra inglesa
    // dentro de una frase en español) + sinónimos de "navegador".
    readonly property var vcBraveWords: [
        "brave", "breiv", "braiv", "brayve", "breve", "braf", "braib", "braif",
        "navegador", "navegadores", "browser", "browsers", "explorador",
    ]

    function _vcIsBrave(word: string): bool {
        var w = root._vcNorm(word);
        if (!w) return false;
        for (var i = 0; i < root.vcBraveWords.length; i++)
            if (root._vcNorm(root.vcBraveWords[i]) === w)
                return true;
        return root._vcFuzzyTokens(w, "brave");
    }

    function _vcBrowser(word: string): string {
        return root._vcIsBrave(word) ? "brave" : "";
    }

    // ── Busca una app instalada por nombre (DesktopEntries) ──────
    function _vcFindApp(name: string) {
        var q = root._vcNorm(name);
        if (!q) return null;
        var apps = DesktopEntries.applications.values;
        var best = null;
        for (var i = 0; i < apps.length; i++) {
            var app = apps[i];
            if (!app || !app.name) continue;
            var n = root._vcNorm(app.name);
            if (n === q)
                return app;
            if (!best && (n.indexOf(q) !== -1 || q.indexOf(n) !== -1))
                best = app;
            else if (!best && root._vcFuzzyTokens(q, n))
                best = app;
        }
        return best;
    }

    // ── Traduce el texto a una intención ─────────────────────────
    function _vcParse(raw: string) {
        var t = root._vcNorm(raw).replace(/\s+/g, " ").trim();
        if (!t) return null;

        // ── Control de medios / volumen ──────────────────────────
        if (/^(pausa|pausar|para|deten)\b/.test(t))
            return { type: "pause" };
        if (/^(reproduce|reanuda|continua|sigue)\b/.test(t))
            return { type: "play" };
        if (/^(siguiente|adelante)\b/.test(t))
            return { type: "next" };
        if (/^(anterior|atras)\b/.test(t))
            return { type: "prev" };
        if (t.indexOf("volumen") !== -1 || /(silenc|mute|muto)/.test(t)) {
            // Nivel exacto: "sube el volumen a 100", "baja el volumen a 75",
            // "volumen al máximo/mínimo".
            var mset = t.match(/volumen (?:a|al) (\d{1,3})/);
            if (mset)
                return { type: "volSet", level: parseInt(mset[1], 10) };
            if (/(maximo|tope|max)\b/.test(t) && t.indexOf("volumen") !== -1)
                return { type: "volSet", level: 100 };
            if (/(minimo|min)\b/.test(t) && t.indexOf("volumen") !== -1)
                return { type: "volSet", level: 0 };
            if (/(sube|aumenta|mas)\b/.test(t) && t.indexOf("volumen") !== -1)
                return { type: "volUp" };
            if (/(baja|rebaja|menos)\b/.test(t) && t.indexOf("volumen") !== -1)
                return { type: "volDown" };
            if (/(silenc|mute|muto)/.test(t))
                return { type: "mute" };
        }

        // ── "coloca/pon música [en <servicio>]" ──────────────────
        if (/(coloca|pon|dale|reproduce) musica/.test(t) || /^(ponme|pon) musica\b/.test(t)) {
            var mms = t.match(/en (\S+)/);
            if (mms) {
                var msvc = root._vcService(mms[1]);
                if (msvc)
                    return { type: "open", url: msvc.url };
            }
            return { type: "open", url: "https://music.youtube.com" };
        }

        // ── "abre X en Y" (un servicio y un navegador) ───────────
        var m = t.match(/^abre (?:la )?(.+?) en (.+)$/);
        if (m) {
            var a = m[1].trim(), b = m[2].trim();
            var sa = root._vcService(a), sb = root._vcService(b);
            var ba = root._vcBrowser(a), bb = root._vcBrowser(b);
            if (sa && bb) return { type: "open", url: sa.url, browser: bb };
            if (sb && ba) return { type: "open", url: sb.url, browser: ba };
            if (sa) return { type: "open", url: sa.url };
            if (sb) return { type: "open", url: sb.url };
        }

        // ── "abre <algo>" → app, navegador o servicio ────────────────
        var mm = t.match(/^(abre|abrir|abra|abrime|abreme|inicia|lanza|ejecuta|open)\b\s*(.*)$/);
        if (mm) {
            var rest = mm[2].replace(/^(la|el|una|un)\s+/, "");
            var svc2 = root._vcService(rest);
            if (svc2) return { type: "open", url: svc2.url };
            // Navegador: "abra brave", "abre navegador", "abra el browser"
            // (whisper puede transcribir "brave" de varias formas).
            if (root._vcIsBrave(rest)) {
                var bapp = root._vcFindApp("brave");
                if (bapp) return { type: "app", app: bapp };
                return { type: "browser" };
            }
            var app = root._vcFindApp(rest);
            if (app) return { type: "app", app: app };
        }

        // ── Servicio suelto ("youtube", "musica"…) ───────────────
        var solo = root._vcService(t);
        if (solo) return { type: "open", url: solo.url };

        return null;
    }

    // ── Ejecuta la intención y devuelve la nota de resultado ─────
    function _vcExecute(intent: var): string {
        if (intent.type === "app" && intent.app) {
            intent.app.execute();
            return "Abriendo " + intent.app.name;
        }
        if (intent.type === "browser") {
            vcExecProc.command = ["sh", "-c", "hyprctl dispatch exec brave"];
            vcExecProc.running = true;
            return "Abriendo Brave";
        }
        if (intent.type === "open") {
            var browser = intent.browser || "brave";
            var url = intent.url.replace(/"/g, "");
            vcExecProc.command = ["sh", "-c", "hyprctl dispatch exec " + browser + " \"" + url + "\""];
            vcExecProc.running = true;
            return "Abriendo " + browser + " → " + url.replace(/^https?:\/\//, "");
        }

        var player = Settings.findActiveMprisPlayer();
        if (intent.type === "pause") {
            if (player) player.pause();
            return player ? "Música en pausa" : "No hay reproductor activo";
        }
        if (intent.type === "play") {
            if (player) player.play();
            return player ? "Reproduciendo" : "No hay reproductor activo";
        }
        if (intent.type === "next") {
            if (player) player.next();
            return player ? "Siguiente canción" : "No hay reproductor activo";
        }
        if (intent.type === "prev") {
            if (player) player.previous();
            return player ? "Canción anterior" : "No hay reproductor activo";
        }

        var sink = Pipewire.ready ? Pipewire.defaultAudioSink : null;
        if (intent.type === "volSet") {
            var target = Math.max(0, Math.min(100, intent.level));
            if (sink && sink.audio)
                sink.audio.volume = target / 100;
            return sink ? "Volumen: " + target + "%" : "Sin salida de audio";
        }
        if (intent.type === "volUp") {
            if (sink && sink.audio)
                sink.audio.volume = Math.min(1, sink.audio.volume + 0.05);
            return sink ? "Volumen: " + Math.round(sink.audio.volume * 100) + "%" : "Sin salida de audio";
        }
        if (intent.type === "volDown") {
            if (sink && sink.audio)
                sink.audio.volume = Math.max(0, sink.audio.volume - 0.05);
            return sink ? "Volumen: " + Math.round(sink.audio.volume * 100) + "%" : "Sin salida de audio";
        }
        if (intent.type === "mute") {
            if (sink && sink.audio)
                sink.audio.muted = !sink.audio.muted;
            return sink && sink.audio.muted ? "Silencio activado" : "Sonido activado";
        }

        return null;
    }

    VoiceCommandOsd {
        id: osd
        vcState: root.vcState
        elapsedText: root.vcElapsedText
        resultText: root.vcResultText
        resultNote: root.vcResultNote
        micForcedOn: root._vcMicForcedOn
        onStopRequested: root.stop()
        onCancelRequested: root.cancel()
    }

    IpcHandler {
        target: "voicecmd"
        function toggle(): void { root.toggle(); }
        function stop(): void { root.stop(); }
        function cancel(): void { root.cancel(); }
    }
}