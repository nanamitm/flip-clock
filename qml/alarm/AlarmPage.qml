import QtQuick
import QtQuick.Controls
import FlipClock

Item {
    id: page

    PageHeader {
        id: header

        width: parent.width
        title: qsTr("Alarm")
        subtitle: AlarmModel.nextAlarmText !== ""
            ? AlarmModel.nextAlarmText
            : qsTr("No alarm set")
        actionText: qsTr("Add")

        onActionTriggered: editSheet.openDraft()
    }

    // The alarm only rings while the app is running; saying so up front is
    // better than a user discovering it at 7 a.m.
    Rectangle {
        id: notice

        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        height: noticeText.implicitHeight + 22
        radius: 10
        color: ThemeManager.surfaceAlt

        Text {
            id: noticeText

            anchors.fill: parent
            anchors.margins: 11
            text: qsTr("Alarms ring while Flip Clock is running. Keep the app open — turn on “Keep screen on” in Settings to leave it showing.")
            color: ThemeManager.textSecondary
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
    }

    ListView {
        id: list

        anchors.top: notice.bottom
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        clip: true
        spacing: 8
        model: AlarmModel

        delegate: Rectangle {
            id: row

            required property int index
            required property string alarmId
            required property string label
            required property string timeText
            required property string meridiem
            required property string repeatText
            required property bool alarmEnabled
            required property bool isSnoozed

            width: list.width
            height: 92
            radius: 14
            color: ThemeManager.surface
            opacity: row.alarmEnabled ? 1.0 : 0.55

            Behavior on opacity {
                NumberAnimation { duration: 160 }
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: enableSwitch.left
                anchors.rightMargin: 12
                spacing: 2

                Row {
                    spacing: 6

                    Text {
                        text: row.timeText
                        color: ThemeManager.digit
                        font.pixelSize: 34
                        font.bold: true
                    }

                    Text {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6
                        visible: row.meridiem !== ""
                        text: row.meridiem
                        color: ThemeManager.textSecondary
                        font.pixelSize: 13
                        font.bold: true
                    }
                }

                Text {
                    width: parent.width
                    text: {
                        let parts = [row.repeatText]
                        if (row.label !== "")
                            parts.push(row.label)
                        if (row.isSnoozed)
                            parts.push(qsTr("Snoozed"))
                        return parts.join(" · ")
                    }
                    color: ThemeManager.textSecondary
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
            }

            ThemedSwitch {
                id: enableSwitch

                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                checked: row.alarmEnabled

                onToggled: AlarmModel.setEnabledAt(row.index, checked)
            }

            TapHandler {
                onTapped: editSheet.openExisting(row.index)
            }
        }
    }

    Text {
        anchors.centerIn: list
        width: parent.width * 0.7
        visible: AlarmModel.count === 0
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: qsTr("No alarms yet.\nUse Add to create one.")
        color: ThemeManager.textSecondary
        font.pixelSize: 15
    }

    AlarmEditSheet {
        id: editSheet
        parent: page
        anchors.fill: parent
    }
}
