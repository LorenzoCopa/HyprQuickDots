// ─── Auto-enfoque defensivo para ventanas flotantes ──────────────────
// Al abrirse sobre un juego fullscreen, Hyprland puede negarle el foco
// inicial a la ventana si el juego mantiene el puntero restringido
// (constraint zwp_pointer_constraints del propio juego, p. ej. Dota 2 con
// SDL nativo Wayland, o una regla confine_pointer): la ventana se PINTA
// encima (allowedOverFullscreen) pero no recibe ni teclado ni ratón.
// Enfocarla por dispatcher rompe el bloqueo: al mover el foco fuera de la
// superficie del juego, FocusState desactiva su constraint y el ratón
// vuelve a procesarse con normalidad. Cuando la ventana ya tiene el foco,
// los dispatchers extra son no-op. El bucle cubre la latencia de mapeo
// (hyprctl devuelve exit 0 aunque el target aún no exista, así que no se
// puede cortar por código de salida).
//
// Uso: SelfFocus { targetTitle: "qs-launcher"; active: launcher.visible }
pragma ComponentBehavior: Bound

import Quickshell.Io

Process {
    id: proc

    // Título (qs-*) de la ventana a enfocar; lo pasa cada flotante.
    required property string targetTitle
    // Conectar a la propiedad visible de la ventana contenedora.
    property bool active: false

    onActiveChanged: {
        if (active) {
            proc.command = ["sh", "-c",
                "i=0; while [ $i -lt 6 ]; do sleep 0.07; hyprctl dispatch 'hl.dsp.focus({window=\"title:" + proc.targetTitle + "\"})' >/dev/null 2>&1; i=$((i+1)); done"];
            proc.running = true;
        } else {
            proc.running = false;
        }
    }
}
