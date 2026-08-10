import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import FlipClock

ApplicationWindow {
    id: app

    width: 1080
    height: 660
    minimumWidth: AppSettings.compactMode ? 300 : 320
    minimumHeight: AppSettings.compactMode ? 130 : 460
    visible: true
    title: qsTr("Flip Clock")
    color: ThemeManager.background
    flags: AppSettings.compactMode && Qt.platform.os === "windows"
           ? Qt.FramelessWindowHint
             | (AppSettings.alwaysOnTop ? Qt.WindowStaysOnTopHint : 0)
             | (AppSettings.clickThrough ? Qt.WindowTransparentForInput : 0)
           : Qt.Window
    opacity: AppSettings.compactMode && Qt.platform.os === "windows" ? AppSettings.compactOpacity : 1.0

    //! Hidden on the clock page for an unobstructed display; tap to bring back.
    property bool chromeVisible: true
    property bool restoringCompactPosition: false
    property bool compactPositionReady: false
    // The accessory opens at a compact but readable desk-clock size every
    // time.  Keeping this fixed avoids a tiny or oversized window being
    // carried over from a temporary resize on a different monitor.
    function useDefaultCompactGeometry() {
        width = 380
        height = 150
        if (AppSettings.hasCompactPosition) {
            restoringCompactPosition = true
            x = AppSettings.compactX
            y = AppSettings.compactY
            restoringCompactPosition = false
        }
    }

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

    Binding {
        target: ScreenAwake
        property: "enabled"
        // Scoped to the window actually being on screen. Android already ties
        // FLAG_KEEP_SCREEN_ON to window visibility, but Windows keeps a
        // SetThreadExecutionState request alive for the whole process, so
        // without this a minimised clock would go on blocking display sleep.
        value: AppSettings.keepScreenOn
               && app.visible
               && app.visibility !== Window.Minimized
    }

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

    Connections {
        target: AppSettings
        function onCompactModeChanged() {
            if (AppSettings.compactMode) {
                app.useDefaultCompactGeometry()
                app.compactPositionReady = true
            } else {
                app.width = 1080
                app.height = 660
            }
        }
    }

    // Accessing the singleton instantiates the Windows notification-area
    // icon.  Its menu remains reachable when the compact window is set to
    // click-through, so that mode can never strand the user.
    Connections {
        target: DesktopController
        function onShowCompactRequested() {
            AppSettings.clickThrough = false
            AppSettings.compactMode = true
            app.show()
            app.raise()
            app.requestActivate()
        }
        function onOpenFullAppRequested() {
            AppSettings.clickThrough = false
            AppSettings.compactMode = false
            app.show()
            app.raise()
            app.requestActivate()
        }
        function onDisableClickThroughRequested() {
            AppSettings.clickThrough = false
        }
        function onQuitRequested() { Qt.quit() }
    }

    Component.onCompleted: {
        if (AppSettings.compactMode && Qt.platform.os === "windows")
            useDefaultCompactGeometry()
        compactPositionReady = true
    }

    onXChanged: {
        if (AppSettings.compactMode && compactPositionReady && !restoringCompactPosition)
            AppSettings.compactX = x
    }

    onYChanged: {
        if (AppSettings.compactMode && compactPositionReady && !restoringCompactPosition)
            AppSettings.compactY = y
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
        visible: !AppSettings.compactMode || Qt.platform.os !== "windows"
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

    DesktopClockPage {
        anchors.fill: parent
        visible: AppSettings.compactMode && Qt.platform.os === "windows"
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
