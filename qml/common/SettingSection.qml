import QtQuick
import FlipClock

//! Group heading inside the settings list.
Item {
    id: section

    property string title: ""

    implicitWidth: parent ? parent.width : 320
    implicitHeight: 44

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        text: section.title
        color: ThemeManager.accent
        font.pixelSize: 12
        font.bold: true
        font.letterSpacing: 1.5
    }
}
