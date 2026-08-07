#include "clock/TimeZoneListModel.h"

#include "clock/TimeZoneFormat.h"

#include <QDateTime>
#include <QTimeZone>

TimeZoneListModel::TimeZoneListModel(QObject *parent)
    : QAbstractListModel(parent)
    , m_all(buildCatalogue())
{
    applyFilter();
}

QList<TimeZoneListModel::Entry> TimeZoneListModel::buildCatalogue()
{
    const QDateTime now = QDateTime::currentDateTime();

    QList<Entry> entries;
    const QList<QByteArray> ids = QTimeZone::availableTimeZoneIds();
    entries.reserve(ids.size());

    for (const QByteArray &rawId : ids) {
        const QString id = QString::fromUtf8(rawId);

        // Keep only Region/City zones. The rest are fixed-offset ("Etc/GMT+3"),
        // legacy compatibility aliases ("US/Pacific", "SystemV/EST5") or
        // TZ-database internals ("posix/...", "right/..."), none of which the
        // user would recognise as a place.
        if (!id.contains(QLatin1Char('/')))
            continue;
        if (id.startsWith(QLatin1String("Etc/")) || id.startsWith(QLatin1String("SystemV/"))
            || id.startsWith(QLatin1String("posix/")) || id.startsWith(QLatin1String("right/"))
            || id.startsWith(QLatin1String("US/")) || id.startsWith(QLatin1String("Canada/"))
            || id.startsWith(QLatin1String("Brazil/")) || id.startsWith(QLatin1String("Mexico/"))
            || id.startsWith(QLatin1String("Chile/")) || id.startsWith(QLatin1String("Australia/ACT"))
            || id.startsWith(QLatin1String("Australia/LHI")) || id.startsWith(QLatin1String("Australia/NSW"))) {
            continue;
        }

        const QTimeZone zone(rawId);
        if (!zone.isValid())
            continue;

        Entry entry;
        entry.id = id;
        entry.city = TimeZoneFormat::cityName(id);
        entry.region = TimeZoneFormat::regionName(id);
        entry.offsetText = TimeZoneFormat::offsetText(zone, now);
        entry.searchKey = (entry.city + QLatin1Char(' ') + entry.region + QLatin1Char(' ') + id).toLower();
        entries.append(entry);
    }

    std::sort(entries.begin(), entries.end(), [](const Entry &a, const Entry &b) {
        if (a.city != b.city)
            return a.city.localeAwareCompare(b.city) < 0;
        return a.region.localeAwareCompare(b.region) < 0;
    });

    return entries;
}

void TimeZoneListModel::applyFilter()
{
    beginResetModel();
    m_visible.clear();
    const QString needle = m_filter.trimmed().toLower();
    for (int i = 0; i < m_all.size(); ++i) {
        if (needle.isEmpty() || m_all.at(i).searchKey.contains(needle))
            m_visible.append(i);
    }
    endResetModel();
    Q_EMIT countChanged();
}

void TimeZoneListModel::setFilter(const QString &value)
{
    if (m_filter == value)
        return;
    m_filter = value;
    applyFilter();
    Q_EMIT filterChanged();
}

int TimeZoneListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_visible.size();
}

QVariant TimeZoneListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_visible.size())
        return {};

    const Entry &entry = m_all.at(m_visible.at(index.row()));
    switch (role) {
    case TimeZoneIdRole:
        return entry.id;
    case CityRole:
        return entry.city;
    case RegionRole:
        return entry.region;
    case OffsetTextRole:
        return entry.offsetText;
    default:
        return {};
    }
}

QHash<int, QByteArray> TimeZoneListModel::roleNames() const
{
    return {
        {TimeZoneIdRole, "timeZoneId"},
        {CityRole, "city"},
        {RegionRole, "region"},
        {OffsetTextRole, "offsetText"},
    };
}
