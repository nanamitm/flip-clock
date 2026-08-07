import QtQuick
import QtQuick.Controls
import FlipClock

Item {
    id: page

    PageHeader {
        id: header
        width: parent.width
        title: qsTr("Settings")
    }

    Flickable {
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        contentHeight: body.implicitHeight + 28
        clip: true

        Column {
            id: body

            width: parent.width
            spacing: 6

            SettingSection { title: qsTr("Clock") }

            SettingRow {
                label: qsTr("24-hour time")

                ThemedSwitch {
                    checked: AppSettings.use24Hour
                    onToggled: AppSettings.use24Hour = checked
                }
            }

            SettingRow {
                label: qsTr("Show seconds")

                ThemedSwitch {
                    checked: AppSettings.showSeconds
                    onToggled: AppSettings.showSeconds = checked
                }
            }

            SettingRow {
                label: qsTr("Show date")

                ThemedSwitch {
                    checked: AppSettings.showDate
                    onToggled: AppSettings.showDate = checked
                }
            }

            SettingRow {
                label: qsTr("Keep screen on")
                description: ScreenAwake.supported
                    ? qsTr("Stops the display sleeping while the clock is showing")
                    : qsTr("Not available on this platform")
                enabled: ScreenAwake.supported

                ThemedSwitch {
                    checked: AppSettings.keepScreenOn
                    enabled: ScreenAwake.supported
                    onToggled: AppSettings.keepScreenOn = checked
                }
            }

            SettingSection { title: qsTr("Appearance") }

            SettingRow {
                label: qsTr("Flip animation")

                ComboBox {
                    width: 150
                    model: [qsTr("Split-flap"), qsTr("Fade"), qsTr("None")]
                    currentIndex: AppSettings.flipStyle
                    onActivated: AppSettings.flipStyle = currentIndex
                }
            }

            SettingRow {
                label: qsTr("Digit font")

                ComboBox {
                    width: 190
                    model: AppSettings.availableFontFamilies
                    currentIndex: Math.max(0, model.indexOf(AppSettings.fontFamily))
                    // The first entry is the empty string, meaning "whatever
                    // the platform's default is".
                    displayText: currentIndex === 0 ? qsTr("System default") : currentText
                    onActivated: AppSettings.fontFamily = model[currentIndex]
                }
            }

            SettingSection { title: qsTr("Theme") }

            Flow {
                x: 20
                width: parent.width - 40
                spacing: 10
                bottomPadding: 8

                Repeater {
                    model: ThemeManager.themes

                    Rectangle {
                        id: swatch

                        required property var modelData

                        readonly property bool selected: AppSettings.themeId === modelData.id

                        width: 104
                        height: 76
                        radius: 12
                        color: modelData.background
                        border.width: selected ? 2 : 1
                        border.color: selected
                            ? ThemeManager.accent
                            : Qt.rgba(ThemeManager.textSecondary.r,
                                      ThemeManager.textSecondary.g,
                                      ThemeManager.textSecondary.b, 0.25)

                        Column {
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 46
                                height: 26
                                radius: 4
                                color: swatch.modelData.cardTop

                                Text {
                                    anchors.centerIn: parent
                                    text: "12"
                                    color: swatch.modelData.digit
                                    font.pixelSize: 15
                                    font.bold: true
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: swatch.modelData.name
                                color: swatch.modelData.digit
                                font.pixelSize: 11
                            }
                        }

                        TapHandler {
                            onTapped: AppSettings.themeId = swatch.modelData.id
                        }
                    }
                }
            }

            SettingSection { title: qsTr("About") }

            SettingRow {
                label: qsTr("Flip Clock")
                description: qsTr("Alarms ring only while this app is running. Android stops background processes, so keep Flip Clock open for an alarm to sound.")
            }
        }
    }
}
