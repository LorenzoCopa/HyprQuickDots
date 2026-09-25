//@ pragma UseQApplication
//@ pragma IconTheme Papirus
//@ pragma DefaultEnv QT_LOGGING_RULES = qt.qpa.services.warning=false
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Networking
import "launcher"
import "bar"
import "quickaccess"
import "screenshot"
import "config"
import "settings"
import "lock"
import "idle"
import "wallpaper"
import "clipboard"
import "polkit"
import "notifications"
import "osd"
import "dictation"
import "wlogout"
import "colorpicker"
import "voicecommand"
import "deps"

Scope {
    id: root

    PolkitAgent {}

    // ── Host de notificaciones (compartido barra + launcher) ────
    // Vive en la raíz para que las notificaciones se reciban aunque la
    // barra esté en "none". La barra y el launcher lo consumen por
    // propiedades.
    NotificationServer {
        id: notifServer
        actionsSupported: true
        onNotification: function(notification) {
            notification.tracked = true;
            root.allNotifs.push(notification);
            if (!root.dndEnabled) {
                root.activeNotif = notification;
                floatTimer.restart();
            }
        }
    }

    property bool dndEnabled: false
    property bool autoDnd: false
    property var activeNotif: null
    property var allNotifs: []

    Timer {
        id: floatTimer
        interval: 4000
        onTriggered: root.activeNotif = null
    }

    function clearAll() {
        for (let i = 0; i < root.allNotifs.length; i++) {
            let n = root.allNotifs[i];
            if (n) n.tracked = false;
        }
        root.allNotifs = [];
        root.activeNotif = null;
        floatTimer.stop();
    }

    // Descarta el toast flotante (lo usa la notificación emergente de raíz).
    function dismissFloating(): void {
        root.activeNotif = null;
    }

    function toggleDnd() {
        root.dndEnabled = !root.dndEnabled;
        root.autoDnd = false;
        if (root.dndEnabled) {
            root.activeNotif = null;
            floatTimer.stop();
        }
    }

    function autoDndOn() {
        root.autoDnd = true;
        root.dndEnabled = true;
        root.activeNotif = null;
        floatTimer.stop();
    }

    function autoDndOff() {
        if (!root.autoDnd) return;
        root.autoDnd = false;
        root.dndEnabled = false;
    }

    Launcher {}

    AppBrowser {}

    QuickAccess {
        id: quickAccess
        notifModel: notifServer.trackedNotifications
        dndEnabled: root.dndEnabled
        onToggleDnd: root.toggleDnd
        onClearAll: root.clearAll
        onOpenSettings: function() { settingsWindow.toggle(); }
        onScreenshot: function() { if (Settings.screenshotManager) Settings.screenshotManager.requestModeSelector(); }
        onLockScreen: function() { sessionLock.lock(); }
        onToggleWlogout: function() { root.showWlogoutOverlay = true; }
        onVisibleChanged: if (visible) root._pollPowerProfile()
    }

    SettingsWindow {
        id: settingsWindow
    }

    WallpaperPicker {}

    ClipboardManager {}

    SessionLock {
        id: sessionLock
    }

    // Barra que está viva ahora mismo (puede diferir de la seleccionada
    // en Settings.barType hasta que se pulse "Aplicar").
    // barStateReady evita instanciar la barra antes de leer barstate.json:
    // al recargar en caliente no debe parpadear la barra de arriba.
    property string appliedBarType: "evergarden"
    property bool barStateReady: false

    Loader {
        id: barLoader
        sourceComponent: !barStateReady || appliedBarType === "none" ? null : barEvergarden
    }

    Component {
        id: barEvergarden
        Bar {
            toggleWlogout: function() { showWlogoutOverlay = !showWlogoutOverlay; }
            notifModel: notifServer.trackedNotifications
            dndEnabled: root.dndEnabled
            onToggleDnd: root.toggleDnd
            onClearAll: root.clearAll
            onAutoDndOn: root.autoDndOn
            onAutoDndOff: root.autoDndOff
            nightLightEnabled: root.nightLightEnabled
            nightLightTemp: root.nightLightTemp
            onNightLightChange: root.setNightLight
        }
    }

    // Wlogout es un overlay global, no depende de la barra: vive en la
    // raíz para que SUPER+SHIFT+X funcione aunque la barra esté en "none".
    property bool showWlogoutOverlay: false

    WlogoutOverlay {
        visible: root.showWlogoutOverlay
        onCloseRequested: root.showWlogoutOverlay = false
        onLockScreen: function() { sessionLock.lock(); }
    }

    IpcHandler {
        target: "wl-toggle"
        function toggleWlogout(): void { root.showWlogoutOverlay = !root.showWlogoutOverlay; }
        function showWlogout(): void { root.showWlogoutOverlay = true; }
        function hideWlogout(): void { root.showWlogoutOverlay = false; }
    }

    IdleManager {
        id: idleManager
        sessionLock: sessionLock
    }

    ScreenshotManager {
        id: screenshotManager
        depsChecker: dependencyCheck
    }

    ColorPicker {}

    VoiceCommand {}

    VolumeOsd {}
    BrightnessOsd {}

    // ── Dictado por voz (whisper.cpp) ────────────────────────────
    // Vive en la raíz (no en la barra) y funciona con la barra en "none".
    // Flujo: pulsa SUPER+D → se graba con pw-record a un wav (16 kHz mono,
    // la fuente por defecto es rnnoise_source, ya con cancelación de ruido);
    // vuelve a pulsar (o botón "Listo") → se recorta el silencio con ffmpeg
    // y se transcribe con whisper-cli (GPU Vulkan). El texto SIEMPRE se copia
    // al portapapeles (queda en cliphist como fallback) y, si hay una ventana
    // real enfocada, se pega con `hyprctl dispatch sendshortcut CTRL+V`.
    // El OSD es una superficie layer (qs-dictation): NO roba el foco, así que
    // la app objetivo conserva el foco durante todo el dictado.
    property string dictState: "idle"        // idle|recording|transcribing|done|error
    property string dictElapsedText: "0:00"
    property string dictResultText: ""
    property string dictResultNote: ""
    property int _dictElapsedS: 0

    // ── Micro del dictado ────────────────────────────────────────
    // Si el micro está silenciado al empezar a grabar se activa durante la
    // grabación (sin eso whisper no oiría nada) y se restaura al terminar.
    // El estado real vive en `source.audio` (válido tras enlazar con
    // PwObjectTracker, mismo patrón que MicSection.qml).
    readonly property var dictMicSource: Pipewire.ready ? Pipewire.defaultAudioSource : null

    PwObjectTracker {
        objects: root.dictMicSource ? [root.dictMicSource] : []
    }

    readonly property bool dictMicMuted: root.dictMicSource && root.dictMicSource.audio
        && typeof root.dictMicSource.audio.muted === "boolean" ? root.dictMicSource.audio.muted : false

    // true si el dictado forzó el micro encendido y toca restaurarlo.
    property bool _dictMicForcedOn: false

    FileView {
        id: dictStateFile
        path: Qt.resolvedUrl("dictate.json")
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: dictState
            property string modelPath: "~/.local/share/dictation/models/ggml-medium-q8_0.bin"
            property string lang: "auto"
            property bool trimSilence: true
            property bool pasteFocused: true
            property bool soundOnFinish: true
        }
    }

    // Graba desde la fuente por defecto. pw-record finaliza el WAV al recibir
    // SIGTERM (cuando se pone running = false), que es lo que lee ffmpeg.
    Process {
        id: dictRecProc
        command: ["true"]
        running: false
    }

    // Recorte de silencio + transcripción en un solo paso (sh -c): recorta el
    // silencio inicial/final (evita que whisper "alucine" frases sobre
    // silencio), descarta la grabación sin voz (max_volume < -45 dB o menos de
    // 1s) y al final imprime el texto transcrito por stdout.
    Process {
        id: dictWorkProc
        command: ["sh", "-c", "true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._dictOnTranscript(text)
        }
    }

    // Copia el texto al portapapeles (siempre). Se inicia en detached para que
    // wl-copy siga vivo sosteniendo la selección aunque el Process termine.
    Process {
        id: dictCopyProc
        command: ["true"]
        running: false
    }

    // Pega con Ctrl+V en la ventana enfocada (sendshortcut de Hyprland). El
    // pequeño retardo da tiempo a que wl-copy publique la selección.
    Process {
        id: dictPasteProc
        command: ["true"]
        running: false
    }

    // Sonido de aviso al terminar la transcripción (pw-play). Se dispara con
    // _dictPlaySound: complete.oga en éxito, dialog-error.oga si no hay voz.
    Process {
        id: dictSoundProc
        command: ["true"]
        running: false
    }

    Timer {
        id: dictElapsedTimer
        interval: 500
        repeat: true
        onTriggered: {
            root._dictElapsedS++;
            root.dictElapsedText = root._dictFormatElapsed(root._dictElapsedS);
        }
    }

    Timer {
        id: dictHideTimer
        interval: 2800
        onTriggered: root.dictState = "idle"
    }

    function _dictFormatElapsed(s: int): string {
        var m = Math.floor(s / 60);
        var ss = (s % 60).toString();
        return m + ":" + (ss.length < 2 ? "0" : "") + ss;
    }

    function _dictScript(): string {
        var trim = Settings.dictTrimSilence;
        // El path puede venir como `~/...`; dentro del sh hay que expandirlo
        // (en comillas dobles `~` no se expande) y escapar comillas por si
        // acaso. El idioma es un código fijo ("es", "en", "auto").
        var model = Settings.dictModelPath;
        if (model.indexOf("~/") === 0)
            model = "${HOME}/" + model.substring(2);
        model = model.replace(/"/g, '\\"');
        var lang = Settings.dictLang;
        var s = "SRC=/tmp/qs-dictation.wav; TGT=$SRC; MAXV=; ";
        if (trim) {
            s += "TGT=/tmp/qs-dictation-trim.wav; ";
            // Una sola pasada de ffmpeg: recorta el silencio inicial y final a la
            // vez (stop_periods='-1' evita el doble areverse; las comillas en el
            // filtro son necesarias o ffmpeg falla al parsear el valor -1) y mide
            // el volumen de la señal recortada. stderr va a un log para extraer
            // max_volume. El -af va con comillas dobles para que las comillas
            // simples del filtro sobrevivan al `sh -c` del script.
            s += "ffmpeg -y -i $SRC -af \"silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.8:stop_periods='-1':stop_threshold=-45dB:stop_silence=0.5,volumedetect\" $TGT 2>/tmp/qs-dict-vol.log || cp $SRC $TGT; ";
            s += "MAXV=`sed -n 's/.*max_volume: \\(-[0-9.]*\\) dB.*/\\1/p' /tmp/qs-dict-vol.log`; ";
        } else {
            s += "MAXV=`ffmpeg -i $TGT -af volumedetect -f null - 2>&1 | sed -n 's/.*max_volume: \\(-[0-9.]*\\) dB.*/\\1/p'`; ";
        }
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

    function dictationToggle(): void {
        if (root.dictState === "recording") {
            root.stopDictation();
        } else if (root.dictState === "idle") {
            root.startDictation();
        }
    }

    function startDictation(): void {
        if (root.dictState !== "idle") return;
        if (dictWorkProc.running) return;
        root.dictResultText = "";
        root.dictResultNote = "";
        root._dictElapsedS = 0;
        root.dictElapsedText = "0:00";
        // Micro silenciado: activarlo durante la grabación y restaurarlo al
        // final (whisper recibe 0 bytes si el micro está muted).
        if (root.dictMicMuted && root.dictMicSource && root.dictMicSource.audio) {
            root.dictMicSource.audio.muted = false;
            root._dictMicForcedOn = true;
            root.dictResultNote = "Micro activado para el dictado";
        }
        dictRecProc.command = ["pw-record", "--rate", "16000", "--channels", "1", "/tmp/qs-dictation.wav"];
        dictRecProc.running = true;
        root.dictState = "recording";
        dictElapsedTimer.start();
    }

    function stopDictation(): void {
        if (root.dictState !== "recording") return;
        dictRecProc.running = false;
        dictElapsedTimer.stop();
        root.dictState = "transcribing";
        // Termina la grabación: restaurar el micro si lo forzamos encendido.
        root._dictRestoreMic();
        dictWorkProc.command = ["sh", "-c", root._dictScript()];
        dictWorkProc.running = true;
    }

    function cancelDictation(): void {
        dictRecProc.running = false;
        dictElapsedTimer.stop();
        root.dictState = "idle";
        root._dictRestoreMic();
    }

    // Restaura el micro a su estado original si el dictado lo forzó encendido.
    function _dictRestoreMic(): void {
        if (root._dictMicForcedOn && root.dictMicSource && root.dictMicSource.audio) {
            root.dictMicSource.audio.muted = true;
            root._dictMicForcedOn = false;
        }
    }

    // Sonido de aviso al terminar (solo si está activado en Ajustes).
    function _dictPlaySound(file: string): void {
        if (!Settings.dictSoundOnFinish) return;
        dictSoundProc.command = ["pw-play", file];
        dictSoundProc.running = true;
    }

    function _dictOnTranscript(raw: string): void {
        var text = (raw || "").replace(/[ \t]*(\r?\n)[ \t]*/g, " ").replace(/\s+/g, " ").trim();
        if (text.length < 2) {
            root.dictResultNote = "No se detectó voz";
            root.dictState = "error";
            root._dictPlaySound("/usr/share/sounds/freedesktop/stereo/dialog-error.oga");
            dictHideTimer.restart();
            return;
        }
        root.dictResultText = text;
        root.dictResultNote = "";
        // Copiar SIEMPRE al portapapeles (queda en cliphist como fallback).
        dictCopyProc.command = ["wl-copy", text];
        dictCopyProc.startDetached();
        // Pegar solo si hay una ventana real enfocada (no una qs-* ni el
        // escritorio); si no, se queda en el portapapeles.
        var canPaste = Settings.dictPasteFocused;
        var tl = Hyprland.activeToplevel;
        var title = tl ? (tl.title || "") : "";
        if (canPaste && title && title.toString().indexOf("qs-") !== 0 && title.toString().trim() !== "") {
            dictPasteProc.command = ["sh", "-c", "sleep 0.15; hyprctl dispatch 'hl.dsp.send_shortcut({ mods = \"CTRL\", key = \"V\" })'"];
            dictPasteProc.running = true;
            root.dictResultNote = "Insertado en " + title.toString();
        } else {
            root.dictResultNote = "Copiado al portapapeles";
        }
        root.dictState = "done";
        root._dictPlaySound(Quickshell.shellPath("assets/dictation-success.wav"));
        dictHideTimer.restart();
    }

    DictationOsd {
        dictState: root.dictState
        elapsedText: root.dictElapsedText
        resultText: root.dictResultText
        resultNote: root.dictResultNote
        micForcedOn: root._dictMicForcedOn
        onStopRequested: root.stopDictation()
        onCancelRequested: root.cancelDictation()
    }

    IpcHandler {
        target: "dictation"
        function toggle(): void { root.dictationToggle(); }
        function stop(): void { root.stopDictation(); }
        function cancel(): void { root.cancelDictation(); }
    }

    // ── Notificación emergente (toast) ──────────────────────────────
    // Vive en la raíz (no en la barra) para que aparezca también con la
    // barra en "none". Se muestra/oculta según root.activeNotif (gestionado
    // por el NotificationServer + floatTimer de arriba).
    NotificationToast {
        activeNotif: root.activeNotif
        onDismiss: root.dismissFloating
    }

    // ── Verificador de dependencias ───────────────────────────────
    // Comprueba al arrancar (y con `qs ipc call deps check` / Reintentar)
    // que existan los binarios que cada apartado del shell necesita. Si
    // falta algo se muestra el toast con el comando de instalación
    // (sudo pacman -S ...) en lugar de dejar la feature rota en silencio.
    property bool showDepsToast: false

    DependencyCheck {
        id: dependencyCheck

        onChecked: root.showDepsToast = dependencyCheck.missing.length > 0
        onRequestNotify: function(missingDeps) {
            if (missingDeps.length > 0) root.showDepsToast = true;
        }
    }

    DepsToast {
        visible: root.showDepsToast
        missing: dependencyCheck.missing
        onDismiss: root.showDepsToast = false
        onRetry: dependencyCheck.check
    }

    IpcHandler {
        target: "deps"
        function check(): void { dependencyCheck.check(); }
    }

    // Barra activa: se persiste en barstate.json (archivo aparte de
    // state.json para no pisar las claves que escribe el popup de reloj).
    FileView {
        id: barStateFile
        path: Qt.resolvedUrl("barstate.json")

        JsonAdapter {
            id: barState
            property string barType: "evergarden"
        }
    }

    // Tiempos de inactividad (bloqueo/suspensión): se persisten en
    // idlestate.json y se aplican al IdleManager desde onCompleted.
    FileView {
        id: idleStateFile
        path: Qt.resolvedUrl("idlestate.json")

        JsonAdapter {
            id: idleState
            property int idleLockMin: 8
            property int idleSuspendMin: 10
        }
    }

    // ── Luz nocturna (hyprsunset) ──────────────────────────────────
    // Vive en la raíz para que funcione aunque la barra esté en "none".
    // El estado se persiste en nightstate.json; la barra (popup del
    // reloj) y la sección de ajustes controlan lo mismo vía setNightLight.
    property bool nightLightEnabled: false
    property int nightLightTemp: 3500

    FileView {
        id: nightStateFile
        path: Qt.resolvedUrl("nightstate.json")
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: nightState
            property bool nightLightEnabled: false
            property int nightLightTemp: 3500
        }
    }

    Process {
        id: nlKillProc
        // Matar hyprsunset y borrar sockets stale. hyprsunset ignora SIGTERM
        // (no muere con pkill normal), así que hay que forzar con -9; al
        // morir así no limpia su .hyprsunset.sock, y la siguiente instancia
        // no podría enlazar el mismo path (EEXIST) quedando su listener
        // inalcanzable. Por eso el rm después del kill.
        command: ["sh", "-c", "pkill -9 -x hyprsunset; rm -f /run/user/*/hypr/*/.hyprsunset.sock"]
        running: false
    }

    Process {
        id: nlStartProc
        command: ["true"]
        running: false
    }

    // ── Daemon persistente de temperatura ──────────────────────────
    // Mantiene UNA conexión abierta al socket de hyprsunset. Lee líneas
    // por stdin (cada una es una temperatura) y las envía al socket. Así
    // el preview del slider es instantáneo: no se lanza un python por
    // movimiento, solo un write al stdin del proceso.
    //
    // PEREZOSO: el proceso solo vive mientras la luz nocturna está
    // encendida (`running` ligado a nightLightEnabled). Antes corría para
    // siempre aunque la luz estuviera apagada (~12 MB de un python
    // residente sin trabajo). Al encenderse la luz el binding lo arranca;
    // al apagarla muere con él.
    readonly property string nlDaemonScript:
        "import socket,glob,os,sys,time\n" +
        "def sock():\n" +
        "    while True:\n" +
        "        for p in sorted(glob.glob('/run/user/*/hypr/*/.hyprsunset.sock'), key=os.path.getmtime, reverse=True):\n" +
        "            try:\n" +
        "                s=socket.socket(socket.AF_UNIX); s.connect(p); s.settimeout(2); return s\n" +
        "            except OSError:\n" +
        "                pass\n" +
        "        time.sleep(0.1)\n" +
        "s=sock()\n" +
        "for line in sys.stdin:\n" +
        "    line=line.strip()\n" +
        "    if not line: continue\n" +
        "    while True:\n" +
        "        try:\n" +
        "            s.send(('temperature '+line).encode()); s.recv(1024); break\n" +
        "        except OSError:\n" +
        "            try: s.close()\n" +
        "            except Exception: pass\n" +
        "            s=sock()\n"

    Process {
        id: nlTempDaemon
        command: ["python3", "-u", "-c", root.nlDaemonScript]
        running: root.nightLightEnabled
        stdinEnabled: true
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.log("nlTempDaemon stderr:", text.trim());
            }
        }
    }

    // Preview en vivo: al deslizar el slider de la sección de ajustes (solo
    // si la luz nocturna está encendida) se aplica la temperatura al
    // instante escribiendo al daemon. Sin debounce: el write es barato.

    // Arranque de hyprsunset: primero se mata cualquier instancia previa y
    // se espera un instante para que el pkill no mate la instancia recién
    // creada (evita el race que dejaba el filtro sin aplicar).
    property int _startTemp: 3500

    Timer {
        id: nlStartTimer
        interval: 250
        onTriggered: {
            nlStartProc.running = false;
            nlStartProc.command = ["sh", "-c", "nohup hyprsunset -t " + root._startTemp + " >/dev/null 2>&1 &"];
            nlStartProc.running = true;
        }
    }

    function _startHyprsunset(temp: int): void {
        root._startTemp = temp;
        nlKillProc.running = true;
        nlStartTimer.restart();
    }

    function _setTempLive(temp: int): void {
        // Si el daemon aún no arrancó (luz recién encendida, exec del python
        // en curso), no hay nada a lo que escribirle: la temperatura ya fue
        // aplicada al spawn de hyprsunset y el siguiente movimiento del
        // slider ya encuentra el daemon listo.
        if (!nlTempDaemon.running)
            return;
        nlTempDaemon.write(String(temp) + "\n");
    }

    function previewNightLightTemp(temp: int): void {
        if (!root.nightLightEnabled)
            return;
        root.nightLightTemp = temp;
        root._setTempLive(temp);
    }

    function setNightLight(enabled: bool, temp: int): void {
        var wasEnabled = root.nightLightEnabled;
        root.nightLightEnabled = enabled;
        root.nightLightTemp = temp;
        nightState.nightLightEnabled = enabled;
        nightState.nightLightTemp = temp;
        nightStateFile.writeAdapter();
        if (enabled && !wasEnabled) {
            // Encendido: matar la instancia previa y arrancar con la
            // temperatura actual (con retardo para evitar el race).
            root._startHyprsunset(temp);
        } else if (enabled) {
            // Ya encendido: cambiar temperatura en caliente por el daemon.
            root._setTempLive(temp);
        } else {
            // Apagado.
            nlKillProc.running = true;
        }
    }

    // ── Modo de energía (power-profiles-daemon) ─────────────────
    // Perfil activo (performance / balanced / power-saver). La fuente de
    // verdad es el daemon: se aplica con `powerprofilesctl set` y se
    // sincroniza con un poll ligero para reflejar también cambios
    // externos. Se persiste la última selección en powerstate.json.
    // QuickAccess y la sección de ajustes solo leen
    // Settings.powerProfile y llaman Settings.setPowerProfile.
    property string powerProfile: "balanced"
    property string _powerPending: ""

    FileView {
        id: powerStateFile
        path: Qt.resolvedUrl("powerstate.json")
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: powerState
            property string powerProfile: "balanced"
        }
    }

    // Consulta el perfil activo del daemon (powerprofilesctl get).
    Process {
        id: powerGetProc
        command: ["true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim();
                if (p)
                    root._onPowerGot(p);
            }
        }
    }

    // Aplica un perfil con `powerprofilesctl set`.
    Process {
        id: powerSetProc
        command: ["true"]
        running: false
        onExited: function(code) {
            // Al terminar (aunque falle) se limpia la marca de pendiente
            // y se re-consulta para quedarse con el estado real del daemon.
            root._powerPending = "";
            root._pollPowerProfile();
        }
    }

    function _pollPowerProfile(): void {
        if (powerGetProc.running)
            return;
        powerGetProc.command = ["powerprofilesctl", "get"];
        powerGetProc.running = true;
    }

    function _onPowerGot(profile: string): void {
        if (root._powerPending === profile)
            root._powerPending = "";
        if (root._powerPending)
            return;
        if (root.powerProfile === profile)
            return;
        root.powerProfile = profile;
        Settings.powerProfile = profile;
        powerState.powerProfile = profile;
        powerStateFile.writeAdapter();
    }

    function setPowerProfile(profile: string): void {
        if (profile === root.powerProfile)
            return;
        root._powerPending = profile;
        powerSetProc.command = ["powerprofilesctl", "set", profile];
        powerSetProc.running = true;
    }

    // Poll ligero para reflejar cambios externos: solo consulta mientras
    // QuickAccess o Ajustes estén abiertos (no consume nada en segundo
    // plano). Al terminar un set se re-consulta igualmente.
    Timer {
        id: powerPollTimer
        interval: 1000
        repeat: true
        running: quickAccess.visible || settingsWindow.visible
        onTriggered: root._pollPowerProfile()
    }

    // ── Hardware adaptativo (brillo/batería/wifi) ─────────────
    // Si no hay hardware, el tile/slider/panel no se crea: visible:false
    // y height 0 (no opaco, no deja hueco). La detección es al arrancar.
    property int brightness: 50

    Process {
        id: brightDetectProc
        command: ["sh", "-c", "ls /sys/class/backlight/* >/dev/null 2>&1 && echo yes || echo no"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const has = text.trim() === "yes";
                root.brightness = has ? root.brightness : 50;
                Settings.hasBrightness = has;
                if (has) brightPollProc.running = true;
            }
        }
    }
    Process {
        id: brightGetProc
        command: ["sh", "-c", "brightnessctl -c backlight g 2>/dev/null || cat /sys/class/backlight/*/brightness 2>/dev/null | head -n1"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim(), 10);
                if (!isNaN(v)) {
                    // Normalizar a 0-100: si brightnessctl da valor bruto, usar max
                    brightMaxProc.running = true;
                    root._brightRaw = v;
                }
            }
        }
    }
    property int _brightRaw: 0
    Process {
        id: brightMaxProc
        command: ["sh", "-c", "brightnessctl -c backlight m 2>/dev/null || cat /sys/class/backlight/*/max_brightness 2>/dev/null | head -n1"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const max = parseInt(text.trim(), 10);
                if (!isNaN(max) && max > 0) {
                    const pct = Math.round(root._brightRaw * 100 / max);
                    root.brightness = Math.max(0, Math.min(100, pct));
                    Settings.brightness = root.brightness;
                }
            }
        }
    }
    Process {
        id: brightSetProc
        command: ["true"]
        running: false
        onExited: brightGetProc.running = true
    }
    Process {
        id: brightPollProc
        command: ["true"]
        running: false
    }
    Timer {
        id: brightPollTimer
        interval: 1200
        repeat: true
        running: Settings.hasBrightness && (quickAccess.visible || settingsWindow.visible)
        onTriggered: if (!brightGetProc.running && !brightSetProc.running) brightGetProc.running = true
    }
    function setBrightness(pct: int): void {
        const v = Math.max(0, Math.min(100, pct));
        root.brightness = v;
        Settings.brightness = v;
        // brightnessctl si existe, si no escribe directo a /sys (requiere permiso, pero se intenta)
        brightSetProc.command = ["sh", "-c", "brightnessctl -c backlight set " + v + "% >/dev/null 2>&1 || ( p=$(ls /sys/class/backlight/* 2>/dev/null | head -n1); [ -n \"$p\" ] && m=$(cat $p/max_brightness); echo $((m*" + v + "/100)) | tee $p/brightness >/dev/null 2>&1 )"];
        brightSetProc.running = true;
    }
    Process {
        id: batteryDetectProc
        command: ["sh", "-c", "ls /sys/class/power_supply/BAT* >/dev/null 2>&1 && echo yes || echo no"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: Settings.hasBattery = text.trim() === "yes"
        }
    }
    // Wi-Fi: derivado de NetworkManager (Quickshell.Networking). Se actualiza
    // reactivo con un timer ligero, sin proceso. Una vez detectada la interfaz,
    // el chequeo baja a 20s (suficiente para captar un hotplug) en vez de
    // iterar los dispositivos cada 2s para siempre.
    Timer {
        id: wifiDetectTimer
        interval: 2000
        repeat: true
        running: true
        onTriggered: {
            var vals = Networking.devices ? Networking.devices.values : null;
            var has = false;
            if (vals) for (var i=0;i<vals.length;i++) if (vals[i].type === DeviceType.Wifi) { has=true; break; }
            Settings.hasWifi = has;
            if (vals && vals.length > 0 && wifiDetectTimer.interval === 2000) {
                wifiDetectTimer.interval = 20000;
                wifiDetectTimer.restart();
            }
        }
    }
    // Micrófono: presencia de fuente de entrada vía Pipewire. Por defecto true
    // hasta que Pipewire reporte (evita hide prematuro al arrancar). Cuando
    // Pipewire ya está listo (se hizo la primera pasada real), el chequeo baja
    // a 20s en vez de recorrer los nodos cada 1.5s para siempre.
    Timer {
        id: micDetectTimer
        interval: 1500
        repeat: true
        running: true
        onTriggered: {
            var has = false;
            if (Pipewire.ready) {
                if (Pipewire.defaultAudioSource) has = true;
                else if (Pipewire.nodes && Pipewire.nodes.values) {
                    var vals = Pipewire.nodes.values;
                    for (var i=0;i<vals.length;i++) {
                        var n = vals[i];
                        if (!n || !n.audio || n.isSink || n.isStream) continue;
                        has = true; break;
                    }
                }
                if (micDetectTimer.interval === 1500) {
                    micDetectTimer.interval = 20000;
                    micDetectTimer.restart();
                }
            } else {
                has = true; // aún no listo, no ocultar
            }
            Settings.hasMic = has;
        }
    }

    // ── Bluetooth ─────────────────────────────────────────────────
    // Estado persistido en state.json (bluetoothEnabled + btVolumeMap,
    // el mapa de volúmenes por dispositivo). La gestión del adaptador
    // (encendido/apagado, desbloqueo rfkill) y el volcado a disco viven
    // aquí; la barra (popup) y la sección de ajustes solo leen el estado
    // y notifican cambios vía Settings.
    FileView {
        id: btStateFile
        path: Qt.resolvedUrl("state.json")
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: btState
            property bool bluetoothEnabled: false
            property var btVolumeMap: ({})
        }
    }

    // Al arrancar se aplica el estado guardado al adaptador. Puede que
    // el adaptador tarde en aparecer (Bluetooth.defaultAdapter null), por
    // eso se reintenta hasta que esté listo.
    property bool _btApplied: false

    function _applyBtState(): void {
        if (root._btApplied)
            return;
        if (!Bluetooth.defaultAdapter)
            return;
        root._btApplied = true;
        if (Bluetooth.defaultAdapter.state !== BluetoothAdapterState.Blocked)
            Bluetooth.defaultAdapter.enabled = btState.bluetoothEnabled;
    }

    Connections {
        target: Bluetooth
        function onDefaultAdapterChanged() {
            root._applyBtState();
        }
    }

    Timer {
        interval: 500
        repeat: true
        running: !root._btApplied
        onTriggered: root._applyBtState()
    }

    function setBluetoothEnabled(enabled: bool): void {
        btState.bluetoothEnabled = enabled;
        btStateFile.writeAdapter();
    }

    function setBtVolumeMap(map: var): void {
        Settings.btVolumeMap = Object.assign({}, map);
        btState.btVolumeMap = Object.assign({}, map);
        btStateFile.writeAdapter();
    }

    // ── Restauración de volumen por dispositivo ────────────────────
    // Vive en la raíz (no en la sección de ajustes ni en el popup de la
    // barra) para funcionar con CUALQUIER forma de conexión: audífonos
    // encendidos, auto-reconexión o conectar desde cualquier lado. Cuando
    // aparece un sink bluez nuevo (bluez_output.<addr>.*) se aplica el
    // volumen guardado en btVolumeMap. Un sink recién creado tarda en
    // estabilizarse y el dispositivo suele re-reportar su propio volumen
    // al conectar (pisando el que ponemos), así que se reaplica durante
    // una ventana de asentado (~15s). Pasada la ventana ya no se toca el
    // volumen (se respeta lo que haga el usuario). Al desconectarse el
    // sink desaparece y se limpia la marca, de modo que la próxima
    // conexión vuelve a restaurar.
    // ── Restauración de volumen por dispositivo ────────────────────
    // Vive en la raíz (no en la sección de ajustes ni en el popup de la
    // barra) para funcionar con CUALQUIER forma de conexión: audífonos
    // encendidos, auto-reconexión o conectar desde cualquier lado. Cuando
    // aparece un sink bluez nuevo (bluez_output.<addr>.*) se espera a que
    // su volumen se asiente (~1.5s sin cambios: el dispositivo re-reporta
    // su propio volumen al conectar) y entonces se aplica UNA sola vez el
    // volumen guardado en btVolumeMap. Eso evita el "flicker" de aplicar
    // antes de tiempo y que el reporte tardío del dispositivo lo pise.
    // Tras aplicarlo solo se re-corrige si el dispositivo vuelve a ~100
    // (re-reporte) durante la ventana; un valor intermedio se respeta
    // (es un cambio manual del usuario, no se le pelea).
    // ── Restauración de volumen por dispositivo ────────────────────
    // Vive en la raíz (no en la sección de ajustes ni en el popup de la
    // barra) para funcionar con CUALQUIER forma de conexión: audífonos
    // encendidos, auto-reconexión o conectar desde cualquier lado. Cuando
    // aparece un sink bluez nuevo (bluez_output.<addr>.*) se espera a que
    // su volumen se asiente (~1.5s sin cambios) y se aplica el volumen
    // guardado en btVolumeMap. El dispositivo suele re-reportar su propio
    // volumen al conectar (el "sonido de conexión" a 100): tras aplicar
    // solo se re-corrige si el volumen vuelve a ~100 exacto (re-reporte
    // del dispositivo); cualquier valor intermedio se interpreta como un
    // cambio manual del usuario y se deja de tocar (no se le pelea).
    // Una vez estabilizado (applied === 2) solo se observa el volumen:
    // si el usuario lo cambia manualmente (teclas, wpctl, OSD) a un valor
    // estable distinto del guardado, ese pasa a ser el nuevo "último
    // volumen" y se persiste en btVolumeMap (auto-record, sin slider).
    property var _btVolSink: ({})
    property int _btVolSettleMs: 1500
    property bool btVolumeSettling: false

    function _checkBtVolumes(): void {
        if (!Settings.btVolumeMap || !Pipewire.nodes) return;
        var seen = {};
        var now = Date.now();
        var map = Settings.btVolumeMap;
        var nodes = Pipewire.nodes.values;
        var active = false;
        for (var i = 0; i < nodes.length; i++) {
            const node = nodes[i];
            if (!node || !node.name) continue;
            var m = /^bluez_output\.([0-9A-Fa-f_]+)\./.exec(node.name);
            if (!m) continue;
            var addr = m[1].replace(/_/g, ":");
            seen[addr] = true;
            active = true;
            var st = root._btVolSink[addr];
            if (st === undefined) {
                st = { born: now, lastChange: now, lastVol: -1, applied: 0 };
                root._btVolSink[addr] = st;
            }
            if (!node.audio) continue;
            var vol = node.audio.volume;
            if (vol < 0) continue;
            var key = "btvol_" + addr.replace(/:/g, "_");
            var saved = map[key];

            // Sink ya estabilizado: solo se observa para recordar cambios
            // manuales del usuario (el dispositivo ya se asentó y no se
            // re-aplica nada). Si el volumen cambia a un valor estable y
            // distinto del guardado (y no es el re-reporte ~100 del
            // dispositivo), se guarda como el nuevo "último volumen".
            if (st.applied === 2) {
                if (Math.abs(vol - st.lastVol) > 0.005) {
                    st.lastVol = vol;
                    st.lastChange = now;
                    continue;
                }
                st.lastVol = vol;
                if (now - st.lastChange < root._btVolSettleMs) continue;
                if (vol >= 0.98) continue;
                if (saved !== undefined && Math.abs(vol - saved) < 0.02) continue;
                const m = Object.assign({}, Settings.btVolumeMap || {});
                m[key] = vol;
                if (Settings.setBtVolumeMap)
                    Settings.setBtVolumeMap(m);
                continue;
            }

            if (saved === undefined || saved === null) {
                st.applied = 2;
                continue;
            }

            if (Math.abs(vol - st.lastVol) > 0.005) {
                st.lastVol = vol;
                st.lastChange = now;
                continue;
            }
            st.lastVol = vol;
            if (now - st.lastChange < root._btVolSettleMs) continue;

            if (st.applied === 0) {
                if (Math.abs(vol - saved) < 0.02) {
                    st.applied = 2;
                } else {
                    node.audio.volume = saved;
                    st.applied = 1;
                }
            } else if (st.applied === 1) {
                if (Math.abs(vol - saved) < 0.02) {
                    st.applied = 2;
                } else if (vol >= 0.98 && saved < 0.9) {
                    node.audio.volume = saved;
                } else {
                    st.applied = 2;
                }
            }
        }
        for (var a in root._btVolSink) {
            if (!seen[a]) delete root._btVolSink[a];
        }
        root.btVolumeSettling = active && (function() {
            for (var k in root._btVolSink) {
                if (root._btVolSink[k].applied !== 2) return true;
            }
            return false;
        })();
        btVolTimer.interval = active ? 300 : 1000;
    }

    // Poll rápido (300ms) mientras haya sinks bluez activos, 1s en otro
    // caso. La restauración usa el estado por sink de _btVolSink.
    Timer {
        id: btVolTimer
        interval: 1000
        repeat: true
        running: true
        onTriggered: root._checkBtVolumes()
    }

    Component.onCompleted: {
        barStateFile.waitForJob();
        Settings.barType = barState.barType;
        appliedBarType = barState.barType;
        Settings.appliedBarType = barState.barType;
        barStateReady = true;
        Settings.writeBarState = function() {
            barState.barType = Settings.barType;
            barStateFile.writeAdapter();
        };
        Settings.applyBar = function() {
            appliedBarType = Settings.barType;
            Settings.appliedBarType = Settings.barType;
        };
        Qt.callLater(function() {
            Settings.screenshotManager = screenshotManager;
            Settings.settingsWindow = settingsWindow;
        });

        // ── Idle: cargar tiempos guardados y aplicar al gestor ──
        idleStateFile.waitForJob();
        Settings.idleLockMin = idleState.idleLockMin;
        Settings.idleSuspendMin = idleState.idleSuspendMin;
        Settings.appliedIdleLockMin = idleState.idleLockMin;
        Settings.appliedIdleSuspendMin = idleState.idleSuspendMin;
        Settings.applyIdle = function() {
            idleManager.lockMin = Settings.idleLockMin;
            idleManager.suspendMin = Settings.idleSuspendMin;
            Settings.appliedIdleLockMin = Settings.idleLockMin;
            Settings.appliedIdleSuspendMin = Settings.idleSuspendMin;
            idleState.idleLockMin = Settings.idleLockMin;
            idleState.idleSuspendMin = Settings.idleSuspendMin;
            idleStateFile.writeAdapter();
        };
        Settings.applyIdle();

        // ── Luz nocturna: cargar estado y arrancar si estaba activa ──
        nightStateFile.waitForJob();
        Settings.nightLightEnabled = nightState.nightLightEnabled;
        Settings.nightLightTemp = nightState.nightLightTemp;
        Settings.appliedNightLightEnabled = nightState.nightLightEnabled;
        Settings.appliedNightLightTemp = nightState.nightLightTemp;
        root.nightLightEnabled = nightState.nightLightEnabled;
        root.nightLightTemp = nightState.nightLightTemp;
        Settings.applyNightLight = function() {
            root.setNightLight(Settings.nightLightEnabled, Settings.nightLightTemp);
            Settings.appliedNightLightEnabled = Settings.nightLightEnabled;
            Settings.appliedNightLightTemp = Settings.nightLightTemp;
        };
        Settings.previewNightLightTemp = root.previewNightLightTemp;
        if (nightState.nightLightEnabled) {
            root._startHyprsunset(nightState.nightLightTemp);
        }

        // ── Bluetooth: cargar estado guardado y aplicar al adaptador ──
        btStateFile.waitForJob();
        Settings.bluetoothEnabled = btState.bluetoothEnabled;
        Settings.btVolumeMap = btState.btVolumeMap;
        Settings.applyBluetooth = root.setBluetoothEnabled;
        Settings.setBtVolumeMap = root.setBtVolumeMap;
        root._applyBtState();

        // ── Modo de energía: cargar último perfil y sincronizar con el
        // daemon (puede haber cambiado fuera, p. ej. con un tool de
        // CachyOS).
        powerStateFile.waitForJob();
        root.powerProfile = powerState.powerProfile;
        Settings.powerProfile = powerState.powerProfile;
        Settings.setPowerProfile = root.setPowerProfile;
        root._pollPowerProfile();

        // ── Dictado por voz: cargar configuración guardada ──
        dictStateFile.waitForJob();
        Settings.dictModelPath = dictState.modelPath;
        Settings.dictLang = dictState.lang;
        Settings.dictTrimSilence = dictState.trimSilence;
        Settings.dictPasteFocused = dictState.pasteFocused;
        Settings.dictSoundOnFinish = dictState.soundOnFinish;
        Settings.applyDictation = function() {
            dictState.modelPath = Settings.dictModelPath;
            dictState.lang = Settings.dictLang;
            dictState.trimSilence = Settings.dictTrimSilence;
            dictState.pasteFocused = Settings.dictPasteFocused;
            dictState.soundOnFinish = Settings.dictSoundOnFinish;
            dictStateFile.writeAdapter();
        };

        // ── Hardware adaptativo: detectar brillo/batería/wifi ──
        Settings.setBrightness = root.setBrightness;
        brightDetectProc.running = true;
        batteryDetectProc.running = true;
        // wifiDetectTimer ya corre; forzar primera evaluación
        {
            var vals = Networking.devices ? Networking.devices.values : null;
            var has = false;
            if (vals) for (var i=0;i<vals.length;i++) if (vals[i].type === DeviceType.Wifi) { has=true; break; }
            Settings.hasWifi = has;
        }

        // ── Dependencias: comprobar al arrancar si falta algún binario ──
        dependencyCheck.check();
    }

    // Brillo por IPC (para hyprland.lua): qs ipc call brightness up/down/set <pct>
    IpcHandler {
        target: "brightness"
        function up(): void { if (Settings.hasBrightness) root.setBrightness(Math.min(100, root.brightness + 5)); }
        function down(): void { if (Settings.hasBrightness) root.setBrightness(Math.max(0, root.brightness - 5)); }
        function set(pct: int): void { if (Settings.hasBrightness) root.setBrightness(pct); }
    }
}

