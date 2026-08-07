import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import FlipClock

/*!
    Countdown timer.

    The dial and the controls sit side by side on a wide screen and stacked on
    a tall one. Stacking them unconditionally pushes the transport row off the
    bottom of a phone in landscape, where the usable height is only a few
    hundred pixels.
*/
Item {
    id: page

    readonly property bool landscape: width > height
    readonly property bool idle: CountdownTimer.state === CountdownTimer.Idle
    readonly property bool finished: CountdownTimer.state === CountdownTimer.Finished

    // Size the dial from the space actually left after the header and margins.
    // Deriving it from the raw page height overflows in landscape, where the
    // header eats a large fraction of a short viewport.
    readonly property real availableWidth: Math.max(80, width - 24)
    readonly property real availableHeight: Math.max(80, height - header.height - 24)
    readonly property real dialSize: landscape
        ? Math.min(availableWidth * 0.40, availableHeight * 0.90)
        : Math.min(availableWidth * 0.72, availableHeight * 0.46)

    PageHeader {
        id: header
        width: parent.width
        title: qsTr("Timer")
    }

    AlertSound {
        source: "assets/sounds/timer.wav"
        active: page.finished
    }

    GridLayout {
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12

        columns: page.landscape ? 2 : 1
        columnSpacing: 24
        rowSpacing: 16

        // ---- dial ---------------------------------------------------------
        Item {
            id: dial

            readonly property real ringWidth: Math.max(6, width * 0.045)

            Layout.alignment: Qt.AlignCenter
            Layout.preferredWidth: page.dialSize
            Layout.preferredHeight: page.dialSize

            Shape {
                anchors.fill: parent
                antialiasing: true

                // Track
                ShapePath {
                    strokeColor: ThemeManager.surfaceAlt
                    strokeWidth: dial.ringWidth
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap

                    PathAngleArc {
                        centerX: dial.width / 2
                        centerY: dial.height / 2
                        radiusX: (dial.width - dial.ringWidth) / 2
                        radiusY: (dial.height - dial.ringWidth) / 2
                        startAngle: -90
                        sweepAngle: 360
                    }
                }

                // Sweeping the *remaining* fraction means the ring empties as
                // the countdown runs down.
                ShapePath {
                    strokeColor: page.finished ? "#e2564a" : ThemeManager.accent
                    strokeWidth: dial.ringWidth
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap

                    PathAngleArc {
                        centerX: dial.width / 2
                        centerY: dial.height / 2
                        radiusX: (dial.width - dial.ringWidth) / 2
                        radiusY: (dial.height - dial.ringWidth) / 2
                        startAngle: -90
                        sweepAngle: -360 * (1.0 - CountdownTimer.progress)
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 4

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: CountdownTimer.remainingText
                    color: ThemeManager.digit
                    font.pixelSize: dial.width * 0.22
                    font.bold: true
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: page.finished ? qsTr("Time's up")
                        : CountdownTimer.state === CountdownTimer.Paused ? qsTr("Paused")
                        : CountdownTimer.running ? qsTr("Running")
                        : qsTr("Ready")
                    color: page.finished ? "#e2564a" : ThemeManager.textSecondary
                    font.pixelSize: 14
                    font.bold: page.finished
                }
            }
        }

        // ---- presets and transport -----------------------------------------
        ColumnLayout {
            Layout.alignment: Qt.AlignCenter
            Layout.fillWidth: true
            spacing: 18

            // Grid rather than Flow: a fixed column count gives a real
            // implicitWidth, which is what lets AlignHCenter actually centre
            // the block. A Flow has to be told its width and then left-aligns.
            Grid {
                Layout.alignment: Qt.AlignHCenter
                visible: page.idle
                columns: 4
                spacing: 8

                Repeater {
                    model: [1, 3, 5, 10, 15, 30, 45, 60]

                    PillButton {
                        required property int modelData

                        implicitWidth: 78
                        implicitHeight: 40
                        text: qsTr("%1 min").arg(modelData)
                        accented: CountdownTimer.durationSeconds === modelData * 60

                        onClicked: {
                            CountdownTimer.durationSeconds = modelData * 60
                            AppSettings.lastTimerSeconds = modelData * 60
                        }
                    }
                }
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12

                PillButton {
                    visible: page.idle
                    accented: true
                    text: qsTr("Start")

                    onClicked: {
                        AppSettings.lastTimerSeconds = CountdownTimer.durationSeconds
                        CountdownTimer.start()
                    }
                }

                PillButton {
                    visible: CountdownTimer.running
                    accented: true
                    text: qsTr("Pause")

                    onClicked: CountdownTimer.pause()
                }

                PillButton {
                    visible: CountdownTimer.state === CountdownTimer.Paused
                    accented: true
                    text: qsTr("Resume")

                    onClicked: CountdownTimer.resume()
                }

                PillButton {
                    visible: !page.idle && !page.finished
                    text: qsTr("+1 min")

                    onClicked: CountdownTimer.addSeconds(60)
                }

                PillButton {
                    visible: !page.idle && !page.finished
                    text: qsTr("Reset")

                    onClicked: CountdownTimer.reset()
                }

                PillButton {
                    visible: page.finished
                    accented: true
                    text: qsTr("Stop")

                    onClicked: CountdownTimer.acknowledge()
                }
            }
        }
    }

    Component.onCompleted: {
        // Start from whatever the user last ran, not a hard-coded five minutes.
        if (page.idle)
            CountdownTimer.durationSeconds = AppSettings.lastTimerSeconds
    }
}
