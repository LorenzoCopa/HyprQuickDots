pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// ─── Verificador de dependencias del shell ────────────────────────────
// Comprueba al arrancar (y bajo demanda) que existen los binarios que cada
// apartado del shell necesita (capturas, portapapeles, dictado, etc.). Si
// falta algo, `missing` se rellena y se emite → el toast (DepsToast) muestra
// el comando de instalación en lugar de dejar la feature rota en silencio.
// Scope (no QtObject): necesita propiedad default para colgar el Process.
Scope {
    id: root

    // bin/archivo → { pkg, feats }: binario (bin) o archivo (file) a
    // comprobar, paquete pacman que lo trae y apartado(s) del shell que lo
    // necesita (texto ES para el aviso). Se usa `file` para dependencias que
    // no son un ejecutable en PATH, como el backend Vulkan de ggml.
    // Mantener en sync con PACKAGES.md / install.sh.
    property var deps: [
        { bin: "hyprshot",         pkg: "hyprshot",              feats: "Capturas de pantalla" },
        { bin: "grim",             pkg: "grim",                  feats: "Capturas y bloqueo" },
        { bin: "slurp",            pkg: "slurp",                 feats: "Captura de región/ventana" },
        { bin: "hyprpicker",       pkg: "hyprpicker",            feats: "Selector de color" },
        { bin: "cliphist",         pkg: "cliphist",              feats: "Portapapeles" },
        { bin: "wl-copy",          pkg: "wl-clipboard",          feats: "Portapapeles / dictado" },
        { bin: "awww",             pkg: "awww",                  feats: "Fondo de pantalla" },
        { bin: "hyprsunset",       pkg: "hyprsunset",            feats: "Luz nocturna" },
        // Nota: brightnessctl NO está aqui a propósito: el brillo tiene
        // fallback a /sys en shell.qml (brightnessctl ... || cat /sys/...),
        // asi que su ausencia no rompe la feature y no debe avisar.
        // playerctl tampoco se comprueba: solo lo usan las teclas
        // multimedia (XF86Audio*). Los widgets MPRIS de Quickshell van por
        // D-Bus y funcionan sin él, así que no debe avisar.
        { bin: "powerprofilesctl", pkg: "power-profiles-daemon", feats: "Modo de energía" },
        { bin: "bluetoothctl",     pkg: "bluez-utils",           feats: "Bluetooth" },
        { bin: "nmcli",            pkg: "networkmanager",        feats: "Red" },
        { bin: "whisper-cli",      pkg: "whisper-cpp",           feats: "Dictado / comandos de voz" },
        // Sin este plugin whisper-cli funciona, pero cae a CPU (mucho más
        // lento). No es un binario: se comprueba el archivo del backend.
        { file: "/usr/lib/ggml/libggml-vulkan.so", pkg: "ggml-vulkan", feats: "Dictado (GPU Vulkan)" },
        { bin: "pw-record",        pkg: "pipewire-audio",        feats: "Dictado (grabación)" },
        { bin: "ffmpeg",           pkg: "ffmpeg",                feats: "Dictado (recorte)" },
        { bin: "sensors",          pkg: "lm_sensors",            feats: "Widgets Sistema/GPU" },
        { bin: "python3",          pkg: "python",                feats: "Luz nocturna (daemon)" },
        { bin: "hyprland",         pkg: "hyprland",              feats: "Núcleo (Hyprland)" }
    ]

    // Cierto cuando el chequeo (de arranque o manual) ya terminó. Las
    // features consultan `isPresent` solo después de esto: es una lectura
    // síncrona del último chequeo, sin lanzar procesos por consulta.
    property bool checkedOnce: false

    // Binarios/paquetes que faltan (objetos de `deps`). Se rellena en cada
    // check() y lo consume el DepsToast.
    property var missing: []

    signal checked()
    signal requestNotify(var missingDeps)

    // Mapa bin → bool (presente). JS plano a propósito: se lee con
    // `isPresent`, no se observa con bindings (asignar claves no notifica).
    property var _present: ({})

    // Clave interna de una dependencia: el binario o, si no hay, la ruta
    // del archivo. Debe ser única dentro de `deps`.
    function _key(d) {
        return d.file ? d.file : d.bin;
    }

    // ¿Existe el binario/archivo? Síncrono, válido tras el primer check().
    function isPresent(key: string): bool {
        return root._present[key] === true;
    }

    // Chequeo completo (arranque, `qs ipc call deps check`, botón
    // "Reintentar"): comprueba TODAS las dependencias en un único proceso y
    // emite `checked` al terminar.
    function check(): void {
        if (checkProc.running) return;
        const cmds = [];
        for (let i = 0; i < root.deps.length; i++) {
            const d = root.deps[i];
            const key = root._key(d);
            const probe = d.file ? "test -f " + d.file : "command -v " + d.bin;
            cmds.push(probe + " >/dev/null 2>&1 && echo YES::" + key + " || echo NO::" + key);
        }
        checkProc.command = ["sh", "-c", cmds.join("; ")];
        checkProc.running = true;
    }

    // Para una feature concreta (p. ej. capturas): si falta alguno de
    // `bins` (según el último chequeo), se notifica el aviso solo con esos
    // paquetes, sin re-chequear todo el sistema.
    function checkAndNotify(bins: var): void {
        const miss = root._missingFor(bins);
        if (miss.length > 0) {
            root.missing = miss;
            root.requestNotify(miss);
        }
    }

    function _missingFor(bins: var): var {
        const out = [];
        for (let i = 0; i < root.deps.length; i++) {
            const d = root.deps[i];
            const key = root._key(d);
            if (bins.indexOf(key) >= 0 && !root.isPresent(key)) out.push(d);
        }
        return out;
    }

    Process {
        id: checkProc
        command: ["true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split("::");
                    if (parts.length === 2) root._present[parts[1]] = parts[0] === "YES";
                }
                root.checkedOnce = true;
                const miss = [];
                for (let j = 0; j < root.deps.length; j++) {
                    const d = root.deps[j];
                    if (root._present[root._key(d)] !== true) miss.push(d);
                }
                root.missing = miss;
                root.checked();
            }
        }
    }
}