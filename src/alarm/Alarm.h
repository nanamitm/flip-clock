#pragma once

#include <QDateTime>
#include <QJsonObject>
#include <QString>
#include <QUuid>

/*!
 * A single alarm entry. Plain value type: the model owns the list, and QML
 * edits alarms as QVariantMaps rather than as live objects, which keeps the
 * edit sheet trivially cancellable.
 */
struct Alarm
{
    /*!
     * Repeat weekdays as a bit mask. Bit 0 is Monday through bit 6 Sunday,
     * matching QDate::dayOfWeek() minus one. Zero means a one-shot alarm,
     * which disables itself after it rings.
     */
    enum Weekday {
        NoDays = 0,
        Monday = 1 << 0,
        Tuesday = 1 << 1,
        Wednesday = 1 << 2,
        Thursday = 1 << 3,
        Friday = 1 << 4,
        Saturday = 1 << 5,
        Sunday = 1 << 6,
        Weekdays = Monday | Tuesday | Wednesday | Thursday | Friday,
        EveryDay = Weekdays | Saturday | Sunday,
    };

    QUuid id = QUuid::createUuid();
    QString label;
    int hour = 7;
    int minute = 0;
    int repeatDays = NoDays;
    bool enabled = true;
    int snoozeMinutes = 5;
    //! Set while the alarm is snoozed; takes precedence over the daily time.
    QDateTime snoozeUntil;

    /*!
     * The next instant this alarm should ring, or an invalid QDateTime when it
     * never will. Strictly after \a from, so calling this at the exact moment
     * an alarm fires returns the following occurrence rather than the current
     * one.
     */
    QDateTime nextFire(const QDateTime &from) const;

    QString repeatText() const;

    QJsonObject toJson() const;
    static Alarm fromJson(const QJsonObject &json);
};
