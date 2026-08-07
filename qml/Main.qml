import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import FlipClock

ApplicationWindow {
    id: app

    width: 1080
    height: 660
    minimumWidth: 320
    minimumHeight: 460
    visible: true
    title: qsTr("Flip Clock")
    color: ThemeManager.background

    //! Hidden on the clock page for an unobstructed display; tap to bring back.
    property bool chromeVisible: true

    Behavior on color {
        ColorAnimation { duration: 240 }
    }

    // Qt Quick Controls in the Basic style draw from the palette, so feeding
    // the theme in here is what makes switches, combo boxes, text fields and
    // tumblers follow the selected palette instead of staying default grey.
    palette.window: ThemeManager.background
    palette.windowText: ThemeManager.textPrimary
    palette.base: ThemeManager.surfaceAlt
    palette.alternateBase: ThemeManager.surface
    palette.text: ThemeManager.textPrimary
    palette.placeholderText: ThemeManager.textSecondary
    palette.button: ThemeManager.surfaceAlt
    palette.buttonText: ThemeManager.textPrimary
    palette.accent: ThemeManager.accent
    palette.highlight: ThemeManager.accent
    palette.highlightedText: "#ffffff"

    // ---- settings fan-out --------------------------------------------------
    // The C++ singletons deliberately do not read AppSettings themselves, so
    // the dependency lives here and stays one-directional.
    Binding { target: ClockController; property: "use24Hour"; value: AppSettings.use24Hour }
    Binding { target: WorldClockModel; property: "use24Hour"; value: AppSettings.use24Hour }
    Binding { target: AlarmModel; property: "use24Hour"; value: AppSettings.use24Hour }
    Binding { target: ThemeManager; property: "themeId"; value: AppSettings.themeId }
    Binding { target: ScreenAwake; property: "enabled"; value: AppSettings.keepScreenOn }

    // Android freezes the process while backgrounded, so the pending tick
    // fires late on return. Resynchronise instead of crawling back up to the
    // right time one second per second.
    Connections {
        target: Qt.application
        function onStateChanged() {
            if (Qt.application.state === Qt.ApplicationActive) {
                ClockController.refresh()
                WorldClockModel.refresh()
            }
        }
    }

    Shortcut {
        sequences: ["F11"]
        onActivated: app.visibility = app.visibility === Window.FullScreen
            ? Window.Windowed
            : Window.FullScreen
    }

    Shortcut {
        sequence: "Esc"
        onActivated: {
            if (app.visibility === Window.FullScreen)
                app.visibility = Window.Windowed
            else if (!app.chromeVisible)
                app.chromeVisible = true
        }
    }

    // ---- content -----------------------------------------------------------
    // Reads the system bar insets without being affected by them: anchoring
    // the content margins to an item's own SafeArea would feed its geometry
    // back into the value it is reading.
    Item {
        id: safeArea
        anchors.fill: parent
        visible: false
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        StackLayout {
            id: pages

            Layout.fillWidth: true
            Layout.fillHeight: true
            // Clear of the status bar / notch. The window background still
            // runs full-bleed underneath it.
            Layout.topMargin: safeArea.SafeArea.margins.top
            Layout.leftMargin: safeArea.SafeArea.margins.left
            Layout.rightMargin: safeArea.SafeArea.margins.right
            currentIndex: 0

            onCurrentIndexChanged: {
                // Chrome only auto-hides on the clock; every other page needs
                // its navigation to stay reachable.
                if (currentIndex !== 0)
                    app.chromeVisible = true
            }

            FlipClockPage {
                onToggleChrome: app.chromeVisible = !app.chromeVisible
            }

            WorldClockPage {}
            AlarmPage {}
            TimerPage {}
            StopwatchPage {}
            SettingsPage {}
        }

        NavBar {
            id: navBar

            Layout.fillWidth: true
            // The bar's surface extends under the gesture pill, but its labels
            // stay above it.
            Layout.preferredHeight: app.chromeVisible
                ? implicitHeight + safeArea.SafeArea.margins.bottom
                : 0

            bottomInset: safeArea.SafeArea.margins.bottom
            clip: true
            currentIndex: pages.currentIndex
            entries: [qsTr("Clock"), qsTr("World"), qsTr("Alarm"),
                      qsTr("Timer"), qsTr("Stopwatch"), qsTr("Settings")]

            onSelected: index => pages.currentIndex = index

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
            }
        }
    }

    // ---- ringing alarm -----------------------------------------------------
    // Sits above everything, including the navigation, so a ringing alarm
    // cannot be navigated away from without being dealt with.
    Loader {
        anchors.fill: parent
        active: AlarmModel.scheduler.ringingAlarmId !== ""
        sourceComponent: AlarmRingScreen {
            alarmId: AlarmModel.scheduler.ringingAlarmId
        }
    }
}
