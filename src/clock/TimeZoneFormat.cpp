#include "clock/TimeZoneFormat.h"

#include <QDateTime>
#include <QStringList>
#include <QTimeZone>

namespace TimeZoneFormat {

QString cityName(const QString &timeZoneId)
{
    QString city = timeZoneId.section(QLatin1Char('/'), -1);
    city.replace(QLatin1Char('_'), QLatin1Char(' '));
    return city;
}

QString regionName(const QString &timeZoneId)
{
    const QStringList parts = timeZoneId.split(QLatin1Char('/'));
    if (parts.size() < 2)
        return {};

    QStringList region = parts.mid(0, parts.size() - 1);
    for (QString &part : region)
        part.replace(QLatin1Char('_'), QLatin1Char(' '));
    return region.join(QStringLiteral(" / "));
}

QString offsetText(const QTimeZone &zone, const QDateTime &at)
{
    if (!zone.isValid())
        return {};

    const int totalSeconds = zone.offsetFromUtc(at);
    if (totalSeconds == 0)
        return QStringLiteral("UTC");

    const QChar sign = totalSeconds < 0 ? QLatin1Char('-') : QLatin1Char('+');
    const int absSeconds = qAbs(totalSeconds);
    return QStringLiteral("UTC%1%2:%3")
        .arg(sign)
        .arg(absSeconds / 3600, 2, 10, QLatin1Char('0'))
        .arg((absSeconds % 3600) / 60, 2, 10, QLatin1Char('0'));
}

int dayOffset(const QTimeZone &zone, const QDateTime &reference)
{
    if (!zone.isValid())
        return 0;

    // Compare calendar dates, not elapsed time: a zone 9 hours ahead is only
    // "tomorrow" once its local date actually rolls over.
    const QDate here = reference.date();
    const QDate there = reference.toTimeZone(zone).date();
    return static_cast<int>(here.daysTo(there));
}

} // namespace TimeZoneFormat
