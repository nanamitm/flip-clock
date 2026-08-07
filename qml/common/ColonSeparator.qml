import QtQuick
import FlipClock

/*!
    The two dots between time fields. Pulses once a second so the clock still
    reads as "live" when the seconds cards are hidden.
*/
Item {
    id: separator

    property real dotSize: 10
    property bool pulsing: true

    implicitWidth: dotSize * 2
    implicitHeight: dotSize * 5

    Column {
        anchors.centerIn: parent
        spacing: separator.dotSize * 1.4

        Repeater {
            model: 2

            Rectangle {
                width: separator.dotSize
                height: separator.dotSize
                radius: width / 2
                color: ThemeManager.digit
                opacity: separator.pulsing && ClockController.second % 2 === 1 ? 0.35 : 1.0

                Behavior on opacity {
                    NumberAnimation { duration: 320; easing.type: Easing.InOutQuad }
                }
            }
        }
    }
}
