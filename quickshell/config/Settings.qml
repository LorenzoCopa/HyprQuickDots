pragma Singleton
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    // ── Layout ──────────────────────────────────────────
    readonly property int workspaceCount: 5
    readonly property int barHeight: 24
    readonly property int animationFast: 200

    // ── Tipografía ──────────────────────────────────────
    readonly property string fontFamily: "Sans Serif"
    readonly property string iconFontFamily: "Symbols Nerd Font"
    readonly property int fontSize: 15
    readonly property int fontWeight: 800                       // 400=Normal 500=Medium 600=DemiBold 700=Bold
    readonly property real fontLetterSpacing: 0.0               // negativo = más compacto, 0 = normal

    // ── Paleta única (negro puro + acento) ──────────────
    readonly property string bg: "#000000"           // fondo: barra, launcher, ventanas
    readonly property string accent: "#B3E6DB"       // color único de letras e iconos
    readonly property string fg: accent              // texto principal (= accent)
    readonly property string subtext0: accent        // texto secundario / placeholder (= accent)
    readonly property string muted: "#5E7B73"        // acento atenuado: iconos/textos inactivos (menos brillo)
    readonly property string surface: "#1A1A1A"      // superficies: inputs, iconos de fondo, botones
    readonly property string selectionBg: "#232A2E"  // hover / selección (selection bg de la paleta)
    readonly property string green: "#9E9E9E"        // estado conectado (paneles)
    readonly property string red: "#FF6B6B"          // error / urgente
    readonly property string yellow: "#FFD166"       // aviso
    readonly property string scrim: "#99000000"      // overlay oscuro (wlogout, wallpaper)

    // ── Global References (set from shell.qml) ──────────
    property var screenshotManager: null
    property var settingsWindow: null
    property var writeBarState: null
    property var applyBar: null

    // ── Captura de pantalla ─────────────────────────────
    // true mientras hay una captura en curso (lo gestiona ScreenshotManager).
    // Los FocusGrab de las ventanas transitorias se desactivan mientras dura
    // para que slurp no robe el foco y las cierre (onCleared); al terminar se
    // reactivan y devuelven el foco a la ventana, que sigue abierta.
    property bool captureActive: false

    // ── Barra ───────────────────────────────────────────
    property string barType: "evergarden"
    property string appliedBarType: "evergarden"

    // ── Suspensión y bloqueo ────────────────────────────
    // Minutos de inactividad antes de bloquear/suspender. 0 = nunca.
    // Los valores "pendientes" se eligen en la UI y se activan con
    // "Aplicar" (Settings.applyIdle), igual que la barra.
    property int idleLockMin: 8
    property int idleSuspendMin: 10
    property int appliedIdleLockMin: 8
    property int appliedIdleSuspendMin: 10
    // Aplica los valores al IdleManager y los persiste en idlestate.json
    // (se setea en shell.qml).
    property var applyIdle: null

    // ── Luz nocturna ────────────────────────────────────
    // Temperatura en kelvin (1000-6500); enabled activa/desactiva
    // hyprsunset. Patrón pendiente/aplicado igual que la barra; la fuente
    // de verdad es shell.qml (setNightLight) que persiste en
    // nightstate.json y controla hyprsunset.
    property bool nightLightEnabled: false
    property int nightLightTemp: 3500
    property bool appliedNightLightEnabled: false
    property int appliedNightLightTemp: 3500
    property var applyNightLight: null
    // Preview en vivo del slider (solo si la luz nocturna está encendida):
    // aplica la temperatura al instante sin persistir. Se setea en shell.qml.
    property var previewNightLightTemp: null

    // ── Modo de energía (power-profiles-daemon) ────────────────
    // Perfil activo (performance / balanced / power-saver). La fuente de
    // verdad es el daemon; la gestión real (powerprofilesctl + sync por
    // poll) la hace shell.qml (Settings.setPowerProfile). QuickAccess y la
    // sección de ajustes solo leen y notifican cambios.
    property string powerProfile: "balanced"
    property var setPowerProfile: null

    readonly property var powerProfiles: [
        // icon: glyphs del icon font (md-lightning_bolt / md-scale_balance / md-leaf).
        // Codepoints como pares sustitutos (el escape \uXXXXXX no existe en JS:
        // \uF140B se leería como \uF140 + "B").
        { id: "performance", label: "Rendimiento",       short: "Perf",   icon: "\uDB85\uDC0B" },  // md-lightning_bolt
        { id: "balanced",    label: "Equilibrado",       short: "Equi",   icon: "\uDB81\uDDD1" },  // md-scale_balance
        { id: "power-saver", label: "Ahorro de energía", short: "Ahorro", icon: "\uDB80\uDF2A" },  // md-leaf
    ]

    readonly property string powerShortLabel: {
        for (var i = 0; i < Settings.powerProfiles.length; i++)
            if (Settings.powerProfiles[i].id === Settings.powerProfile)
                return Settings.powerProfiles[i].short;
        return "";
    }

    readonly property string powerIcon: {
        for (var i = 0; i < Settings.powerProfiles.length; i++)
            if (Settings.powerProfiles[i].id === Settings.powerProfile)
                return Settings.powerProfiles[i].icon;
        return Settings.powerProfiles.length ? Settings.powerProfiles[0].icon : "";
    }

    // ── Bluetooth ────────────────────────────────────────────────
    // Enabled + mapa de volúmenes por dispositivo, persistidos en
    // state.json. La gestión real la hace shell.qml (setBluetoothEnabled /
    // setBtVolumeMap); la barra y la sección de ajustes solo leen y
    // notifican cambios.
    property bool bluetoothEnabled: false
    property var btVolumeMap: ({})
    property var applyBluetooth: null
    property var setBtVolumeMap: null

    // ── Hardware adaptativo (oculto total si no hay) ────────────
    // Detectado en shell.qml al arrancar: si no hay backlight/batería/wifi/mic
    // el tile/slider/panel no se crea (visible:false + height 0), no opaco.
    property bool hasBrightness: false
    property bool hasBattery: false
    property bool hasWifi: false
    property bool hasMic: true
    // Brillo actual 0-100 (solo si hasBrightness), gestionado por shell.qml
    property int brightness: 50
    property var setBrightness: null

    // ── Dictado por voz (whisper.cpp) ────────────────────────────────
    // Configuración persistida en dictate.json por shell.qml
    // (Settings.applyDictation). La gestión real (pw-record → whisper-cli →
    // wl-copy/pegar) es de shell.qml; la sección de ajustes solo lee/notifica.
    property string dictModelPath: "~/.local/share/dictation/models/ggml-medium-q8_0.bin"
    property string dictLang: "auto"
    property bool dictTrimSilence: true
    property bool dictPasteFocused: true
    property bool dictSoundOnFinish: true
    property var applyDictation: null

    readonly property var dictLangs: [
        { id: "es",   label: "Español" },
        { id: "en",   label: "English" },
        { id: "auto", label: "Auto" },
    ]

    // ── Mpris helpers (shared to avoid duplication) ────
    function findActiveMprisPlayer() {
        const model = Mpris.players;
        if (!model)
            return null;
        for (const p of model.values) {
            if (p && p.trackTitle)
                return p;
        }
        return null;
    }

    // ── Notificaciones helpers ─────────────────────────────
    // Nombre de la app para una notificación. Muchos emisores no mandan
    // appName (p. ej. juegos como Dota 2 llegan vacíos y se caía al
    // feo "notify-send"); se resuelve entonces desde desktopEntry y, si
    // tampoco hay, se intenta derivar algo legible del appIcon.
    function notifAppName(n) {
        if (!n) return "";
        if (n.appName && n.appName.trim() !== "") return n.appName;
        const de = (n.desktopEntry || "").toLowerCase();
        const icon = (n.appIcon || "").toLowerCase();
        if (de.indexOf("steam_app_") === 0 || icon.indexOf("steam_icon_") === 0)
            return "Steam";
        if (n.desktopEntry && n.desktopEntry !== "") {
            const e = DesktopEntries.heuristicLookup(n.desktopEntry);
            if (e && e.name && e.name !== "") return e.name;
        }
        if (n.appIcon && n.appIcon !== "") {
            var ic = n.appIcon;
            const idx = ic.lastIndexOf("/");
            if (idx >= 0) ic = ic.substring(idx + 1);
            ic = ic.replace(/[-_.]/g, " ").replace(/\s+/g, " ").trim();
            if (ic !== "")
                return ic.replace(/\b\w/g, c => c.toUpperCase());
        }
        return "";
    }

    // ── Icono de notificación ─────────────────────────────
    // Resuelve el icono de una notificación a una URL usable, en orden:
    // el appIcon (icono de la app, ruta o nombre del tema) y, si no hay,
    // la imagen real que manda la notificación (perfil/foto).
    // OJO: `Quickshell.iconPath(nombre, true)` devuelve "" para los iconos
    // que solo existen en Papirus (Qt busca el theme activo, hicolor, no
    // Papirus) y por eso caían al círculo con la inicial. Aquí se busca en
    // Papirus a mano (papirusAppIcon) y el Image deja de estar Ready si el
    // archivo no existe, mostrando la inicial solo como último recurso.
    function notifIconUrl(n) {
        if (!n) return "";
        const icon = n.appIcon || "";
        if (icon !== "") {
            if (icon.indexOf("/") === 0 || icon.indexOf("file://") === 0)
                return icon;
            return Settings.papirusAppIcon(icon);
        }
        const img = n.image || "";
        if (img !== "" && (img.indexOf("/") === 0 || img.indexOf("file://") === 0))
            return img;
        return "";
    }

    // Ruta al icono en Papirus (el tema de esta config). Papirus replica
    // todos sus iconos en cada tamaño, así que 64x64 cubre el tema entero;
    // si el nombre no está, la URL no existe y el Image no llega a Ready.
    function papirusAppIcon(name) {
        if (!name || name === "") return "";
        return "file:///usr/share/icons/Papirus/64x64/apps/" + name + ".svg";
    }
}
