import QtQuick
import Quickshell
import Quickshell.Io
import "../config"
import "."

Scope {
  id: root

  readonly property int timeoutDirect: 15000
  readonly property int timeoutInteractive: 120000

  property string currentScreenshotPath: ""

  // Chequeador de dependencias (lo inyecta shell.qml): si falta hyprshot/
  // grim/slurp se avisa en lugar de fallar en silencio.
  property var depsChecker: null

  // ¿Están presentes todos los binarios de `need`? Sin chequeo previo
  // (checkedOnce) no se bloquea: el chequeo de arranque corre al inicio y
  // las capturas requieren interacción del usuario.
  function _depsOk(need) {
    if (!root.depsChecker || !root.depsChecker.checkedOnce) return true;
    for (var i = 0; i < need.length; i++) {
      if (!root.depsChecker.isPresent(need[i])) return false;
    }
    return true;
  }

  Component.onCompleted: {
    captureProc.exited.connect(function(code) {
      if (!root.capturing) return;
      root.capturing = false;
      quickTimer.stop();
      interactiveTimer.stop();
      if (code === 0 && root.currentScreenshotPath) {
        screenshotOverlay.screenshotPath = root.currentScreenshotPath;
        screenshotOverlay.visible = true;
      } else {
        root.currentScreenshotPath = "";
        Settings.captureActive = false;
      }
    });
  }
  property bool capturing: false
  property string currentMode: ""

  readonly property var modeConfig: ({
    output: { args: ["-m", "active", "-m", "output"], delay: 0.15 },
    active: { args: ["-m", "active", "-m", "window"], delay: 0.20 },
    region: { args: ["-m", "region", "-z"], delay: 0.20 },
    window: { args: ["-m", "window", "-z"], delay: 0.20 },
  })

  function shellEscape(str) {
    return "'" + str.replace(/'/g, "'\\''") + "'";
  }

  function generateTempPath() {
    return "/tmp/quickshot_" + Date.now() + ".png";
  }

  function hyprshotFilename(path) {
    return path.split("/").pop();
  }

  function startCapture(mode) {
    if (capturing) return;

    // Guarda de dependencias: region/window → hyprshot+grim+slurp; el resto
    // de modos → hyprshot+grim (hyprshot los necesita por debajo). Si falta
    // algo se avisa en el toast en vez de capturar nada en silencio.
    var need = (mode === "region" || mode === "window") ? ["hyprshot", "grim", "slurp"] : ["hyprshot", "grim"];
    if (!root._depsOk(need)) {
      if (root.depsChecker) root.depsChecker.checkAndNotify(need);
      return;
    }

    capturing = true;
    currentMode = mode;
    Settings.captureActive = true;

    modeSelector.visible = false;

    if (screenshotOverlay.visible)
      screenshotOverlay.discardScreenshot();

    var path = generateTempPath();
    currentScreenshotPath = path;

    var cfg = modeConfig[mode] || modeConfig.region;
    var escaped = shellEscape(path);
    var filename = hyprshotFilename(path);
    var delay = cfg.delay > 0 ? "sleep " + cfg.delay + "; " : "";
    var flags = cfg.args.join(" ");

    // NO se ocultan las ventanas de quickshell: si hay una abierta (launcher,
    // quickaccess, dictado, etc.) debe salir EN la captura. En los modos
    // interactivos (region/window) hyprshot congela la pantalla con `-z`
    // (hyprpicker) antes de que slurp robe el foco, así la interfaz queda en
    // el frame congelado aunque la ventana se cierre sola al perder el foco.
    // El delay en TODOS los modos da tiempo a que el selector de modo se
    // desmapee antes del disparo/congelado; sin él su "muesca" quedaba
    // impresa en el frame que hyprshot congela.
    captureProc.command = ["sh", "-c",
      delay + "hyprshot " + flags + " -o /tmp -f " + filename + " -s 2>/dev/null; sleep 0.3; [ -f " + escaped + " ]"];
    captureProc.running = true;

    var isInteractive = mode === "region" || mode === "window";
    (isInteractive ? interactiveTimer : quickTimer).restart();
  }

  function requestModeSelector() {
    if (screenshotOverlay.visible)
      screenshotOverlay.discardScreenshot();
    else if (!capturing)
      modeSelector.visible = true;
  }

  // ── Pin temporal ─────────────────────────────────────────────
  // El preview se auto-pinnea por encima (juegos fullscreen). Cuando se abre
  // el launcher / navegador de apps encima, hay que bajarlo para que esas
  // ventanas de quickshell queden visibles; se vuelve a pinner al cerrarlas.
  function suspendPin(): void { screenshotOverlay.suspendPin(); }
  function resumePin(): void { screenshotOverlay.resumePin(); }

  // Captura la ventana enfocada DIRECTAMENTE (sin selector de modo ni slurp).
  // Pensado para capturar una interfaz de quickshell abierta (launcher,
  // quickaccess, etc.): esas ventanas se cierran solas si pierden el foco
  // (HyprlandFocusGrab), así que no se oculta nada ni se roba el foco; se
  // lee la geometría con hyprctl y se corta con grim.
  function captureFocused() {
    if (capturing) return;

    // Esta ruta usa grim (geometría con hyprctl + corte).
    if (!root._depsOk(["grim"])) {
      if (root.depsChecker) root.depsChecker.checkAndNotify(["grim"]);
      return;
    }

    capturing = true;
    currentMode = "focused";
    Settings.captureActive = true;

    modeSelector.visible = false;

    if (screenshotOverlay.visible)
      screenshotOverlay.discardScreenshot();

    var path = generateTempPath();
    currentScreenshotPath = path;
    var escaped = shellEscape(path);

    captureProc.command = ["sh", "-c",
      "GEOM=$(hyprctl activewindow -j | jq -r 'if .mapped then \"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])\" else empty end'); " +
      "if [ -n \"$GEOM\" ]; then grim -g \"$GEOM\" " + escaped + "; else exit 1; fi; " +
      "sleep 0.3; [ -f " + escaped + " ]"];
    captureProc.running = true;

    quickTimer.restart();
  }

function resetCapture() {
      capturing = false;
      currentScreenshotPath = "";
      captureProc.running = false;
      Settings.captureActive = false;
    }

    // Cierre completo vía IPC (ruta de SUPER+X / cancel): sin esto el
    // selector de modo y/o el preview se quedan pegados en pantalla con
    // el foco capturado (SelfFocus) y quickshell parece "colgado".
    function cancel() {
      modeSelector.visible = false;
      if (screenshotOverlay.visible)
        screenshotOverlay.discardScreenshot();
      resetCapture();
    }

  Process {
    id: captureProc
    running: false
  }

  Timer {
    id: quickTimer
    interval: root.timeoutDirect
    onTriggered: root.resetCapture()
  }

  Timer {
    id: interactiveTimer
    interval: root.timeoutInteractive
    onTriggered: root.resetCapture()
  }

  ModeSelector {
    id: modeSelector
    onModeSelected: function(mode) {
      root.startCapture(mode);
    }
  }

  ScreenshotOverlay {
    id: screenshotOverlay
    onDiscardRequested: {
      root.currentScreenshotPath = "";
    }
    // Al cerrar el preview (descartar, anotar o acción) termina la captura:
    // se reactivan los FocusGrab y la ventana de quickshell recupera el foco.
    onVisibleChanged: {
      if (!visible && Settings.captureActive)
        Settings.captureActive = false;
    }
  }

  IpcHandler {
    target: "screenshot"

    function mode(): void {
      if (screenshotOverlay.visible)
        screenshotOverlay.discardScreenshot();
      else if (!root.capturing)
        modeSelector.visible = true;
    }

    function full(): void { root.startCapture("output"); }
    function region(): void { root.startCapture("region"); }
    function window(): void { root.startCapture("window"); }
    function active(): void { root.startCapture("active"); }
    function focused(): void { root.captureFocused(); }
    function cancel(): void { root.cancel(); }
  }
}
