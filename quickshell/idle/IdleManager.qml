// ─── Gestor de inactividad (bloqueo + suspensión) ─────────────────────
// Tras `lockMin` minutos sin input bloquea la sesión; tras `suspendMin`
// suspende el sistema. 0 = nunca (útil al descargar, ver un vídeo, etc.).
//
// IMPORTANTE: el IdleMonitor se crea UNA sola vez con timeout fijo de 1s.
// Quickshell 0.3.0 re-crea el notification interno cada vez que cambian
// `enabled`/`timeout`, y eso rompe la cadena de bindings de `isIdle` (el
// compositor marca idle pero isIdle se queda en false). Por eso el monitor
// no se toca nunca: solo detecta "hay o no input" y un Timer de 1s evalúa
// en tiempo real los minutos elegidos (lockMin/suspendMin), así los
// cambios en la configuración se aplican al instante.
//
// Gotcha de Hyprland: al crear la superficie de bloqueo el compositor
// cambia el foco y reinicia su temporizador de idle, lo que genera un
// "resumed" + "idled" y reiniciaría la cuenta (la suspensión pasaría a ser
// bloqueo + suspensión). Por eso:
//   - El "resumed" que llega justo tras bloquear (ventana de 5s) se ignora.
//   - Cuando lockMin < suspendMin, además se programa la suspensión con un
//     Timer anclado al momento del bloqueo, de modo que en total se
//     suspende a los suspendMin desde el inicio de la inactividad, sin
//     importar que Hyprland reinicie su temporizador.
//
// Los valores reales los inyecta shell.qml desde idlestate.json y se
// persisten desde la sección de configuración (PowerSection).

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Scope {
    id: root

    required property var sessionLock

    // Minutos de inactividad antes de bloquear/suspender. 0 = nunca.
    property int lockMin: 8
    property int suspendMin: 10

    property bool _locked: false
    property bool _suspended: false
    property real _idleStart: 0
    // Ventana en la que se ignora el "resumed" provocado por el propio
    // bloqueo (el foco pasa a la superficie de bloqueo y Hyprland reinicia
    // su temporizador de idle). Fuera de esa ventana, un resumed es
    // actividad real del usuario.
    property real _lockFlickerUntil: 0

    Process {
        id: suspendProc
        command: ["systemctl", "suspend"]
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.log("suspendProc stderr:", text.trim());
            }
        }
    }

    // El timeout no se modifica en runtime: ver comentario del encabezado.
    IdleMonitor {
        id: idleMonitor
        timeout: 1
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle) {
                // Nueva inactividad. No se reinicia la cuenta si ya hay una
                // en curso (el parpadeo que provoca el bloqueo no debe
                // reiniciar la suspensión).
                if (root._idleStart === 0)
                    root._idleStart = Date.now();
                checkTimer.restart();
            } else {
                // "resumed": puede ser actividad real del usuario o el
                // parpadeo que genera el propio bloqueo. Se distingue con la
                // ventana de tiempo abierta justo al bloquear.
                if (Date.now() < root._lockFlickerUntil && root.sessionLock.locked) {
                    root._lockFlickerUntil = 0;
                    return;
                }
                root._cancel();
            }
        }
    }

    // Evaluación continua mientras se está inactivo. Lee lockMin/suspendMin
    // en cada tick, así que los cambios de configuración se aplican solos.
    Timer {
        id: checkTimer
        interval: 1000
        repeat: true
        onTriggered: root.check()
    }

    // Red de seguridad para la suspensión cuando el bloqueo reinicia el
    // temporizador de idle de Hyprland (y la cuenta de _idleStart vuelve a
    // cero). Se ancla al momento del bloqueo: si se bloquea a los lockMin,
    // dispara (suspendMin - lockMin) minutos después, o sea a los suspendMin
    // totales desde el inicio de la inactividad.
    Timer {
        id: suspendTimer
        interval: 60000
        onTriggered: {
            if (root._suspended)
                return;
            root._suspended = true;
            suspendProc.running = true;
        }
    }

    function _cancel(): void {
        checkTimer.stop();
        suspendTimer.stop();
        root._idleStart = 0;
        root._locked = false;
        root._suspended = false;
    }

    // Al desbloquear se cancela la cuenta para que el próximo periodo de
    // inactividad arranque de cero.
    Connections {
        target: root.sessionLock
        function onLockedChanged() {
            if (!root.sessionLock.locked) {
                root._lockFlickerUntil = 0;
                root._cancel();
            }
        }
    }

    function check(): void {
        var elapsed = (Date.now() - root._idleStart) / 1000;

        if (root.lockMin > 0 && !root._locked && !root.sessionLock.locked
                && elapsed >= root.lockMin * 60) {
            root._locked = true;
            // Abre la ventana para ignorar el "resumed" que provoca el
            // propio bloqueo (el foco pasa a la superficie de bloqueo).
            root._lockFlickerUntil = Date.now() + 5000;
            root.sessionLock.lock();

            if (root.suspendMin > root.lockMin) {
                suspendTimer.interval = (root.suspendMin - root.lockMin) * 60000;
                suspendTimer.start();
            }
        }

        if (root.suspendMin > 0 && !root._suspended && elapsed >= root.suspendMin * 60) {
            root._suspended = true;
            suspendProc.running = true;
        }
    }
}
