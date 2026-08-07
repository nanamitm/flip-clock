import QtQuick

/*!
    Top or bottom half of a flip card.

    Both halves render the *whole* card and clip it, rather than each drawing
    its own half of the glyph. That way the digit is split exactly on the fold
    line at any size, with no font-metric guesswork, and the four halves of a
    flip stay pixel-identical where they meet.
*/
Item {
    id: half

    property string value: ""
    //! true renders the card's upper portion, false the lower one.
    property bool topHalf: true

    //! Height of the complete card this is a half of: 2 * height + gap.
    property real cardHeight: height * 2
    property real cardRadius: 8
    property color topColor: "#2b2f3d"
    property color bottomColor: "#1c1f2a"
    property color digitColor: "#ffffff"
    property string fontFamily: ""
    property real fontPixelSize: 100
    //! 0 = lit, 1 = fully in shadow. Drives the folding leaves' shading.
    property real shade: 0

    clip: true

    Rectangle {
        id: face

        width: half.width
        height: half.cardHeight
        // The top half shows rows 0..height; the bottom half shows the last
        // `height` rows, so it has to be pulled up by everything above it.
        y: half.topHalf ? 0 : half.height - half.cardHeight
        radius: half.cardRadius

        gradient: Gradient {
            GradientStop { position: 0.0; color: half.topColor }
            GradientStop { position: 1.0; color: half.bottomColor }
        }

        Text {
            anchors.centerIn: parent
            text: half.value
            color: half.digitColor
            font.family: half.fontFamily !== "" ? half.fontFamily : Qt.application.font.family
            font.pixelSize: half.fontPixelSize
            font.bold: true
        }

        Rectangle {
            anchors.fill: parent
            radius: face.radius
            color: "black"
            opacity: half.shade
            visible: half.shade > 0
        }
    }
}
