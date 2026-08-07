import QtQuick

/*!
    A two-digit time field (hours, minutes or seconds).

    Each character gets its own FlipCard so that, for example, the tens-of-
    minutes card sits still for ten minutes at a time while the units card
    flips every minute.
*/
Row {
    id: group

    //! Always two characters, zero padded.
    property string value: "00"
    property real cardWidth: 100
    property real cardHeight: 150
    property int flipDuration: 340
    //! Gap between the two cards, as a fraction of cardWidth. Callers that
    //! lay several groups out themselves need this to size the row.
    property real digitSpacingRatio: 0.06

    spacing: Math.max(2, cardWidth * digitSpacingRatio)

    FlipCard {
        value: group.value.charAt(0)
        width: group.cardWidth
        height: group.cardHeight
        flipDuration: group.flipDuration
    }

    FlipCard {
        value: group.value.charAt(1)
        width: group.cardWidth
        height: group.cardHeight
        flipDuration: group.flipDuration
    }
}
