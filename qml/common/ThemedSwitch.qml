import QtQuick
import QtQuick.Controls
import FlipClock

/*!
    Switch drawn from the theme palette directly.

    The Basic style derives its track colour from palette roles (`dark`,
    `midlight`) that a dark theme cannot set without either washing the track
    out or hiding it against the background. Drawing the indicator here makes
    the on/off states explicit instead.

    The label lives in SettingRow, so this contributes no content of its own.
*/
Switch {
    id: control

    padding: 0
    implicitWidth: 52
    implicitHeight: 30

    contentItem: Item {}

    indicator: Rectangle {
        implicitWidth: 52
        implicitHeight: 30
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        color: control.checked ? ThemeManager.accent : ThemeManager.surfaceAlt
        border.width: control.checked ? 0 : 1
        border.color: Qt.rgba(ThemeManager.textSecondary.r,
                              ThemeManager.textSecondary.g,
                              ThemeManager.textSecondary.b, 0.4)
        opacity: control.enabled ? 1.0 : 0.4

        Behavior on color {
            ColorAnimation { duration: 140 }
        }

        Rectangle {
            width: 24
            height: 24
            radius: 12
            y: 3
            x: control.checked ? parent.width - width - 3 : 3
            color: control.checked ? "#ffffff" : ThemeManager.textSecondary

            Behavior on x {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
        }
    }
}
