import QtQuick
import QtQuick.Controls
import FlipClock

/*!
    Full-page overlay for choosing a city to add to the world clock.

    An overlay rather than a pushed page: the world clock is the only entry
    point, and this way dismissing it needs no navigation stack.
*/
Item {
    id: sheet

    visible: false

    function open() {
        searchField.text = ""
        zoneModel.filter = ""
        visible = true
        searchField.forceActiveFocus()
    }

    function close() {
        visible = false
    }

    TimeZoneListModel {
        id: zoneModel
    }

    Rectangle {
        anchors.fill: parent
        // Fully opaque: even a couple of percent of transparency leaves the
        // page underneath legible through the sheet.
        color: ThemeManager.background

        // Swallow taps so they cannot reach the world clock underneath.
        TapHandler {}
    }

    Item {
        id: header

        width: parent.width
        height: 66

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Add a city")
            color: ThemeManager.textPrimary
            font.pixelSize: 22
            font.bold: true
        }

        PillButton {
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Done")

            onClicked: sheet.close()
        }
    }

    TextField {
        id: searchField

        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        height: 44
        placeholderText: qsTr("Search city or region")
        color: ThemeManager.textPrimary
        placeholderTextColor: ThemeManager.textSecondary
        font.pixelSize: 15
        leftPadding: 14

        background: Rectangle {
            radius: 12
            color: ThemeManager.surfaceAlt
        }

        onTextChanged: zoneModel.filter = text
    }

    ListView {
        anchors.top: searchField.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        clip: true
        model: zoneModel

        // The list is ~400 rows tall; caching a screenful either side keeps
        // flicking smooth without building every delegate.
        // Guarded against the negative height the view briefly reports before
        // its anchors resolve.
        cacheBuffer: Math.max(0, height * 2)

        delegate: ItemDelegate {
            id: zoneRow

            required property int index
            required property string timeZoneId
            required property string city
            required property string region
            required property string offsetText

            // contains() is a method, not a property, so referencing `count`
            // is what makes this re-evaluate when a city is added or removed.
            readonly property bool alreadyAdded: {
                WorldClockModel.count
                return WorldClockModel.contains(zoneRow.timeZoneId)
            }

            width: ListView.view.width
            height: 62
            enabled: !alreadyAdded

            background: Rectangle {
                color: zoneRow.down ? ThemeManager.surfaceAlt : "transparent"
                radius: 10
            }

            contentItem: Item {
                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: trailing.left
                    anchors.rightMargin: 12
                    spacing: 2

                    Text {
                        width: parent.width
                        text: zoneRow.city
                        color: ThemeManager.textPrimary
                        font.pixelSize: 16
                        opacity: zoneRow.enabled ? 1.0 : 0.45
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: zoneRow.region
                        color: ThemeManager.textSecondary
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }

                Text {
                    id: trailing

                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: zoneRow.enabled ? zoneRow.offsetText : qsTr("Added")
                    color: zoneRow.enabled ? ThemeManager.textSecondary : ThemeManager.accent
                    font.pixelSize: 13
                    font.bold: !zoneRow.enabled
                }
            }

            onClicked: {
                WorldClockModel.add(zoneRow.timeZoneId)
                WorldClockModel.refresh()
            }
        }
    }
}
