import QtQuick
import FlipClock

/*!
    One settings line: a label (with optional explanatory text) on the left and
    a single control on the right.

    The control is passed as the default child, so call sites read as
    `SettingRow { label: "..."; Switch { ... } }`.
*/
Item {
    id: row

    default property alias control: controlSlot.data

    property string label: ""
    property string description: ""

    implicitWidth: parent ? parent.width : 320
    implicitHeight: Math.max(58, textColumn.implicitHeight + 22)

    Column {
        id: textColumn

        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.right: controlSlot.left
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
            width: parent.width
            text: row.label
            color: ThemeManager.textPrimary
            font.pixelSize: 15
            opacity: row.enabled ? 1.0 : 0.5
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: row.description !== ""
            text: row.description
            color: ThemeManager.textSecondary
            font.pixelSize: 12
            opacity: row.enabled ? 1.0 : 0.5
            wrapMode: Text.WordWrap
        }
    }

    Item {
        id: controlSlot

        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        // Sized from whatever control was slotted in; zero when there is none,
        // which is how the About row renders as pure text.
        width: childrenRect.width
        height: childrenRect.height
    }
}
