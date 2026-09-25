import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../config"

Scope {
    id: root

    property alias locked: sessionLock.locked

    signal unlocked()

    // Captura previa de la pantalla ANTES de bloquear, para que LockSurface
    // pinte lo que había en el momento del bloqueo (desenfocado) en vez del
    // wallpaper. grim está instalado (dependencia de hyprshot). Si falla o
    // tarda, el Timer de seguridad fuerza el bloqueo igual (fallback wallpaper).
    property bool _capturing: false

    function lock() {
        lockContext.currentText = "";
        if (root._capturing) return;
        root._capturing = true;
        lockSafety.start();
        shotProc.command = ["sh", "-c", root.shotCmd()];
        shotProc.running = true;
    }

    function unlock() {
        sessionLock.locked = false;
        root.unlocked();
    }

    // Captura cada output a /tmp/qs-lockshot-<output>.png (una por monitor,
    // LockSurface resuelve la suya por screenName). Se ejecuta con el
    // escritorio todavía visible; una vez `locked = true` la superficie se
    // crea y lee el archivo correspondiente.
    function shotCmd() {
        const parts = [];
        const monitors = Quickshell.screens;
        for (let i = 0; i < monitors.length; i++) {
            const name = monitors[i].name;
            if (name !== "")
                parts.push("grim -o \"" + name + "\" /tmp/qs-lockshot-" + name + ".png");
        }
        return parts.join("; ");
    }

    Process {
        id: shotProc
        command: []
        running: false
        onRunningChanged: {
            if (!running && root._capturing) {
                root._capturing = false;
                lockSafety.stop();
                sessionLock.locked = true;
            }
        }
    }

    // Seguridad: si grim cuelga, bloquea igual a los ~2s.
    Timer {
        id: lockSafety
        interval: 2000
        repeat: false
        onTriggered: {
            root._capturing = false;
            sessionLock.locked = true;
        }
    }

    LockContext {
        id: lockContext
        onUnlocked: sessionLock.locked = false
    }

    WlSessionLock {
        id: sessionLock

        onLockedChanged: {
            if (!locked) {
                root.unlocked();
            }
        }

        WlSessionLockSurface {
            id: surface
            color: Settings.bg
            // El screen de la superficie solo es accesible aquí (en la plantilla
            // de la propia WlSessionLockSurface), no desde LockSurface (su padre
            // en runtime es el contentItem interno, sin `screen`).
            readonly property string lockScreenName: surface.screen ? surface.screen.name : ""
            // Animación de entrada: la superficie se mantiene opaca (color:
            // Settings.bg) y solo se anima el contenido (LockSurface) con un
            // fade + zoom desde dentro + deslizamiento hacia arriba, para que
            // el bloqueo no "aparezca de golpe". El pequeño retardo asegura que
            // la superficie ya esté mapeada cuando arranque (si no, la
            // animación correría invisible). En desbloqueo la superficie se
            // destruye al instante (sin animación).
            Item {
                id: lockContent
                anchors.fill: parent
                opacity: 0
                scale: 1.06

                transform: Translate { id: lockSlide; y: 32 }

                ParallelAnimation {
                    id: lockEnterAnim
                    running: false
                    NumberAnimation { target: lockContent; property: "opacity"; to: 1; duration: 700; easing.type: Easing.OutCubic }
                    NumberAnimation { target: lockContent; property: "scale"; to: 1; duration: 700; easing.type: Easing.OutCubic }
                    NumberAnimation { target: lockSlide; property: "y"; to: 0; duration: 700; easing.type: Easing.OutCubic }
                }

                Timer {
                    interval: 150
                    running: true
                    repeat: false
                    onTriggered: lockEnterAnim.start()
                }

                LockSurface {
                    anchors.fill: parent
                    context: lockContext
                    screenName: surface.lockScreenName
                }
            }
        }
    }
}