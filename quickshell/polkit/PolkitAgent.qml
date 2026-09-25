pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import "../config"

FloatingWindow {
  id: dialog
  title: "qs-polkit"
  color: "transparent"
  // Horizontal y alargado: la altura crece solo si el mensaje necesita
  // más de una línea (17px por línea extra).
  implicitWidth: 480
  implicitHeight: 201 + Math.max(0, msgText.lineCount - 1) * 17
  visible: agent.isActive

  // Estado local de la UI: esperando respuesta de polkit / Bloq Mayús /
  // último mensaje de error de polkit
  property bool busy: false
  property bool capsOn: false
  property string errMsg: ""

  // Usuario que ejecuta quickshell (fallback si la identidad de polkit
  // no se puede leer).
  readonly property string userName: Quickshell.env("USER") || "usuario"

  // Identidad REAL que pide polkit (puede ser root aunque la sesión sea
  // tuya). El tipo Identity es opaco en QML: probamos toString() y si no
  // da algo parseable ("unix-user:nombre" / "unix-user:0") usamos $USER.
  readonly property string authUser: {
    const id = agent.flow ? agent.flow.selectedIdentity : null;
    let s = "";
    if (id) {
      try { s = String(id.toString ? id.toString() : id); } catch (e) { s = ""; }
    }
    const m = s.match(/^unix-user:(.+)$/);
    if (!m)
      return userName;
    return m[1] === "0" ? "root" : m[1];
  }

  PolkitAgent {
    id: agent
    path: "/org/quickshell/Polkit"
  }

  HyprlandFocusGrab {
    windows: [dialog]
    active: agent.isActive
  }

  // Sobre un juego fullscreen el foco inicial puede quedarse en el juego
  // (constraint del puntero); pedirlo por dispatcher rompe el bloqueo.
  SelfFocus {
    targetTitle: "qs-polkit"
    active: agent.isActive
  }

  onVisibleChanged: {
    if (visible) {
      busy = false;
      capsOn = false;
      passField.forceActiveFocus();
      passField.text = "";
      errMsg = "";
      popIn.restart();
    }
  }

  Connections {
    target: agent.flow

    function onFailedChanged() {
      if (agent.flow && agent.flow.failed) {
        dialog.busy = false;
        passField.text = "";
        passField.forceActiveFocus();
        shakeAnim.start();
      }
    }

    function onSupplementaryMessageChanged() {
      if (agent.flow) {
        dialog.errMsg = agent.flow.supplementaryIsError ? agent.flow.supplementaryMessage : "";
      }
    }

    function onIsCompletedChanged() {
      if (agent.flow && agent.flow.isCompleted) {
        dialog.busy = false;
        passField.text = "";
      }
    }
  }

  // Pop-in suave al abrirse
  SequentialAnimation {
    id: popIn
    PropertyAction { target: dialogCard; property: "scale"; value: 0.96 }
    NumberAnimation { target: dialogCard; property: "scale"; to: 1; duration: Settings.animationFast; easing.type: Easing.OutCubic }
  }

  // Sacudida horizontal cuando falla la contraseña
  SequentialAnimation {
    id: shakeAnim
    NumberAnimation { target: dialogCard; property: "x"; to: -9; duration: 45; easing.type: Easing.InOutSine }
    NumberAnimation { target: dialogCard; property: "x"; to: 7; duration: 45; easing.type: Easing.InOutSine }
    NumberAnimation { target: dialogCard; property: "x"; to: -5; duration: 40; easing.type: Easing.InOutSine }
    NumberAnimation { target: dialogCard; property: "x"; to: 3; duration: 35; easing.type: Easing.InOutSine }
    NumberAnimation { target: dialogCard; property: "x"; to: 0; duration: 30; easing.type: Easing.OutCubic }
  }

  Item {
    id: dialogCard
    anchors.fill: parent

    // Sombra suave bajo la tarjeta (mismo patrón que QuickAccess)
    Item {
      anchors.fill: parent
      Rectangle { x: 0; y: 2; width: parent.width; height: parent.height; radius: 16; color: "#26000000" }
      Rectangle { x: 0; y: 5; width: parent.width; height: parent.height; radius: 17; color: "#18000000" }
      Rectangle { x: 0; y: 8; width: parent.width; height: parent.height; radius: 18; color: "#0E000000" }
    }

    // Tarjeta sin borde: relleno apenas más claro que el fondo (cardBg de QuickAccess)
    Rectangle {
      anchors.fill: parent
      radius: 14
      color: "#121212"
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 20
      spacing: 0

      // ── Cabecera horizontal: icono + mensaje + usuario ──
      RowLayout {
        Layout.fillWidth: true
        spacing: 14

        Rectangle {
          Layout.preferredWidth: 46
          Layout.preferredHeight: 46
          radius: 12
          color: Settings.surface

          Image {
            id: appIcon
            anchors.centerIn: parent
            width: 26
            height: 26
            source: agent.flow && agent.flow.iconName ? Quickshell.iconPath(agent.flow.iconName) : ""
            sourceSize { width: 26; height: 26 }
            visible: status === Image.Ready
          }

          Text {
            anchors.centerIn: parent
            text: Icons.lock
            color: Settings.accent
            font.family: Settings.iconFontFamily
            font.pixelSize: 22
            visible: appIcon.status !== Image.Ready
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 3

          Text {
            id: msgText
            Layout.fillWidth: true
            text: agent.flow && agent.flow.message ? agent.flow.message : "Autenticación requerida"
            color: Settings.fg
            font.family: Settings.fontFamily
            font.pixelSize: 13
            font.weight: Font.Bold
            wrapMode: Text.WordWrap
          }

          Text {
            Layout.fillWidth: true
            text: "Como " + dialog.authUser
            color: Settings.muted
            font.family: Settings.fontFamily
            font.pixelSize: 11
            elide: Text.ElideRight
          }
        }
      }

      // ── Campo de contraseña (sin label: el mensaje ya lo explica) ──
      Rectangle {
        Layout.topMargin: 14
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        radius: 9
        color: Settings.surface
        border {
          width: passField.activeFocus ? 1 : 0
          color: Settings.accent
        }

        TextInput {
          id: passField
          anchors.fill: parent
          anchors.leftMargin: 14
          anchors.rightMargin: 14
          focus: true
          clip: true
          echoMode: agent.flow && agent.flow.responseVisible ? TextInput.Normal : TextInput.Password
          passwordCharacter: "●"
          color: Settings.fg
          font.family: Settings.fontFamily
          font.pixelSize: 13
          selectionColor: Settings.selectionBg
          selectedTextColor: Settings.fg
          verticalAlignment: TextInput.AlignVCenter

          Keys.onPressed: event => {
            dialog.capsOn = (event.modifiers & Qt.CapsLockModifier) !== 0;
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              submitAuth();
              event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
              cancelAuth();
              event.accepted = true;
            }
          }
        }
      }

      // ── Línea de estado: error (rojo) o Bloq Mayús (amarillo).
      // Altura siempre reservada para que el layout no salte.
      Text {
        Layout.topMargin: 6
        Layout.fillWidth: true
        Layout.preferredHeight: 15
        text: dialog.errMsg !== "" ? dialog.errMsg
             : dialog.capsOn ? "Bloq Mayús está activado"
             : ""
        color: dialog.errMsg !== "" ? Settings.red : Settings.yellow
        font.family: Settings.fontFamily
        font.pixelSize: 11
        elide: Text.ElideRight
        opacity: text !== "" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
      }

      // Relleno: empuja los botones al fondo sin estirar el resto
      Item { Layout.fillHeight: true }

      // ── Botones alineados a la derecha ──
      RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        spacing: 8

        Item { Layout.fillWidth: true }

        Rectangle {
          id: cancelBtn
          Layout.preferredWidth: 88
          Layout.fillHeight: true
          radius: 8
          opacity: dialog.busy ? 0.55 : 1
          Behavior on opacity { NumberAnimation { duration: 120 } }
          color: maCancel.containsMouse || maCancel.pressed ? Settings.selectionBg : Settings.surface

          Text {
            anchors.centerIn: parent
            text: "Cancelar"
            color: Settings.fg
            font.family: Settings.fontFamily
            font.pixelSize: 12
            font.weight: Font.Bold
          }

          MouseArea {
            id: maCancel
            anchors.fill: parent
            hoverEnabled: true
            enabled: !dialog.busy
            cursorShape: Qt.PointingHandCursor
            onClicked: cancelAuth()
          }
        }

        Rectangle {
          id: acceptBtn
          Layout.preferredWidth: 116
          Layout.fillHeight: true
          radius: 8
          color: dialog.busy ? Settings.surface
               : maAccept.pressed ? Qt.darker(Settings.accent, 0.92)
               : maAccept.containsMouse ? Qt.lighter(Settings.accent, 1.07)
               : Settings.accent
          Behavior on color { ColorAnimation { duration: 80 } }

          Text {
            anchors.centerIn: parent
            text: dialog.busy ? "Verificando…" : "Aceptar"
            color: dialog.busy ? Settings.muted : "#000000"
            font.family: Settings.fontFamily
            font.pixelSize: 12
            font.weight: Font.Bold
          }

          MouseArea {
            id: maAccept
            anchors.fill: parent
            hoverEnabled: true
            enabled: !dialog.busy
            cursorShape: Qt.PointingHandCursor
            onClicked: submitAuth()
          }
        }
      }
    }
  }

  function submitAuth() {
    if (dialog.busy)
      return;
    if (agent.flow && agent.flow.isResponseRequired) {
      dialog.busy = true;
      agent.flow.submit(passField.text);
    }
  }

  function cancelAuth() {
    if (agent.flow) {
      agent.flow.cancelAuthenticationRequest();
    }
  }
}
