import QtQuick
import QtQuick.Controls
import FlipClock

/*!
    The user's cities and the current time in each.

    Rows update from the clock tick, but only while this page is actually
    visible -- there is no point recomputing time zone conversions behind the
    flip clock.
*/
Item {
    id: page

    Connections {
        target: ClockController
        enabled: page.visible
        function onTick() { WorldClockModel.refresh() }
    }

    // Times go stale while the page is hidden; bring them up to date the
    // moment it comes back.
    onVisibleChanged: {
        if (visible)
            WorldClockModel.refresh()
    }

    PageHeader {
        id: header

        width: parent.width
        title: qsTr("World clock")
        subtitle: WorldClockModel.count === 1
            ? qsTr("1 city")
            : qsTr("%1 cities").arg(WorldClockModel.count)
        actionText: qsTr("Add")

        onActionTriggered: picker.open()
    }

    ListView {
        id: list

        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        clip: true
        spacing: 8
        model: WorldClockModel

        // Rows slide out of the way when one is dropped in a new position.
        displaced: Transition {
            NumberAnimation { properties: "y"; duration: 180; easing.type: Easing.OutQuad }
        }

        delegate: Item {
            id: row

            required property int index
            required property string city
            required property string region
            required property string timeText
            required property string meridiem
            required property string offsetText
            required property string dayOffsetText
            required property bool isDaylightTime

            width: list.width
            height: 84
            // A row being dragged has to float over its neighbours.
            z: dragHandler.active ? 2 : 1

            Rectangle {
                id: card

                width: row.width
                height: row.height
                radius: 14
                color: ThemeManager.surface
                border.width: dragHandler.active ? 1 : 0
                border.color: ThemeManager.accent

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: timeColumn.left
                    anchors.rightMargin: 12
                    spacing: 3

                    Text {
                        width: parent.width
                        text: row.city
                        color: ThemeManager.textPrimary
                        font.pixelSize: 18
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Row {
                        spacing: 8

                        Text {
                            text: row.offsetText
                            color: ThemeManager.textSecondary
                            font.pixelSize: 12
                        }

                        Text {
                            visible: row.dayOffsetText !== ""
                            text: row.dayOffsetText
                            color: ThemeManager.accent
                            font.pixelSize: 12
                            font.bold: true
                        }

                        Text {
                            visible: row.isDaylightTime
                            text: qsTr("DST")
                            color: ThemeManager.textSecondary
                            font.pixelSize: 12
                        }
                    }
                }

                Column {
                    id: timeColumn

                    anchors.right: removeButton.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Text {
                        anchors.right: parent.right
                        text: row.timeText
                        color: ThemeManager.digit
                        font.pixelSize: 30
                        font.bold: true
                    }

                    Text {
                        anchors.right: parent.right
                        visible: row.meridiem !== ""
                        text: row.meridiem
                        color: ThemeManager.textSecondary
                        font.pixelSize: 12
                        font.bold: true
                    }
                }

                RoundButton {
                    id: removeButton

                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    height: 34
                    flat: true
                    text: "×"
                    font.pixelSize: 20
                    palette.buttonText: ThemeManager.textSecondary

                    onClicked: WorldClockModel.removeAt(row.index)
                }

                // Vertical drag reorders. The model is only touched on
                // release, so a half-finished drag never scrambles the list.
                DragHandler {
                    id: dragHandler

                    target: card
                    xAxis.enabled: false
                    yAxis.enabled: true

                    onActiveChanged: {
                        if (active)
                            return

                        const steps = Math.round(card.y / row.height)
                        card.y = 0
                        if (steps === 0)
                            return

                        const target = Math.max(0, Math.min(WorldClockModel.count - 1,
                                                            row.index + steps))
                        WorldClockModel.move(row.index, target)
                    }
                }
            }
        }
    }

    Text {
        anchors.centerIn: list
        width: parent.width * 0.7
        visible: WorldClockModel.count === 0
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: qsTr("No cities yet.\nUse Add to pick one.")
        color: ThemeManager.textSecondary
        font.pixelSize: 15
    }

    TimeZonePickerSheet {
        id: picker
        parent: page
        anchors.fill: parent
    }
}
