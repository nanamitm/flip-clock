import QtQuick
import FlipClock

/*!
    The full-screen flip clock.

    Two layouts, chosen by aspect ratio rather than by a device breakpoint:

      landscape - hours : minutes : seconds across one row
      portrait  - hours over minutes, with small seconds beneath

    Laying the fields out across a portrait screen would make every card as
    narrow as a sixth of the width; stacking them lets the digits use the space
    that is actually available. Card size is then whichever of the width or
    height budget runs out first, so the clock fills a desktop window and a
    phone equally well with no hard-coded sizes.
*/
Item {
    id: page

    //! Emitted on tap so the shell can toggle its chrome.
    signal toggleChrome()

    readonly property bool landscape: width > height
    readonly property bool stacked: !landscape
    readonly property bool showSeconds: AppSettings.showSeconds

    // All gaps are fractions of the card *width*. Deriving them from cardWidth
    // rather than the other way round is what keeps the sizing below a plain
    // calculation instead of a binding loop.
    readonly property real cardAspect: 1.45 // height / width
    readonly property real digitSpacingRatio: 0.06
    readonly property real fieldSpacingRatio: 0.10
    readonly property real separatorRatio: 0.34
    //! Seconds are secondary information, so they get smaller cards.
    readonly property real secondsScale: 0.55

    readonly property real contentWidth: width * 0.92
    readonly property real contentHeight: height * 0.92
    readonly property real rowSpacing: Math.max(6, height * 0.018)
    readonly property real dateBlockHeight: AppSettings.showDate ? height * 0.17 : height * 0.06

    // --- width budget, in card-width units ---------------------------------
    readonly property int fieldCount: showSeconds ? 3 : 2
    readonly property real widthUnits: stacked
        ? (2 + digitSpacingRatio)
        : fieldCount * (2 + digitSpacingRatio)
          + (fieldCount - 1) * separatorRatio
          + (2 * fieldCount - 2) * fieldSpacingRatio

    // --- height budget, in card-height units -------------------------------
    readonly property int cardRows: stacked ? (showSeconds ? 3 : 2) : 1
    readonly property real heightUnits: stacked
        ? 2 + (showSeconds ? secondsScale : 0)
        : 1

    readonly property real cardWidth: Math.max(24, Math.min(
        contentWidth / widthUnits,
        (contentHeight - dateBlockHeight - cardRows * rowSpacing) / (cardAspect * heightUnits)))

    readonly property real cardHeight: cardWidth * cardAspect
    readonly property real cardSpacing: cardWidth * fieldSpacingRatio
    readonly property real separatorWidth: cardWidth * separatorRatio

    TapHandler {
        onTapped: page.toggleChrome()
    }

    Column {
        anchors.centerIn: parent
        spacing: page.rowSpacing

        // ---- landscape: one row ------------------------------------------
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !page.stacked
            spacing: page.cardSpacing

            FlipGroup {
                value: ClockController.hourText
                cardWidth: page.cardWidth
                cardHeight: page.cardHeight
                digitSpacingRatio: page.digitSpacingRatio
            }

            ColonSeparator {
                anchors.verticalCenter: parent.verticalCenter
                width: page.separatorWidth
                dotSize: Math.max(4, page.cardHeight * 0.075)
            }

            FlipGroup {
                value: ClockController.minuteText
                cardWidth: page.cardWidth
                cardHeight: page.cardHeight
                digitSpacingRatio: page.digitSpacingRatio
            }

            ColonSeparator {
                anchors.verticalCenter: parent.verticalCenter
                visible: page.showSeconds
                width: page.showSeconds ? page.separatorWidth : 0
                dotSize: Math.max(4, page.cardHeight * 0.075)
            }

            FlipGroup {
                visible: page.showSeconds
                value: ClockController.secondText
                cardWidth: page.cardWidth
                cardHeight: page.cardHeight
                digitSpacingRatio: page.digitSpacingRatio
            }
        }

        // ---- portrait: hours over minutes over seconds --------------------
        FlipGroup {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: page.stacked
            value: ClockController.hourText
            cardWidth: page.cardWidth
            cardHeight: page.cardHeight
            digitSpacingRatio: page.digitSpacingRatio
        }

        FlipGroup {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: page.stacked
            value: ClockController.minuteText
            cardWidth: page.cardWidth
            cardHeight: page.cardHeight
            digitSpacingRatio: page.digitSpacingRatio
        }

        FlipGroup {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: page.stacked && page.showSeconds
            value: ClockController.secondText
            cardWidth: page.cardWidth * page.secondsScale
            cardHeight: page.cardHeight * page.secondsScale
            digitSpacingRatio: page.digitSpacingRatio
        }

        // ---- meridiem, weekday, date --------------------------------------
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: page.rowSpacing
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: text !== ""
                text: ClockController.meridiem
                color: ThemeManager.accent
                font.pixelSize: Math.max(13, page.cardHeight * 0.13)
                font.bold: true
                font.letterSpacing: 3
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: AppSettings.showDate
                text: ClockController.weekdayText
                color: ThemeManager.textPrimary
                font.pixelSize: Math.max(14, page.cardHeight * 0.14)
                font.bold: true
                font.letterSpacing: 2
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: AppSettings.showDate
                text: ClockController.dateText
                color: ThemeManager.textSecondary
                font.pixelSize: Math.max(12, page.cardHeight * 0.1)
            }
        }
    }
}
