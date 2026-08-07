#pragma once

#include <QString>

class QDateTime;
class QTimeZone;

/*!
 * Presentation helpers shared by the time zone picker and the world clock
 * list, so both derive city names and UTC offsets the same way.
 */
namespace TimeZoneFormat {

//! "Asia/Tokyo" -> "Tokyo"; "America/Argentina/Buenos_Aires" -> "Buenos Aires".
QString cityName(const QString &timeZoneId);

//! "America/Argentina/Buenos_Aires" -> "America / Argentina".
QString regionName(const QString &timeZoneId);

//! "UTC+09:00", or "UTC" exactly on the meridian.
QString offsetText(const QTimeZone &zone, const QDateTime &at);

/*!
 * Whole days the zone's date is ahead of (positive) or behind (negative)
 * \a reference. Used for the "Tomorrow" / "Yesterday" badge.
 */
int dayOffset(const QTimeZone &zone, const QDateTime &reference);

} // namespace TimeZoneFormat
