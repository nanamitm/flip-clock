import QtQuick
import QtMultimedia

/*!
    Looping alert tone shared by the ringing alarm and the finished timer.

    Wrapping MediaPlayer keeps the two call sites from each having to manage an
    AudioOutput and remember to stop playback on teardown.
*/
Item {
    id: root

    property alias source: player.source
    property real volume: 0.85
    //! Set true to sound the alert; setting it false stops immediately.
    property bool active: false

    MediaPlayer {
        id: player
        loops: MediaPlayer.Infinite
        audioOutput: AudioOutput { volume: root.volume }
    }

    onActiveChanged: active ? player.play() : player.stop()

    // The alert must not outlive the screen that raised it -- a Loader
    // unloading its component would otherwise leave the tone playing.
    Component.onDestruction: player.stop()
}
