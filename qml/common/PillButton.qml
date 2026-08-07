import QtQuick
import QtQuick.Controls
import FlipClock

/*!
    Flat rounded button used across the timer, stopwatch and alarm screens.
    `accented` fills it with the theme accent for the primary action of a
    screen; the rest stay outlined.
*/
Button {
    id: control

    property bool accented: false
    property color tint: control.accented ? ThemeManager.accent : ThemeManager.textPrimary

    implicitWidth: Math.max(112, contentItem.implicitWidth + 44)
    implicitHeight: 46
    padding: 12
    font.pixelSize: 15
    font.bold: true

    background: Rectangle {
        radius: height / 2
        color: control.accented
            ? (control.down ? Qt.darker(ThemeManager.accent, 1.2) : ThemeManager.accent)
            : (control.down ? ThemeManager.surfaceAlt : "transparent")
        border.width: control.accented ? 0 : 1
        border.color: Qt.rgba(control.tint.r, control.tint.g, control.tint.b, 0.35)
        opacity: control.enabled ? 1.0 : 0.4

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }

    contentItem: Text {
        text: control.text
        font: control.font
        color: control.accented ? (ThemeManager.isDark ? "#ffffff" : "#ffffff") : control.tint
        opacity: control.enabled ? 1.0 : 0.5
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
