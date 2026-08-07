import QtQuick
import FlipClock

/*!
    One split-flap digit.

    Layering, bottom to top:

      1. static top half    - shows the incoming digit
      2. static bottom half - shows the outgoing digit
      3. folding top leaf   - outgoing digit, rotates 0 -> -90 about the fold
      4. folding bottom leaf - incoming digit, rotates 90 -> 0 about the fold

    Phase 1 drops the old top out of the way, revealing the new top behind it;
    phase 2 drops the new bottom over the old one. Only the two leaves are
    animated, and only when `value` actually changes -- binding one card per
    character means the seconds card flips every second while the hours card
    stays completely idle.
*/
Item {
    id: card

    property string value: "0"
    property int flipStyle: AppSettings.flipStyle
    property int flipDuration: 340

    property real cardRadius: Math.max(3, height * 0.07)
    //! Space between the two halves; the fold line lives here.
    property real gap: Math.max(1, Math.round(height * 0.015))
    property real fontPixelSize: height * 0.7

    property color topColor: ThemeManager.cardTop
    property color bottomColor: ThemeManager.cardBottom
    property color digitColor: ThemeManager.digit
    property color dividerColor: ThemeManager.divider
    property string fontFamily: AppSettings.fontFamily

    readonly property real halfHeight: (height - gap) / 2

    // What each layer currently shows. `_current` only advances once the
    // animation completes, which is what keeps the outgoing digit on screen
    // for the first half of the flip.
    property string _current: value
    property string _incoming: value
    property bool _flipping: false

    implicitWidth: 120
    implicitHeight: 180

    onValueChanged: {
        if (value === _current && !_flipping)
            return

        if (flipStyle === AppSettings.Instant) {
            splitFlapAnimation.stop()
            fadeAnimation.stop()
            _flipping = false
            _incoming = value
            _current = value
            return
        }

        _incoming = value

        if (flipStyle === AppSettings.Fade) {
            _flipping = false
            fadeAnimation.restart()
            return
        }

        _flipping = true
        splitFlapAnimation.restart()
    }

    Item {
        id: staticLayer
        anchors.fill: parent

        FlipCardHalf {
            id: topStatic
            topHalf: true
            // Mid-flip the top already belongs to the new digit; at rest both
            // halves agree, so this collapses to `_current`.
            value: card._flipping ? card._incoming : card._current
            width: card.width
            height: card.halfHeight
            cardHeight: card.height
            cardRadius: card.cardRadius
            topColor: card.topColor
            bottomColor: card.bottomColor
            digitColor: card.digitColor
            fontFamily: card.fontFamily
            fontPixelSize: card.fontPixelSize
            anchors.top: parent.top
        }

        FlipCardHalf {
            id: bottomStatic
            topHalf: false
            value: card._current
            width: card.width
            height: card.halfHeight
            cardHeight: card.height
            cardRadius: card.cardRadius
            topColor: card.topColor
            bottomColor: card.bottomColor
            digitColor: card.digitColor
            fontFamily: card.fontFamily
            fontPixelSize: card.fontPixelSize
            anchors.bottom: parent.bottom
        }
    }

    // The fold line. Sits in the gap between the halves, so no leaf ever
    // overlaps it.
    Rectangle {
        y: card.halfHeight
        width: card.width
        height: card.gap
        color: card.dividerColor
    }

    FlipCardHalf {
        id: topLeaf
        topHalf: true
        value: card._current
        visible: card._flipping
        width: card.width
        height: card.halfHeight
        cardHeight: card.height
        cardRadius: card.cardRadius
        topColor: card.topColor
        bottomColor: card.bottomColor
        digitColor: card.digitColor
        fontFamily: card.fontFamily
        fontPixelSize: card.fontPixelSize
        anchors.top: parent.top
        // Darkens as it turns away from the light.
        shade: Math.abs(topRotation.angle) / 90 * 0.6

        transform: Rotation {
            id: topRotation
            origin.x: card.width / 2
            origin.y: card.halfHeight
            axis { x: 1; y: 0; z: 0 }
            angle: 0
        }
    }

    FlipCardHalf {
        id: bottomLeaf
        topHalf: false
        value: card._incoming
        visible: card._flipping
        width: card.width
        height: card.halfHeight
        cardHeight: card.height
        cardRadius: card.cardRadius
        topColor: card.topColor
        bottomColor: card.bottomColor
        digitColor: card.digitColor
        fontFamily: card.fontFamily
        fontPixelSize: card.fontPixelSize
        y: card.halfHeight + card.gap
        shade: Math.abs(bottomRotation.angle) / 90 * 0.6

        transform: Rotation {
            id: bottomRotation
            origin.x: card.width / 2
            origin.y: 0
            axis { x: 1; y: 0; z: 0 }
            angle: 0
        }
    }

    SequentialAnimation {
        id: splitFlapAnimation

        // Park the leaves before showing them: without this the incoming
        // bottom leaf would be sitting flat at 0 degrees and cover the
        // outgoing digit for the whole first phase.
        PropertyAction { target: topRotation; property: "angle"; value: 0 }
        PropertyAction { target: bottomRotation; property: "angle"; value: 90 }

        NumberAnimation {
            target: topRotation
            property: "angle"
            to: -90
            duration: card.flipDuration / 2
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: bottomRotation
            property: "angle"
            to: 0
            duration: card.flipDuration / 2
            easing.type: Easing.OutBounce
        }

        ScriptAction {
            script: {
                card._current = card._incoming
                card._flipping = false
            }
        }
    }

    SequentialAnimation {
        id: fadeAnimation

        NumberAnimation {
            target: staticLayer
            property: "opacity"
            to: 0
            duration: card.flipDuration / 2
            easing.type: Easing.InQuad
        }
        ScriptAction { script: card._current = card._incoming }
        NumberAnimation {
            target: staticLayer
            property: "opacity"
            to: 1
            duration: card.flipDuration / 2
            easing.type: Easing.OutQuad
        }
    }
}
