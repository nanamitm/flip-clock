import QtQuick
import QtQuick.Controls
import FlipClock

Item {
    id: page

    PageHeader {
        id: header
        width: parent.width
        title: qsTr("Stopwatch")
        subtitle: Stopwatch.laps.count > 0
            ? qsTr("%1 laps").arg(Stopwatch.laps.count)
            : ""
    }

    Text {
        id: readout

        anchors.top: header.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        text: Stopwatch.elapsedText
        color: ThemeManager.digit
        font.pixelSize: Math.min(page.width * 0.17, 74)
        font.bold: true
    }

    Row {
        id: transport

        anchors.top: readout.bottom
        anchors.topMargin: 16
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 12

        PillButton {
            accented: true
            text: Stopwatch.running ? qsTr("Stop") : (Stopwatch.started ? qsTr("Resume") : qsTr("Start"))

            onClicked: Stopwatch.running ? Stopwatch.stop() : Stopwatch.start()
        }

        PillButton {
            enabled: Stopwatch.running
            text: qsTr("Lap")

            onClicked: Stopwatch.lap()
        }

        PillButton {
            enabled: Stopwatch.started
            text: qsTr("Reset")

            onClicked: Stopwatch.reset()
        }
    }

    ListView {
        id: lapList

        anchors.top: transport.bottom
        anchors.topMargin: 18
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        clip: true
        model: Stopwatch.laps

        header: Item {
            width: lapList.width
            height: Stopwatch.laps.count > 0 ? 28 : 0
            visible: Stopwatch.laps.count > 0

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Lap")
                color: ThemeManager.textSecondary
                font.pixelSize: 12
                font.bold: true
            }

            Text {
                anchors.right: totalHeading.left
                anchors.rightMargin: 28
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Split")
                color: ThemeManager.textSecondary
                font.pixelSize: 12
                font.bold: true
            }

            Text {
                id: totalHeading

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Total")
                color: ThemeManager.textSecondary
                font.pixelSize: 12
                font.bold: true
            }
        }

        delegate: Item {
            id: lapRow

            required property int lapNumber
            required property string lapText
            required property string totalText
            required property bool isFastest
            required property bool isSlowest

            width: lapList.width
            height: 42

            readonly property color highlight: isFastest ? "#3fb37f"
                : isSlowest ? "#e2564a"
                : ThemeManager.textPrimary

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: String(lapRow.lapNumber).padStart(2, "0")
                color: ThemeManager.textSecondary
                font.pixelSize: 15
            }

            Text {
                anchors.right: totalCell.left
                anchors.rightMargin: 28
                anchors.verticalCenter: parent.verticalCenter
                text: lapRow.lapText
                color: lapRow.highlight
                font.pixelSize: 16
                font.bold: lapRow.isFastest || lapRow.isSlowest
            }

            Text {
                id: totalCell

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: lapRow.totalText
                color: ThemeManager.textSecondary
                font.pixelSize: 16
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Qt.rgba(ThemeManager.textSecondary.r,
                               ThemeManager.textSecondary.g,
                               ThemeManager.textSecondary.b, 0.12)
            }
        }
    }
}
