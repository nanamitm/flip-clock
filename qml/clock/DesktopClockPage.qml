import QtQuick
import QtQuick.Controls
import FlipClock

/*
    The desktop accessory deliberately keeps the split-flap cards as its
    primary surface.  This is not a small text clock: its quiet state is a
    physical-looking desk clock, with controls available only on hover or a
    right-click so they do not compete with the time.
*/
Item {
    id: page

    readonly property bool showSeconds: AppSettings.showSeconds
    readonly property real margin: Math.max(12, Math.min(width, height) * 0.06)
    readonly property real cardAspect: 1.45
    readonly property real digitGapRatio: 0.055
    readonly property real fieldGapRatio: 0.11
    readonly property real separatorRatio: 0.28
    readonly property int fieldCount: showSeconds ? 3 : 2
    readonly property real widthUnits: fieldCount * (2 + digitGapRatio)
        + (fieldCount - 1) * (separatorRatio + fieldGapRatio * 2)
    // Reserve a fixed fraction of the window rather than deriving this from
    // dateLabel's font size, which itself follows cardHeight.
    readonly property real dateBlockHeight: AppSettings.showDate ? Math.max(18, height * 0.13) : 0
    readonly property real usableHeight: height - margin * 2 - dateBlockHeight - 12
    readonly property real cardWidth: Math.max(30, Math.min(
        (width - margin * 2) / widthUnits,
        usableHeight / cardAspect))
    readonly property real cardHeight: cardWidth * cardAspect

    Rectangle {
        anchors.fill: parent
        radius: Math.max(12, page.margin)
        color: ThemeManager.background
        border.width: 1
        border.color: Qt.rgba(ThemeManager.textSecondary.r,
                               ThemeManager.textSecondary.g,
                               ThemeManager.textSecondary.b, 0.22)
    }

    Row {
        id: clockRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -page.dateBlockHeight / 2
        spacing: page.cardWidth * page.fieldGapRatio

        FlipGroup {
            value: ClockController.hourText
            cardWidth: page.cardWidth
            cardHeight: page.cardHeight
            digitSpacingRatio: page.digitGapRatio
        }

        ColonSeparator {
            anchors.verticalCenter: parent.verticalCenter
            width: page.cardWidth * page.separatorRatio
            dotSize: Math.max(4, page.cardHeight * 0.07)
        }

        FlipGroup {
            value: ClockController.minuteText
            cardWidth: page.cardWidth
            cardHeight: page.cardHeight
            digitSpacingRatio: page.digitGapRatio
        }

        ColonSeparator {
            anchors.verticalCenter: parent.verticalCenter
            visible: page.showSeconds
            width: visible ? page.cardWidth * page.separatorRatio : 0
            dotSize: Math.max(4, page.cardHeight * 0.06)
        }

        FlipGroup {
            visible: page.showSeconds
            value: ClockController.secondText
            cardWidth: page.cardWidth
            cardHeight: page.cardHeight
            digitSpacingRatio: page.digitGapRatio
        }
    }

    Text {
        id: dateLabel
        anchors.top: clockRow.bottom
        anchors.topMargin: Math.max(5, page.cardHeight * 0.055)
        anchors.horizontalCenter: parent.horizontalCenter
        visible: AppSettings.showDate
        text: ClockController.weekdayText + "  " + ClockController.dateText
        color: ThemeManager.textSecondary
        font.pixelSize: Math.max(11, page.cardHeight * 0.105)
        font.bold: true
        font.letterSpacing: 1.2
    }

    Rectangle {
        id: hoverBar
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: controls.implicitWidth + 20
        height: controls.implicitHeight + 12
        radius: height / 2
        color: Qt.rgba(ThemeManager.surface.r, ThemeManager.surface.g,
                       ThemeManager.surface.b, 0.94)
        opacity: (hover.hovered || controls.hovered) && !AppSettings.clickThrough ? 1 : 0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 150 } }

        Row {
            id: controls
            anchors.centerIn: parent
            spacing: 8
            property bool hovered: pinHover.hovered || secondsHover.hovered || settingsHover.hovered

            ToolButton {
                id: pinButton
                text: AppSettings.alwaysOnTop ? qsTr("Pinned") : qsTr("Pin")
                onClicked: AppSettings.alwaysOnTop = !AppSettings.alwaysOnTop
                HoverHandler { id: pinHover }
            }
            ToolButton {
                text: qsTr("Seconds")
                onClicked: AppSettings.showSeconds = !AppSettings.showSeconds
                HoverHandler { id: secondsHover }
            }
            ToolButton {
                text: qsTr("Open")
                onClicked: AppSettings.compactMode = false
                HoverHandler { id: settingsHover }
            }
        }
    }

    HoverHandler { id: hover }

    DragHandler {
        enabled: !AppSettings.clickThrough
        target: null
        onActiveChanged: if (active) page.Window.window.startSystemMove()
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: contextMenu.popup()
    }

    Menu {
        id: contextMenu

        MenuItem {
            text: AppSettings.alwaysOnTop ? qsTr("Disable always on top") : qsTr("Always on top")
            onTriggered: AppSettings.alwaysOnTop = !AppSettings.alwaysOnTop
        }
        MenuItem {
            text: AppSettings.showSeconds ? qsTr("Hide seconds") : qsTr("Show seconds")
            onTriggered: AppSettings.showSeconds = !AppSettings.showSeconds
        }
        MenuSeparator {}
        MenuItem {
            text: qsTr("Click-through (use the tray menu to turn it off)")
            checkable: true
            checked: AppSettings.clickThrough
            onTriggered: AppSettings.clickThrough = checked
        }
        Menu {
            title: qsTr("Opacity")
            Repeater {
                model: [1.0, 0.85, 0.7, 0.55]
                MenuItem {
                    required property real modelData
                    text: Math.round(modelData * 100) + "%"
                    checkable: true
                    checked: Math.abs(AppSettings.compactOpacity - modelData) < 0.01
                    onTriggered: AppSettings.compactOpacity = modelData
                }
            }
        }
        MenuSeparator {}
        MenuItem {
            text: qsTr("Open full app")
            onTriggered: AppSettings.compactMode = false
        }
        MenuSeparator {}
        MenuItem {
            text: qsTr("Quit Flip Clock")
            onTriggered: Qt.quit()
        }
    }
}
