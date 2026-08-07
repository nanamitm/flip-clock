cmake_minimum_required(VERSION 3.21.1)

project(FlipClock
    VERSION 1.0.0
    DESCRIPTION "Flip clock with world clock, alarms, timer and stopwatch"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# The presets resolve Qt through environment variables that tools/common.ps1
# (or the CI workflow) fills in. Catch the unset case here rather than letting
# find_package fail with a bare "could not find Qt6Config.cmake".
if(NOT CMAKE_PREFIX_PATH AND NOT QT_HOST_PATH AND NOT DEFINED Qt6_DIR)
    message(FATAL_ERROR
        "Qt was not located. Run the build through tools/build-windows.ps1 or "
        "tools/build-android.ps1, or set QT_DIR_DESKTOP (and QT_DIR_ANDROID_* "
        "for Android) before invoking the CMake preset. See README.md.")
endif()

# Qt 6.9 is the floor: Main.qml uses the SafeArea attached type, added in 6.9,
# to keep content clear of the Android status bar and gesture area.
# QuickShapes is deliberately absent: TimerPage's dial uses Shapes only from
# QML, so the module is pulled in as a QML plugin by qmlimportscanner at deploy
# time. Linking it explicitly buys nothing and breaks on Qt builds that do not
# export a Qt6QuickShapes package (6.9.3 from aqtinstall, for one).
find_package(Qt6 6.9 REQUIRED COMPONENTS Core Gui Quick QuickControls2 Multimedia Svg)

qt_standard_project_setup(REQUIRES 6.9)

qt_add_executable(appFlipClock
    src/main.cpp
)

if(WIN32)
    # Gives the .exe its shell icon. The resource script has to be compiled by
    # the RC toolchain, which is not enabled by a CXX-only project().
    enable_language(RC)
    target_sources(appFlipClock PRIVATE assets/icons/appicon.rc)
endif()

# ---------------------------------------------------------------------------
# QML module
#
# The .qml files live in per-feature subdirectories on disk for readability,
# but a QML module only makes types visible to each other when they sit in the
# same module directory. QT_RESOURCE_ALIAS flattens each file to the module
# root so every component is importable from every other one without extra
# imports, while the source tree stays organised.
# ---------------------------------------------------------------------------
set(APP_QML_FILES
    qml/Main.qml

    qml/clock/FlipCardHalf.qml
    qml/clock/FlipCard.qml
    qml/clock/FlipGroup.qml
    qml/clock/FlipClockPage.qml
    qml/clock/WorldClockPage.qml
    qml/clock/TimeZonePickerSheet.qml

    qml/alarm/AlarmPage.qml
    qml/alarm/AlarmEditSheet.qml
    qml/alarm/AlarmRingScreen.qml

    qml/timing/TimerPage.qml
    qml/timing/StopwatchPage.qml

    qml/settings/SettingsPage.qml

    qml/common/AlertSound.qml
    qml/common/ColonSeparator.qml
    qml/common/NavBar.qml
    qml/common/PageHeader.qml
    qml/common/PillButton.qml
    qml/common/SettingRow.qml
    qml/common/SettingSection.qml
    qml/common/ThemedSwitch.qml
)

foreach(qml_file IN LISTS APP_QML_FILES)
    get_filename_component(qml_name "${qml_file}" NAME)
    set_source_files_properties("${qml_file}" PROPERTIES QT_RESOURCE_ALIAS "${qml_name}")
endforeach()

set(APP_CPP_SOURCES
    src/app/AppSettings.h            src/app/AppSettings.cpp
    src/app/ScreenAwake.h            src/app/ScreenAwake.cpp
    src/theme/ThemeManager.h         src/theme/ThemeManager.cpp
    src/clock/ClockController.h      src/clock/ClockController.cpp
    src/clock/TimeZoneFormat.h       src/clock/TimeZoneFormat.cpp
    src/clock/TimeZoneListModel.h    src/clock/TimeZoneListModel.cpp
    src/clock/WorldClockModel.h      src/clock/WorldClockModel.cpp
    src/alarm/Alarm.h                src/alarm/Alarm.cpp
    src/alarm/AlarmModel.h           src/alarm/AlarmModel.cpp
    src/alarm/AlarmScheduler.h       src/alarm/AlarmScheduler.cpp
    src/timing/CountdownTimer.h      src/timing/CountdownTimer.cpp
    src/timing/Stopwatch.h           src/timing/Stopwatch.cpp
    src/timing/LapModel.h            src/timing/LapModel.cpp
)

# Alert tones keep their relative path so QML can reference them as
# "assets/sounds/alarm.wav" from the (flattened) module root.
set(APP_RESOURCES
    assets/sounds/alarm.wav
    assets/sounds/timer.wav
    assets/icons/appicon.png
)

qt_add_qml_module(appFlipClock
    URI FlipClock
    VERSION 1.0
    QML_FILES ${APP_QML_FILES}
    SOURCES ${APP_CPP_SOURCES}
    RESOURCES ${APP_RESOURCES}
)

# `src` supports the "clock/ClockController.h" style used inside the sources.
# The per-feature directories are needed as well because the QML type
# registration code Qt generates includes each header by bare file name.
target_include_directories(appFlipClock PRIVATE
    src
    src/alarm
    src/app
    src/clock
    src/theme
    src/timing
)

target_compile_definitions(appFlipClock PRIVATE
    APP_VERSION="${PROJECT_VERSION}"
)

target_link_libraries(appFlipClock PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Multimedia
    Qt6::Svg           # lets QIcon load the SVG application icon
)

set_target_properties(appFlipClock PROPERTIES
    WIN32_EXECUTABLE TRUE
    MACOSX_BUNDLE FALSE
)

if(ANDROID)
    set_target_properties(appFlipClock PROPERTIES
        QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android"
        QT_ANDROID_MIN_SDK_VERSION 28
        QT_ANDROID_TARGET_SDK_VERSION 35
        QT_ANDROID_PACKAGE_NAME "com.example.flipclock"
        QT_ANDROID_APP_NAME "Flip Clock"
        QT_ANDROID_VERSION_CODE ${PROJECT_VERSION_MAJOR}
        QT_ANDROID_VERSION_NAME ${PROJECT_VERSION}
    )
endif()

install(TARGETS appFlipClock
    BUNDLE  DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

# Android packaging is handled by androiddeployqt via the `apk` target;
# qt_generate_deploy_qml_app_script explicitly rejects cross-compiled targets.
if(NOT ANDROID)
    qt_generate_deploy_qml_app_script(
        TARGET appFlipClock
        OUTPUT_SCRIPT deploy_script
    )
    install(SCRIPT ${deploy_script})
endif()
