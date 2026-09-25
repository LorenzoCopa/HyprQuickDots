pragma Singleton
import Quickshell

// Iconos Nerd Font, set Material Design Icons (familia "Symbols Nerd Font").
// Cada propiedad contiene el glifo del icono (codepoint PUA).
// Uso: SymbolicIcon { path: Icons.wifi; color: Settings.accent; size: 16 }
Singleton {
    readonly property string power: "\u23FB"
    readonly property string reboot: "\uDB81\uDF09"
    readonly property string suspend: "\uDB81\uDCB2"
    readonly property string logout: "\uDB80\uDF43"
    readonly property string lock: "\uDB80\uDF3E"
    readonly property string settings: "\uF013"   // mdi-cog (engranaje)
    readonly property string keyboard: "\uF13C"   // mdi-keyboard (atajos) — verificado en la cmap de Symbols Nerd Font
    readonly property string music: "\uDB80\uDF87"
    readonly property string bluetooth: "\uDB80\uDCAF"
    readonly property string bluetoothOff: "\uDB80\uDCB2"
    readonly property string wifi: "\uDB81\uDDA9"
    readonly property string wifiConnected: "\uDB85\uDEBD"
    readonly property string wifiOffline: "\uDB81\uDDAA"
    readonly property string wifiEncrypted: "\uDB85\uDEBF"
    readonly property string ethernet: "\uDB80\uDE00"
    readonly property string networkOffline: "\uDB80\uDF19"
    readonly property string nightlight: "\uDB81\uDEE8"
    readonly property string calendar: "\uDB80\uDCED"   // md-calendar
    readonly property string clockOutline: "\uDB80\uDD50"   // md-clock_outline
    readonly property string camera: "\uDB80\uDD00"
    readonly property string clipboard: "\uDB80\uDD92"
    readonly property string copy: "\uDB80\uDD8F"
    readonly property string trash: "\uDB80\uDDB4"
    readonly property string info: "\uF05A"     // fa-info_circle (información/ventajas) — verificado en la cmap de Symbols Nerd Font
    readonly property string refresh: "\uDB81\uDC50"
    readonly property string close: "\uDB80\uDD56"
    readonly property string check: "\uDB80\uDD2C"
    readonly property string chevronUp: "\uDB80\uDD43"
    readonly property string chevronDown: "\uDB80\uDD40"
    readonly property string image: "\uDB80\uDEE9"
    readonly property string textFile: "\uDB80\uDE19"
    readonly property string download: "\uDB80\uDDDA"
    readonly property string search: "\uDB80\uDF49"
    readonly property string save: "\uDB80\uDD93"
    readonly property string annotate: "\uDB80\uDCE3"
    readonly property string monitor: "\uDB80\uDF79"
    readonly property string region: "\uDB80\uDD9F"
    readonly property string window: "\uDB81\uDDB2"
    readonly property string active: "\uDB80\uDF28"
    readonly property string stack: "\uDB80\uDC3E"
    readonly property string notifications: "\uDB80\uDC9A"
    readonly property string mediaPlay: "\uDB81\uDC0A"
    readonly property string mediaPause: "\uDB80\uDFE4"
    readonly property string mediaPrev: "\uDB81\uDCAE"
    readonly property string mediaNext: "\uDB81\uDCAD"
    readonly property string repeat: "\uF454"   // mdi-repeat (repetir lista)
    readonly property string repeatOnce: "\uF455"   // mdi-repeat-once (repetir canción)
    readonly property string trayArrow: "\uF078"   // fa-chevron_down (flecha del tray, más ancha)
    readonly property string volumeHigh: "\uDB81\uDD7E"   // mdi-volume_high
    readonly property string volumeMedium: "\uDB81\uDD80"   // mdi-volume_medium
    readonly property string volumeLow: "\uDB81\uDD7F"   // mdi-volume_low
    readonly property string volumeOff: "\uDB81\uDD81"   // mdi-volume_off
    readonly property string volumeMute: "\uDB81\uDF5F"   // mdi-volume_mute
    readonly property string mic: "\uDB80\uDF6C"   // mdi-microphone
    readonly property string micOff: "\uDB80\uDF6D"   // mdi-microphone_off
    readonly property string brightness: "\uDB81\uDEE9"   // md-brightness_6 (sol)
    readonly property string battery: "\uDB80\uDCB2"   // md-battery (batería)
    readonly property string batteryCharging: "\uDB80\uDCB3"
    readonly property string warning: "\uDB80\uDC26"     // md-alert (triángulo de aviso, U+F0026) — glifo verificado por nombre en la cmap

    // ── Glifos de marca (Nerd Font v3, rango PUA) ─────────────
    // OJO: codepoints > U+FFFF como pares sustitutos. `\u` en JS solo acepta
    // 4 dígitos: "\uF0239" se leería como \uF023 + "9" (glifo equivocado).
    readonly property string firefox: "\uDB80\uDE39"      // md-firefox
    readonly property string browser: "\uDB80\uDEAF"      // md-google_chrome (navegador genérico)
    readonly property string terminal: "\uDB80\uDD8D"     // md-console (terminal)
    readonly property string discord: "\uDB81\uDE6F"      // md-discord
    readonly property string spotify: "\uDB81\uDCC7"      // md-spotify
    readonly property string steam: "\uDB81\uDCD3"        // md-steam
    readonly property string vscode: "\uDB82\uDE1E"       // md-microsoft_visual_studio_code
    readonly property string folder: "\uDB80\uDE4B"       // md-folder (gestor de archivos)
    readonly property string appGlyph: "\uDB82\uDCC6"     // md-application (fallback genérico)
    readonly property string apps: "\uDB80\uDC3B"         // md-apps (cuadrícula de aplicaciones)
    readonly property string accountLock: "\uDB84\uDD5E"  // md-account_lock (usuario + candado, polkit)
    readonly property string gamepad: "\uDB80\uDE96"      // md-gamepad (juegos)
    readonly property string arrowUp: "\uDB80\uDD43"      // md-chevron_up (replegar tray)
    readonly property string arrowDown: "\uDB80\uDD40"    // md-chevron_down (desplegar tray)

    // Mapea la clase de una ventana a un glifo Nerd Font (para el panel).
    function glyphForClass(appClass) {
        const lower = (appClass || "").toLowerCase();
        if (lower.includes("firefox") || lower.includes("zen"))
            return Icons.firefox;
        if (lower.includes("chrom") || lower.includes("edge") || lower.includes("brave"))
            return Icons.browser;
        if (lower.includes("kitty") || lower.includes("alacritty") || lower.includes("wezterm")
            || lower.includes("konsole") || lower.includes("terminal") || lower.includes("xterm"))
            return Icons.terminal;
        if (lower.includes("discord") || lower.includes("vesktop"))
            return Icons.discord;
        if (lower.includes("spotify"))
            return Icons.spotify;
        if (lower.includes("steam"))
            return Icons.steam;
        if (lower.includes("lutris") || lower.includes("heroic") || lower.includes("game"))
            return Icons.gamepad;
        if (lower.includes("dolphin") || lower.includes("nautilus") || lower.includes("nemo")
            || lower.includes("pcmanfm") || lower.includes("thunar") || lower.includes("files")
            || lower.includes("file"))
            return Icons.folder;
        if (lower.includes("code") || lower.includes("visual") || lower.includes("codium") || lower.includes("zed"))
            return Icons.vscode;
        return Icons.appGlyph;
    }
}
