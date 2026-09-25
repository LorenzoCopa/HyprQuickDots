import QtQuick
import SddmComponents

// Theme SDDM "evergarden" con el diseño de la pantalla de bloqueo de
// Quickshell: fondo con el wallpaper pre-desenfocado y oscurecido, reloj
// seven-segment LED + fecha en español, y formulario con la paleta única
// (negro + acento) sin bordes.
Rectangle {
    id: root

    property color bgColor: config.bgColor || "#000000"
    property color surfaceColor: config.surfaceColor || "#1A1A1A"
    property color fgColor: config.fgColor || "#B3E6DB"
    property color accentColor: config.accentColor || "#B3E6DB"
    property color selectionBg: config.selectionBg || "#232A2E"
    property color mutedColor: config.mutedColor || "#5E7B73"
    property color errorColor: config.errorColor || "#FF6B6B"

    property var currentDate: new Date()
    property bool loginInProgress: false
    property bool haveErrors: false

    // Fondo: wallpaper pre-desenfocado y oscurecido con ImageMagick
    // (wallpaper-blur.jpg). A diferencia del lock de Quickshell no puede ser
    // una captura en vivo (en login no hay sesión); es una imagen estática.
    property string backgroundSource: {
        const b = config.background;
        return (typeof b === "string" && b !== "") ? b : "wallpaper-blur.jpg";
    }

    readonly property int fieldHeight: 40
    readonly property int fieldWidth: 260
    readonly property real ts: 3.0

    // Parpadeo de los dos puntos del reloj (estilo LED, como el lock).
    property real colonOpacity: 1.0

    function doLogin() {
        root.loginInProgress = true;
        root.haveErrors = false;
        sddm.login(userInput.text, passInput.text, sessionBox.index)
    }

    function invalidPassword() {
        passInput.text = ""
        passInput.focus = true
        passwordError.visible = true
        passwordErrorTimer.restart()
    }

    function invalidUser() {
        userInput.text = ""
        passInput.text = ""
        userInput.focus = true
        usernameError.visible = true
        usernameErrorTimer.restart()
    }

    Component.onCompleted: {
        currentDate = new Date()
        if (userModel.lastUser) {
            userInput.text = userModel.lastUser
            passInput.focus = true
        } else {
            userInput.focus = true
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.loginInProgress = false;
            if (userInput.text === userModel.lastUser)
                invalidPassword()
            else
                invalidUser()
        }
        function onLoginSucceeded() {
            root.loginInProgress = true;
        }
    }

    Timer {
        id: passwordErrorTimer
        interval: 3000
        onTriggered: passwordError.visible = false
    }

    Timer {
        id: usernameErrorTimer
        interval: 3000
        onTriggered: usernameError.visible = false
    }

    Text {
        text: "sddm-qt6 greeting"
        visible: false
    }

    TextConstants {
        id: textConstants
    }

    // ── Fondo: imagen estática pre-blureada + velo ─────────────
    Rectangle {
        anchors.fill: parent
        color: root.bgColor
    }

    Image {
        id: bgImg
        anchors.fill: parent
        source: Qt.resolvedUrl(root.backgroundSource)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Rectangle {
        anchors.fill: parent
        color: "#66000000"
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.currentDate = new Date()
            root.colonOpacity = root.colonOpacity === 1.0 ? 0.12 : 1.0
        }
    }

    // ── Reloj seven-segment LED + fecha en español ─────────────
    Column {
        id: clockBlock
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.12
        spacing: 14

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 136 * root.ts
            height: 50 * root.ts

            Row {
                anchors.centerIn: parent
                transformOrigin: Item.Center
                scale: root.ts
                spacing: 2

                SevenSegmentDigit { value: Math.floor(root.currentDate.getHours() / 10); segColor: root.accentColor }
                SevenSegmentDigit { value: root.currentDate.getHours() % 10; segColor: root.accentColor }

                Item {
                    width: 24
                    height: 50

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 13
                        width: 6
                        height: 6
                        radius: 3
                        color: root.accentColor
                        opacity: root.colonOpacity
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 13
                        width: 6
                        height: 6
                        radius: 3
                        color: root.accentColor
                        opacity: root.colonOpacity
                    }
                }

                SevenSegmentDigit { value: Math.floor(root.currentDate.getMinutes() / 10); segColor: root.accentColor }
                SevenSegmentDigit { value: root.currentDate.getMinutes() % 10; segColor: root.accentColor }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.mutedColor
            font.pixelSize: 18
            font.weight: Font.Medium
            text: {
                const d = root.currentDate;
                const days = ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"];
                const months = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
                               "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"];
                return days[d.getDay()] + ", " + d.getDate() + " de " + months[d.getMonth()];
            }
        }
    }

    // ── Formulario (estilo lock: campos sin borde, ícono + placeholder) ──
    Column {
        id: middleColumn
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max((parent.height - childrenRect.height) / 2, clockBlock.y + clockBlock.height + 28)
        spacing: 12

        Column {
            id: loginForm
            spacing: 12

            // Usuario
            Rectangle {
                id: userField
                width: root.fieldWidth
                height: root.fieldHeight
                radius: 8
                color: root.surfaceColor

                UserIcon {
                    id: userFieldIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 13
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    iconColor: userInput.focus ? root.accentColor : root.mutedColor
                }

                TextInput {
                    id: userInput
                    anchors.left: userFieldIcon.right
                    anchors.right: parent.right
                    anchors.leftMargin: 10
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.fgColor
                    font.pixelSize: 15
                    clip: true
                    selectByMouse: true
                    text: userModel.lastUser

                    KeyNavigation.tab: passInput
                    KeyNavigation.backtab: layoutBox

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            passInput.focus = true
                            event.accepted = true
                        }
                    }
                }

                Text {
                    anchors.left: userFieldIcon.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: userInput.text.length === 0 && !userInput.focus
                    color: root.mutedColor
                    font.pixelSize: 15
                    text: "Usuario"
                }
            }

            // Contraseña
            Rectangle {
                id: passField
                width: root.fieldWidth
                height: root.fieldHeight
                radius: 8
                color: root.surfaceColor

                LockIcon {
                    id: passFieldIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 13
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    iconColor: passInput.focus ? root.accentColor : root.mutedColor
                }

                TextInput {
                    id: passInput
                    anchors.left: passFieldIcon.right
                    anchors.right: parent.right
                    anchors.leftMargin: 10
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.fgColor
                    font.pixelSize: 15
                    clip: true
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    passwordMaskDelay: 0
                    focus: true

                    KeyNavigation.tab: loginButton
                    KeyNavigation.backtab: userInput

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.doLogin()
                            event.accepted = true
                        }
                    }
                }

                Text {
                    anchors.left: passFieldIcon.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: passInput.text.length === 0 && !passInput.focus
                    color: root.mutedColor
                    font.pixelSize: 15
                    text: "Contraseña"
                }
            }

            Text {
                id: passwordError
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Contraseña incorrecta"
                color: root.errorColor
                font.pixelSize: 12
                font.weight: Font.Medium
                visible: false
            }

            Text {
                id: usernameError
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Usuario no válido"
                color: root.errorColor
                font.pixelSize: 12
                font.weight: Font.Medium
                visible: false
            }

            Rectangle {
                id: loginButton
                width: root.fieldWidth
                height: root.fieldHeight
                radius: 10
                color: root.loginInProgress ? root.mutedColor : root.accentColor
                opacity: root.haveErrors ? 0.4 : 1.0

                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    id: loginButtonText
                    anchors.centerIn: parent
                    text: root.loginInProgress ? "..." : "ENTRAR"
                    color: root.bgColor
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    font.letterSpacing: 2
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.doLogin()
                    onEntered: parent.color = Qt.lighter(root.accentColor, 1.1)
                    onExited: parent.color = root.loginInProgress ? root.mutedColor : root.accentColor
                }

                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        root.doLogin()
                        event.accepted = true
                    }
                }
            }
        }
    }

    Row {
        id: cornerControls
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 28
        spacing: 16

        Column {
            spacing: 6

            Text {
                text: textConstants.session
                color: root.mutedColor
                font.pixelSize: 11
                font.weight: Font.Medium
                font.letterSpacing: 1
            }

            ComboBox {
                id: sessionBox
                width: 160
                height: 34

                model: sessionModel
                index: sessionModel.lastIndex
                color: root.surfaceColor
                arrowColor: "transparent"
                arrowIcon: Qt.resolvedUrl("accent-chevron.png")
                borderWidth: 1
                borderColor: root.selectionBg
                menuColor: root.surfaceColor
                hoverColor: root.selectionBg

                KeyNavigation.tab: layoutBox
                KeyNavigation.backtab: loginButton

                rowDelegate: Text {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 26
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignLeft
                    color: root.fgColor
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    text: parent.modelItem ? parent.modelItem.name : ""
                }
            }
        }

        Column {
            spacing: 6
            visible: keyboard.enabled && keyboard.layouts.length > 0

            Text {
                text: textConstants.layout
                color: root.mutedColor
                font.pixelSize: 11
                font.weight: Font.Medium
                font.letterSpacing: 1
            }

            LayoutBox {
                id: layoutBox
                width: 140
                height: 34

                color: root.surfaceColor
                arrowColor: "transparent"
                arrowIcon: Qt.resolvedUrl("accent-chevron.png")
                borderWidth: 1
                borderColor: root.selectionBg
                menuColor: root.surfaceColor
                hoverColor: root.selectionBg

                KeyNavigation.tab: userInput
                KeyNavigation.backtab: sessionBox

                rowDelegate: Rectangle {
                    color: "transparent"

                    Rectangle {
                        id: flagFrame
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 27
                        height: 18
                        radius: 3
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: "/usr/share/sddm/flags/%1.png".arg(modelItem ? modelItem.modelData.shortName : "zz")
                            fillMode: Image.PreserveAspectCrop
                        }
                    }

                    Text {
                        anchors.left: flagFrame.right
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.fgColor
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        text: modelItem ? modelItem.modelData.shortName.toUpperCase() : ""
                    }
                }
            }
        }
    }

    Row {
        id: powerRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 32
        spacing: 24

        Item {
            id: powerOffButton
            width: 42
            height: 42
            visible: sddm.canPowerOff

            property bool hovered: false

            Image {
                anchors.centerIn: parent
                width: 22
                height: 22
                source: Qt.resolvedUrl("power.svg")
                opacity: parent.hovered ? 1.0 : 0.5
                scale: parent.hovered ? 1.15 : 1.0

                Behavior on opacity { NumberAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 150 } }
            }

            Text {
                id: powerOffTooltip
                anchors.bottom: parent.top
                anchors.bottomMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                text: textConstants.shutdown
                color: root.accentColor
                font.pixelSize: 11
                font.weight: Font.Medium
                opacity: parent.hovered ? 1.0 : 0.0

                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: parent.hovered = true
                onExited: parent.hovered = false
                onClicked: sddm.powerOff()
            }
        }

        Item {
            id: rebootButton
            width: 42
            height: 42
            visible: sddm.canReboot

            property bool hovered: false

            Image {
                anchors.centerIn: parent
                width: 22
                height: 22
                source: Qt.resolvedUrl("reboot.svg")
                opacity: parent.hovered ? 1.0 : 0.5
                scale: parent.hovered ? 1.15 : 1.0

                Behavior on opacity { NumberAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 150 } }
            }

            Text {
                id: rebootTooltip
                anchors.bottom: parent.top
                anchors.bottomMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                text: textConstants.reboot
                color: root.accentColor
                font.pixelSize: 11
                font.weight: Font.Medium
                opacity: parent.hovered ? 1.0 : 0.0

                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: parent.hovered = true
                onExited: parent.hovered = false
                onClicked: sddm.reboot()
            }
        }
    }

    Text {
        id: footer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        text: "evergarden"
        color: root.mutedColor
        font.pixelSize: 11
        font.letterSpacing: 1
        opacity: 0.5
    }
}