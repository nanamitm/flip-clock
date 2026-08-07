import QtQuick
import QtQuick.Controls
import FlipClock

/*!
    Create/edit sheet for a single alarm.

    Edits a copy of the alarm map; nothing reaches the model until Save, so
    Cancel needs no undo bookkeeping. `existingIndex` is -1 for a new alarm,
    which is also what hides the Delete button.
*/
Item {
    id: sheet

    property var draft: ({})
    property int existingIndex: -1

    visible: false

    function openDraft() {
        draft = AlarmModel.createDraft()
        existingIndex = -1
        syncFromDraft()
        visible = true
    }

    function openExisting(index) {
        draft = AlarmModel.at(index)
        existingIndex = index
        syncFromDraft()
        visible = true
    }

    function syncFromDraft() {
        hourTumbler.currentIndex = draft.hour
        minuteTumbler.currentIndex = draft.minute
        labelField.text = draft.label
        repeatMask = draft.repeatDays
        snoozeBox.currentIndex = Math.max(0, snoozeBox.model.indexOf(draft.snoozeMinutes))
    }

    property int repeatMask: 0

    function save() {
        const updated = {
            alarmId: draft.alarmId,
            label: labelField.text,
            hour: hourTumbler.currentIndex,
            minute: minuteTumbler.currentIndex,
            repeatDays: repeatMask,
            enabled: true, // Saving an alarm always arms it.
            snoozeMinutes: snoozeBox.model[snoozeBox.currentIndex]
        }
        AlarmModel.save(updated)
        visible = false
    }

    Rectangle {
        anchors.fill: parent
        // Fully opaque: even a couple of percent of transparency leaves the
        // page underneath legible through the sheet.
        color: ThemeManager.background

        // Swallow taps so they cannot reach the alarm list underneath.
        TapHandler {}
    }

    Item {
        id: header

        width: parent.width
        height: 66

        PillButton {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Cancel")

            onClicked: sheet.visible = false
        }

        Text {
            anchors.centerIn: parent
            text: sheet.existingIndex < 0 ? qsTr("New alarm") : qsTr("Edit alarm")
            color: ThemeManager.textPrimary
            font.pixelSize: 18
            font.bold: true
        }

        PillButton {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            accented: true
            text: qsTr("Save")

            onClicked: sheet.save()
        }
    }

    Flickable {
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        contentHeight: body.implicitHeight + 32
        clip: true

        Column {
            id: body

            width: parent.width
            spacing: 20
            topPadding: 8

            // ---- time ----------------------------------------------------
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Tumbler {
                    id: hourTumbler

                    width: 92
                    height: 190
                    visibleItemCount: 5
                    model: 24
                    wrap: true

                    delegate: Text {
                        required property int modelData
                        required property int index

                        text: {
                            if (AppSettings.use24Hour)
                                return String(modelData).padStart(2, "0")
                            const display = ((modelData + 11) % 12) + 1
                            return String(display).padStart(2, "0")
                                + (modelData < 12 ? " AM" : " PM")
                        }
                        color: ThemeManager.textPrimary
                        opacity: 1.0 - Math.abs(Tumbler.displacement) / 2.4
                        font.pixelSize: AppSettings.use24Hour ? 28 : 19
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ":"
                    color: ThemeManager.textSecondary
                    font.pixelSize: 28
                    font.bold: true
                }

                Tumbler {
                    id: minuteTumbler

                    width: 92
                    height: 190
                    visibleItemCount: 5
                    model: 60
                    wrap: true

                    delegate: Text {
                        required property int modelData
                        // Tumbler.displacement is only available on a delegate
                        // that exposes `index`.
                        required property int index

                        text: String(modelData).padStart(2, "0")
                        color: ThemeManager.textPrimary
                        opacity: 1.0 - Math.abs(Tumbler.displacement) / 2.4
                        font.pixelSize: 28
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // ---- repeat --------------------------------------------------
            Column {
                width: parent.width
                spacing: 10

                Text {
                    x: 20
                    text: qsTr("Repeat")
                    color: ThemeManager.textSecondary
                    font.pixelSize: 13
                    font.bold: true
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    Repeater {
                        // Monday-first, matching the bit order in Alarm::Weekday.
                        model: 7

                        Rectangle {
                            id: dayChip

                            required property int index

                            readonly property int bit: 1 << index
                            readonly property bool selected: (sheet.repeatMask & bit) !== 0

                            width: 40
                            height: 40
                            radius: 20
                            color: selected ? ThemeManager.accent : ThemeManager.surfaceAlt

                            Behavior on color {
                                ColorAnimation { duration: 130 }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: Qt.locale().dayName(dayChip.index + 1, Locale.ShortFormat).charAt(0)
                                color: dayChip.selected ? "#ffffff" : ThemeManager.textSecondary
                                font.pixelSize: 14
                                font.bold: true
                            }

                            TapHandler {
                                onTapped: sheet.repeatMask ^= dayChip.bit
                            }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: sheet.repeatMask === 0
                        ? qsTr("Rings once, then turns itself off")
                        : qsTr("Repeats every selected day")
                    color: ThemeManager.textSecondary
                    font.pixelSize: 12
                }
            }

            // ---- label ---------------------------------------------------
            Column {
                width: parent.width
                spacing: 8

                Text {
                    x: 20
                    text: qsTr("Label")
                    color: ThemeManager.textSecondary
                    font.pixelSize: 13
                    font.bold: true
                }

                TextField {
                    id: labelField

                    x: 20
                    width: parent.width - 40
                    height: 44
                    placeholderText: qsTr("Wake up")
                    color: ThemeManager.textPrimary
                    placeholderTextColor: ThemeManager.textSecondary
                    leftPadding: 14
                    font.pixelSize: 15

                    background: Rectangle {
                        radius: 12
                        color: ThemeManager.surfaceAlt
                    }
                }
            }

            // ---- snooze --------------------------------------------------
            Row {
                x: 20
                width: parent.width - 40
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Snooze")
                    color: ThemeManager.textSecondary
                    font.pixelSize: 13
                    font.bold: true
                }

                ComboBox {
                    id: snoozeBox

                    anchors.verticalCenter: parent.verticalCenter
                    width: 130
                    model: [1, 3, 5, 10, 15, 20, 30]
                    currentIndex: 2

                    displayText: qsTr("%1 min").arg(model[currentIndex])
                }
            }

            // ---- delete --------------------------------------------------
            PillButton {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: sheet.existingIndex >= 0
                text: qsTr("Delete alarm")
                tint: "#e2564a"

                onClicked: {
                    AlarmModel.removeAt(sheet.existingIndex)
                    sheet.visible = false
                }
            }
        }
    }
}
