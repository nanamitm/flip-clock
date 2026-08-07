import QtQuick
import FlipClock

/*!
    Title row shared by every non-clock page, with an optional action on the
    right (Add a city, Add an alarm, ...).
*/
Item {
    id: header

    property string title: ""
    property string subtitle: ""
    property string actionText: ""
    property bool actionEnabled: true

    signal actionTriggered()

    implicitHeight: 72

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: actionButton.left
        anchors.rightMargin: 12
        spacing: 2

        Text {
            width: parent.width
            text: header.title
            color: ThemeManager.textPrimary
            font.pixelSize: 24
            font.bold: true
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: header.subtitle !== ""
            text: header.subtitle
            color: ThemeManager.textSecondary
            font.pixelSize: 13
            elide: Text.ElideRight
        }
    }

    PillButton {
        id: actionButton

        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        visible: header.actionText !== ""
        width: visible ? implicitWidth : 0
        enabled: header.actionEnabled
        accented: true
        text: header.actionText

        onClicked: header.actionTriggered()
    }
}
