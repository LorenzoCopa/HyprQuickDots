pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../config"

FloatingWindow {
    id: root
    title: "qs-screenshot-preview"
    color: "transparent"
    implicitWidth: 580
    implicitHeight: 520
    visible: false

    readonly property int pinDelay: 400
    readonly property int feedbackDuration: 2000
    readonly property int feedbackAnimDuration: 200
    readonly property int ocrSectionHeight: 130

    property string screenshotPath: ""
    property string ocrText: ""
    property bool ocrRunning: false
    property bool pinActive: false
    property int pinRetries: 0

    signal discardRequested

    function shellEscape(str) {
        return "'" + str.replace(/'/g, "'\\''") + "'";
    }

    function reset() {
        screenshotPath = "";
        ocrText = "";
        ocrRunning = false;
        root.visible = false;
    }

    onVisibleChanged: {
        if (visible) {
            root.pinRetries = 0;
            Qt.callLater(function () {
                keyCatcher.forceActiveFocus();
                pinTimer.restart();
            });
        } else if (root.pinActive) {
            root.pinActive = false;
            pinProc.command = ["hyprctl", "dispatch", "hl.dsp.window.pin({action='disable',window='title:qs-screenshot-preview'})"];
            pinProc.running = true;
        }
    }

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
    }

    // Sobre un juego fullscreen el foco inicial puede quedarse en el juego
    // (constraint del puntero); pedirlo por dispatcher rompe el bloqueo y
    // deja operativos los botones del preview (copiar/guardar/anotar/pin).
    SelfFocus {
        targetTitle: "qs-screenshot-preview"
        active: root.visible
    }

    Timer {
        id: pinTimer
        interval: root.pinDelay
        onTriggered: {
            if (root.visible) {
                root.pinActive = true;
                pinProc.command = ["hyprctl", "dispatch", "hl.dsp.window.pin({action='enable'})"];
                pinProc.running = true;
            }
        }
    }

    // Baja temporalmente el preview (lo despinnea) para que otras ventanas de
    // quickshell (launcher, appbrowser) puedan quedar por encima. Guarda
    // contra el pin pendiente del timer y los reintentos.
    function suspendPin(): void {
        if (!root.visible || !root.pinActive) {
            pinTimer.stop();
            root.pinRetries = 0;
            return;
        }
        root.pinActive = false;
        pinTimer.stop();
        root.pinRetries = 0;
        pinProc.command = ["hyprctl", "dispatch", "hl.dsp.window.pin({action='disable',window='title:qs-screenshot-preview'})"];
        pinProc.running = true;
    }

    // Vuelve a pinner el preview si sigue visible.
    function resumePin(): void {
        if (root.visible && !root.pinActive) {
            root.pinRetries = 0;
            pinTimer.restart();
        }
    }

    Process {
        id: pinProc
        running: false
        onRunningChanged: {
            if (!running && root.visible && root.pinActive && root.pinRetries < 2) {
                root.pinRetries++;
                pinTimer.restart();
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Settings.bg
        radius: 12

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: Settings.surface
                clip: true

                Image {
                    id: preview
                    anchors.fill: parent
                    anchors.margins: 4
                    fillMode: Image.PreserveAspectFit
                    source: root.screenshotPath ? "file://" + root.screenshotPath : ""
                    asynchronous: true
                }

                Text {
                    anchors.centerIn: parent
                    text: "Procesando captura..."
                    color: Settings.subtext0
                    font.family: Settings.fontFamily
                    font.pixelSize: 13
                    visible: root.screenshotPath.length > 0 && preview.status !== Image.Ready
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                spacing: 6

                Item {
                    Layout.fillWidth: true
                }

                Repeater {
                    model: [
                        {
                            icon: Icons.copy,
                            label: "Copiar",
                            action: "copy"
                        },
                        {
                            icon: Icons.save,
                            label: "Guardar",
                            action: "save"
                        },
                        {
                            icon: Icons.search,
                            label: "OCR",
                            action: "ocr"
                        },
                        {
                            icon: Icons.annotate,
                            label: "Anotar",
                            action: "annotate"
                        },
                        {
                            icon: Icons.trash,
                            label: "Descartar",
                            action: "discard"
                        },
                    ]

                    delegate: Rectangle {
                        id: btnBg
                        required property var modelData
                        implicitWidth: labelText.implicitWidth + 28
                        Layout.preferredHeight: 34
                        radius: 8
                        color: btnMouse.containsMouse ? Settings.selectionBg : "transparent"
                        Behavior on color {
                            ColorAnimation {
                                duration: 80
                            }
                        }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 5

                            SymbolicIcon {
                                path: btnBg.modelData.icon
                                color: Settings.fg
                                implicitSize: 12
                            }

                            Text {
                                id: labelText
                                text: btnBg.modelData.label
                                color: Settings.fg
                                font.family: Settings.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Bold
                            }
                        }

                        MouseArea {
                            id: btnMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.handleAction(btnBg.modelData.action)
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                id: ocrSection
                Layout.fillWidth: true
                implicitHeight: root.ocrText.length > 0 || root.ocrRunning ? root.ocrSectionHeight : 0
                radius: 8
                color: Settings.surface
                clip: true
                visible: implicitHeight > 0
                Behavior on implicitHeight {
                    NumberAnimation {
                        duration: 150
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Texto extraído"
                            color: Settings.fg
                            font.family: Settings.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: root.ocrRunning ? "Procesando..." : ""
                            color: Settings.subtext0
                            font.family: Settings.fontFamily
                            font.pixelSize: 10
                            font.italic: true
                        }

                        Rectangle {
                            Layout.preferredWidth: 64
                            Layout.preferredHeight: 22
                            radius: 4
                            color: ocrCopyBtn.containsMouse ? Settings.selectionBg : "transparent"
                            visible: root.ocrText.length > 0

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 4
                                SymbolicIcon {
                                    path: Icons.copy
                                    color: Settings.fg
                                    implicitSize: 11
                                }
                                Text {
                                    text: "Copiar"
                                    color: Settings.fg
                                    font.family: Settings.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                }
                            }

                            MouseArea {
                                id: ocrCopyBtn
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: root.copyOcrToClipboard()
                            }
                        }
                    }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: parent.width
                        contentHeight: ocrTextEdit.implicitHeight

                        TextEdit {
                            id: ocrTextEdit
                            width: parent.width
                            text: root.ocrText
                            color: Settings.fg
                            font.family: Settings.fontFamily
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            readOnly: true
                            selectByMouse: true
                        }
                    }
                }
            }
        }
    }

    Process {
        id: actionProc
        command: []
        running: false
    }

    Process {
        id: ocrProc
        command: []
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.ocrText = this.text.trim();
                root.ocrRunning = false;
            }
        }
    }

    Process {
        id: annotateProc
        property bool startedByUs: false
        command: []
        running: false
        onRunningChanged: {
            if (running) {
                startedByUs = true;
            } else if (startedByUs) {
                startedByUs = false;
                root.visible = false;
            }
        }
    }

    function handleAction(action) {
        switch (action) {
        case "copy":
            copyToClipboard();
            break;
        case "save":
            saveScreenshot();
            break;
        case "ocr":
            runOcr();
            break;
        case "annotate":
            openAnnotator();
            break;
        case "discard":
            discardScreenshot();
            break;
        }
    }

    function copyToClipboard() {
        if (!screenshotPath)
            return;
        var escaped = shellEscape(screenshotPath);
        actionProc.command = ["sh", "-c", "wl-copy --type image/png < " + escaped];
        actionProc.running = true;
        showFeedback("Imagen copiada al portapapeles");
    }

    function saveScreenshot() {
        if (!screenshotPath)
            return;
        var d = new Date();
        var filename = "Screenshot_%1-%2-%3_%4-%5-%6.png".arg(d.getFullYear()).arg(String(d.getMonth() + 1).padStart(2, '0')).arg(String(d.getDate()).padStart(2, '0')).arg(String(d.getHours()).padStart(2, '0')).arg(String(d.getMinutes()).padStart(2, '0')).arg(String(d.getSeconds()).padStart(2, '0'));
        var escaped = shellEscape(screenshotPath);
        // OJO: `~` entre comillas simples NO lo expande el shell y el cp
        // acabaría en un directorio literal "~" (o en error). Se expande con
        // $HOME fuera de comillas (el filename es solo dígitos, sin espacios).
        var dest = "$HOME/Pictures/Screenshots/" + filename;
        actionProc.command = ["sh", "-c", "mkdir -p \"$HOME/Pictures/Screenshots\" && cp " + escaped + " \"" + dest + "\""];
        actionProc.running = true;
        showFeedback("Guardado en ~/Pictures/Screenshots/");
    }

    function runOcr() {
        if (!screenshotPath || ocrRunning)
            return;
        ocrRunning = true;
        ocrText = "";
        var escaped = shellEscape(screenshotPath);
        ocrProc.command = ["sh", "-c", "tesseract " + escaped + " stdout -l spa+eng 2>/dev/null"];
        ocrProc.running = true;
    }

    function copyOcrToClipboard() {
        if (!ocrText)
            return;
        var escaped = ocrText.replace(/'/g, "'\\''");
        actionProc.command = ["sh", "-c", "printf '%s' '" + escaped + "' | wl-copy"];
        actionProc.running = true;
        showFeedback("Texto copiado al portapapeles");
    }

    function openAnnotator() {
        if (!screenshotPath)
            return;
        annotateProc.command = ["swappy", "-f", screenshotPath];
        annotateProc.running = true;
        root.visible = false;
    }

    function discardScreenshot() {
        if (screenshotPath) {
            actionProc.command = ["rm", "-f", screenshotPath];
            actionProc.running = true;
        }
        root.discardRequested();
        root.reset();
    }

    function showFeedback(msg) {
        feedbackText.text = msg;
        feedbackText.color = Settings.green;
        feedbackText.opacity = 1.0;
        feedbackTimer.restart();
    }

    Text {
        id: feedbackText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36
        color: Settings.green
        font.family: Settings.fontFamily
        font.pixelSize: 11
        font.weight: Font.Bold
        opacity: 0
        z: 10

        Behavior on opacity {
            NumberAnimation {
                duration: root.feedbackAnimDuration
            }
        }
    }

    Timer {
        id: feedbackTimer
        interval: root.feedbackDuration
        onTriggered: feedbackText.opacity = 0
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                root.discardScreenshot();
                event.accepted = true;
            } else if ((event.key === Qt.Key_C || event.key === Qt.Key_S) && !(event.modifiers & Qt.ControlModifier)) {
                if (event.key === Qt.Key_C)
                    root.copyToClipboard();
                else if (event.key === Qt.Key_S)
                    root.saveScreenshot();
                event.accepted = true;
            }
        }
    }
}
