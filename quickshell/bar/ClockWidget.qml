import QtQuick
import QtQuick.Layouts
import Quickshell
import "."
import "../config"

Item {
    id: root
    required property var panelWindow
    required property var notifModel
    required property bool dndEnabled
    required property var onToggleDnd
    required property var onClearAll
    required property var onToggleWlogout
    required property bool nightLightEnabled
    required property int nightLightTemp
    required property var onNightLightChange
    implicitWidth: clockText.implicitWidth
    implicitHeight: clockText.implicitHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        id: clockText
        anchors.centerIn: parent
        font.family: Settings.fontFamily
        font.pixelSize: Settings.fontSize
        font.weight: Settings.fontWeight
        font.letterSpacing: Settings.fontLetterSpacing
        color: Settings.accent

        text: {
            var d = clock.date;
            var days = ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"];
            var months = ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"];
            var hh = ("0" + d.getHours()).slice(-2);
            var mm = ("0" + d.getMinutes()).slice(-2);
            return days[d.getDay()] + " " + d.getDate() + " " + months[d.getMonth()] + " · " + hh + ":" + mm;
        }
    }

    function showMediaPanel() {
        if (popup.visible && popupContent.showMedia) {
            popup.visible = false;
            popupContent.showMedia = false;
        } else {
            popup.updatePosition();
            popup.visible = true;
            popupContent.showMedia = true;
        }
    }

    function showNetworkPanel() {
        if (popup.visible && popupContent.showNetwork) {
            popup.visible = false;
            popupContent.showNetwork = false;
        } else {
            popup.updatePosition();
            popup.visible = true;
            popupContent.showNetwork = true;
        }
    }

    function togglePopup() {
        if (popup.visible) {
            popup.visible = false;
        } else {
            popup.updatePosition();
            popup.visible = true;
        }
    }

    function hidePopup() {
        popup.visible = false;
    }

    MouseArea {
        anchors.fill: clockText
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (popup.visible) {
                popup.visible = false;
            } else {
                popup.updatePosition();
                popup.visible = true;
            }
        }
    }

    /* qmllint disable unresolved-type */
    PopupWindow {
        id: popup
        color: "transparent"
        grabFocus: true
        visible: false
        implicitWidth: popupContent.implicitWidth
        implicitHeight: popupContent.implicitHeight

        anchor.window: root.panelWindow

        ClockPopup {
            id: popupContent
            panelWindow: root.panelWindow
            notifModel: root.notifModel
            dndEnabled: root.dndEnabled
            onToggleDnd: root.onToggleDnd
            onClearAll: root.onClearAll
            onToggleWlogout: root.onToggleWlogout
            onCloseRequested: function () {
                popup.visible = false;
            }
            nightLightEnabled: root.nightLightEnabled
            nightLightTemp: root.nightLightTemp
            onNightLightChange: root.onNightLightChange
        }

        function updatePosition() {
            var r = root.panelWindow.itemRect(clockText);
            anchor.rect.x = r.x + r.width / 2 - popupContent.implicitWidth / 2;
            anchor.rect.y = r.y + r.height + 6;
        }
    }
    /* qmllint enable unresolved-type */
}
