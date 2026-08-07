#include "clock/WorldClockModel.h"

#include "clock/TimeZoneFormat.h"

#include <QSettings>

namespace {
constexpr auto kSettingsKey = "worldClock/timeZoneIds";

//! Cities pre-loaded on first run so the page is never an empty void.
QStringList defaultTimeZoneIds()
{
    return {
        QStringLiteral("America/New_York"),
        QStringLiteral("Europe/London"),
        QStringLiteral("Asia/Tokyo"),
    };
}
} // namespace

WorldClockModel::WorldClockModel(QObject *parent)
    : QAbstractListModel(parent)
    , m_now(QDateTime::currentDateTime())
{
    load();
}

void WorldClockModel::load()
{
    QSettings settings;
    QStringList ids = settings.value(QString::fromLatin1(kSettingsKey)).toStringList();
    if (!settings.contains(QString::fromLatin1(kSettingsKey)))
        ids = defaultTimeZoneIds();

    m_rows.clear();
    m_rows.reserve(ids.size());
    for (const QString &id : std::as_const(ids)) {
        const QTimeZone zone(id.toUtf8());
        if (!zone.isValid())
            continue; // A zone removed from the TZ database since it was saved.
        m_rows.append(Row{id, zone, TimeZoneFormat::cityName(id), TimeZoneFormat::regionName(id)});
    }
}

void WorldClockModel::save() const
{
    QStringList ids;
    ids.reserve(m_rows.size());
    for (const Row &row : m_rows)
        ids.append(row.id);

    QSettings settings;
    settings.setValue(QString::fromLatin1(kSettingsKey), ids);
}

int WorldClockModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_rows.size();
}

QVariant WorldClockModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_rows.size())
        return {};

    const Row &row = m_rows.at(index.row());
    switch (role) {
    case TimeZoneIdRole:
        return row.id;
    case CityRole:
        return row.city;
    case RegionRole:
        return row.region;
    case TimeTextRole: {
        const QTime time = m_now.toTimeZone(row.zone).time();
        const int hour = m_use24Hour ? time.hour() : ((time.hour() + 11) % 12) + 1;
        return QStringLiteral("%1:%2")
            .arg(hour, 2, 10, QLatin1Char('0'))
            .arg(time.minute(), 2, 10, QLatin1Char('0'));
    }
    case MeridiemRole:
        if (m_use24Hour)
            return QString();
        return m_now.toTimeZone(row.zone).time().hour() < 12 ? QStringLiteral("AM")
                                                             : QStringLiteral("PM");
    case OffsetTextRole:
        return TimeZoneFormat::offsetText(row.zone, m_now);
    case DayOffsetRole:
        return TimeZoneFormat::dayOffset(row.zone, m_now);
    case DayOffsetTextRole: {
        const int offset = TimeZoneFormat::dayOffset(row.zone, m_now);
        if (offset > 0)
            return tr("Tomorrow");
        if (offset < 0)
            return tr("Yesterday");
        return QString();
    }
    case IsDaylightTimeRole:
        return row.zone.isDaylightTime(m_now);
    default:
        return {};
    }
}

QHash<int, QByteArray> WorldClockModel::roleNames() const
{
    return {
        {TimeZoneIdRole, "timeZoneId"},
        {CityRole, "city"},
        {RegionRole, "region"},
        {TimeTextRole, "timeText"},
        {MeridiemRole, "meridiem"},
        {OffsetTextRole, "offsetText"},
        {DayOffsetRole, "dayOffset"},
        {DayOffsetTextRole, "dayOffsetText"},
        {IsDaylightTimeRole, "isDaylightTime"},
    };
}

void WorldClockModel::setUse24Hour(bool value)
{
    if (m_use24Hour == value)
        return;
    m_use24Hour = value;
    Q_EMIT use24HourChanged();
    refresh();
}

bool WorldClockModel::contains(const QString &timeZoneId) const
{
    return std::any_of(m_rows.cbegin(), m_rows.cend(), [&timeZoneId](const Row &row) {
        return row.id == timeZoneId;
    });
}

void WorldClockModel::add(const QString &timeZoneId)
{
    if (contains(timeZoneId))
        return;

    const QTimeZone zone(timeZoneId.toUtf8());
    if (!zone.isValid())
        return;

    beginInsertRows(QModelIndex(), m_rows.size(), m_rows.size());
    m_rows.append(Row{timeZoneId,
                      zone,
                      TimeZoneFormat::cityName(timeZoneId),
                      TimeZoneFormat::regionName(timeZoneId)});
    endInsertRows();

    save();
    Q_EMIT countChanged();
}

void WorldClockModel::removeAt(int row)
{
    if (row < 0 || row >= m_rows.size())
        return;

    beginRemoveRows(QModelIndex(), row, row);
    m_rows.removeAt(row);
    endRemoveRows();

    save();
    Q_EMIT countChanged();
}

void WorldClockModel::move(int from, int to)
{
    if (from == to || from < 0 || from >= m_rows.size() || to < 0 || to >= m_rows.size())
        return;

    // beginMoveRows wants the destination *before* the row is taken out, which
    // is one further along when moving downwards.
    const int destination = to > from ? to + 1 : to;
    beginMoveRows(QModelIndex(), from, from, QModelIndex(), destination);
    m_rows.move(from, to);
    endMoveRows();

    save();
}

void WorldClockModel::refresh()
{
    if (m_rows.isEmpty())
        return;

    m_now = QDateTime::currentDateTime();
    Q_EMIT dataChanged(index(0), index(m_rows.size() - 1),
                       {TimeTextRole, MeridiemRole, OffsetTextRole, DayOffsetRole,
                        DayOffsetTextRole, IsDaylightTimeRole});
}
