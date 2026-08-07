import QtQuick
import FlipClock

/*!
    Full-screen takeover shown while an alarm is ringing.

    Covers the whole window including the navigation bar, so the alarm has to
    be snoozed or dismissed rather than navigated away from.
*/
Item {
    id: screen

    required property string alarmId

    readonly property var alarm: AlarmModel.byId(alarmId)

    Rectangle {
        anchors.fill: parent
        color: ThemeManager.background

        // Swallow taps so nothing behind the ringing alarm can be operated.
        TapHandler {}
    }

    AlertSound {
        source: "assets/sounds/alarm.wav"
        active: true
    }

    Column {
        anchors.centerIn: parent
        width: parent.width * 0.86
        spacing: 26

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Alarm")
            color: ThemeManager.accent
            font.pixelSize: 15
            font.bold: true
            font.letterSpacing: 4

            // A slow pulse reads as "still ringing" without being a strobe.
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: screen.alarm.timeText !== undefined ? screen.alarm.timeText : ""
            color: ThemeManager.digit
            font.pixelSize: Math.min(screen.width * 0.28, screen.height * 0.24)
            font.bold: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            visible: text !== ""
            text: screen.alarm.label !== undefined ? screen.alarm.label : ""
            color: ThemeManager.textPrimary
            font.pixelSize: 20
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16

            PillButton {
                text: screen.alarm.snoozeMinutes !== undefined
                    ? qsTr("Snooze %1 min").arg(screen.alarm.snoozeMinutes)
                    : qsTr("Snooze")

                onClicked: AlarmModel.snooze(screen.alarmId)
            }

            PillButton {
                accented: true
                text: qsTr("Dismiss")

                onClicked: AlarmModel.dismiss(screen.alarmId)
            }
        }
    }
}
