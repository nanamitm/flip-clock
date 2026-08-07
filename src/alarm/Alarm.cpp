#include "alarm/Alarm.h"

#include <QCoreApplication>
#include <QLocale>
#include <QStringList>

QDateTime Alarm::nextFire(const QDateTime &from) const
{
    if (!enabled)
        return {};

    if (snoozeUntil.isValid() && snoozeUntil > from)
        return snoozeUntil;

    const QTime target(hour, minute);

    // Look at today plus the next seven days: that is always enough to find
    // the next matching weekday, and it lets the loop below handle one-shot
    // and repeating alarms with the same code.
    for (int dayOffset = 0; dayOffset <= 7; ++dayOffset) {
        const QDate date = from.date().addDays(dayOffset);

        if (repeatDays != NoDays) {
            const int bit = 1 << (date.dayOfWeek() - 1);
            if (!(repeatDays & bit))
                continue;
        }

        QDateTime candidate(date, target);
        if (!candidate.isValid()) {
            // The wall clock skipped this time (spring-forward DST gap); ring
            // an hour later rather than silently never ringing.
            candidate = QDateTime(date, target.addSecs(3600));
            if (!candidate.isValid())
                continue;
        }

        if (candidate > from)
            return candidate;
    }

    return {};
}

QString Alarm::repeatText() const
{
    if (repeatDays == NoDays)
        return QCoreApplication::translate("Alarm", "Once");
    if (repeatDays == EveryDay)
        return QCoreApplication::translate("Alarm", "Every day");
    if (repeatDays == Weekdays)
        return QCoreApplication::translate("Alarm", "Weekdays");
    if (repeatDays == (Saturday | Sunday))
        return QCoreApplication::translate("Alarm", "Weekends");

    const QLocale locale = QLocale::system();
    QStringList names;
    for (int day = 1; day <= 7; ++day) {
        if (repeatDays & (1 << (day - 1)))
            names.append(locale.dayName(day, QLocale::ShortFormat));
    }
    return names.join(QStringLiteral(", "));
}

QJsonObject Alarm::toJson() const
{
    QJsonObject json{
        {QStringLiteral("id"), id.toString(QUuid::WithoutBraces)},
        {QStringLiteral("label"), label},
        {QStringLiteral("hour"), hour},
        {QStringLiteral("minute"), minute},
        {QStringLiteral("repeatDays"), repeatDays},
        {QStringLiteral("enabled"), enabled},
        {QStringLiteral("snoozeMinutes"), snoozeMinutes},
    };
    // A snooze is deliberately not persisted: after a restart the alarm should
    // fall back to its scheduled time rather than ringing at a stale offset.
    return json;
}

Alarm Alarm::fromJson(const QJsonObject &json)
{
    Alarm alarm;
    alarm.id = QUuid::fromString(json.value(QStringLiteral("id")).toString());
    if (alarm.id.isNull())
        alarm.id = QUuid::createUuid();
    alarm.label = json.value(QStringLiteral("label")).toString();
    alarm.hour = qBound(0, json.value(QStringLiteral("hour")).toInt(7), 23);
    alarm.minute = qBound(0, json.value(QStringLiteral("minute")).toInt(0), 59);
    alarm.repeatDays = json.value(QStringLiteral("repeatDays")).toInt(NoDays) & EveryDay;
    alarm.enabled = json.value(QStringLiteral("enabled")).toBool(true);
    alarm.snoozeMinutes = qBound(1, json.value(QStringLiteral("snoozeMinutes")).toInt(5), 60);
    return alarm;
}
