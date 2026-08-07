import QtQuick
import FlipClock

/*!
    Bottom navigation. Labels rather than icons: no icon set has to be bundled
    and licensed, and the destinations stay unambiguous in any language.
*/
Rectangle {
    id: bar

    property var entries: []
    property int currentIndex: 0
    //! Padding at the bottom for a system gesture bar. The surface still
    //! extends under it; only the labels move up.
    property real bottomInset: 0

    signal selected(int index)

    implicitHeight: 62
    color: ThemeManager.surface

    Behavior on color {
        ColorAnimation { duration: 200 }
    }

    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: Qt.rgba(ThemeManager.textSecondary.r,
                       ThemeManager.textSecondary.g,
                       ThemeManager.textSecondary.b, 0.18)
    }

    Row {
        id: entryRow

        anchors.fill: parent
        anchors.topMargin: 1
        anchors.bottomMargin: bar.bottomInset

        Repeater {
            model: bar.entries

            Item {
                id: entry

                required property int index
                required property string modelData

                readonly property bool active: index === bar.currentIndex

                width: bar.width / Math.max(1, bar.entries.length)
                height: entryRow.height

                Column {
                    anchors.centerIn: parent
                    spacing: 5

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 22
                        height: 3
                        radius: 1.5
                        color: ThemeManager.accent
                        opacity: entry.active ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation { duration: 160 }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: entry.modelData
                        font.pixelSize: 12
                        font.bold: entry.active
                        color: entry.active ? ThemeManager.textPrimary : ThemeManager.textSecondary
                    }
                }

                TapHandler {
                    onTapped: bar.selected(entry.index)
                }
            }
        }
    }
}
