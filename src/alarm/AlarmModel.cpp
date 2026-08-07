#include "alarm/AlarmModel.h"

#include "alarm/AlarmScheduler.h"

#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QSaveFile>
#include <QStandardPaths>

AlarmModel::AlarmModel(QObject *parent)
    : QAbstractListModel(parent)
    , m_scheduler(new AlarmScheduler(this))
{
    load();
    m_scheduler->reschedule();

    connect(m_scheduler, &AlarmScheduler::nextFireChanged, this, &AlarmModel::scheduleChanged);
}

AlarmModel::~AlarmModel() = default;

QString AlarmModel::storagePath() const
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    return dir + QStringLiteral("/alarms.json");
}

void AlarmModel::load()
{
    QFile file(storagePath());
    if (!file.open(QIODevice::ReadOnly))
        return; // First run, or the file was removed: start with no alarms.

    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    if (!doc.isArray())
        return;

    const QJsonArray array = doc.array();
    m_alarms.reserve(array.size());
    for (const QJsonValue &value : array) {
        if (value.isObject())
            m_alarms.append(Alarm::fromJson(value.toObject()));
    }
}

void AlarmModel::persist()
{
    QJsonArray array;
    for (const Alarm &alarm : std::as_const(m_alarms))
        array.append(alarm.toJson());

    // QSaveFile writes to a temporary and renames, so a crash mid-write leaves
    // the previous alarm list intact rather than a truncated file.
    QSaveFile file(storagePath());
    if (!file.open(QIODevice::WriteOnly))
        return;
    file.write(QJsonDocument(array).toJson(QJsonDocument::Indented));
    file.commit();
}

void AlarmModel::rescheduled()
{
    persist();
    m_scheduler->reschedule();
    Q_EMIT scheduleChanged();
}

int AlarmModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_alarms.size();
}

QString AlarmModel::timeTextFor(const Alarm &alarm) const
{
    const int hour = m_use24Hour ? alarm.hour : ((alarm.hour + 11) % 12) + 1;
    return QStringLiteral("%1:%2")
        .arg(hour, 2, 10, QLatin1Char('0'))
        .arg(alarm.minute, 2, 10, QLatin1Char('0'));
}

QVariant AlarmModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_alarms.size())
        return {};

    const Alarm &alarm = m_alarms.at(index.row());
    switch (role) {
    case IdRole:
        return alarm.id.toString(QUuid::WithoutBraces);
    case LabelRole:
        return alarm.label;
    case HourRole:
        return alarm.hour;
    case MinuteRole:
        return alarm.minute;
    case TimeTextRole:
        return timeTextFor(alarm);
    case MeridiemRole:
        return m_use24Hour ? QString()
                           : (alarm.hour < 12 ? QStringLiteral("AM") : QStringLiteral("PM"));
    case RepeatDaysRole:
        return alarm.repeatDays;
    case RepeatTextRole:
        return alarm.repeatText();
    case EnabledRole:
        return alarm.enabled;
    case SnoozeMinutesRole:
        return alarm.snoozeMinutes;
    case IsSnoozedRole:
        return alarm.snoozeUntil.isValid() && alarm.snoozeUntil > QDateTime::currentDateTime();
    default:
        return {};
    }
}

QHash<int, QByteArray> AlarmModel::roleNames() const
{
    return {
        {IdRole, "alarmId"},
        {LabelRole, "label"},
        {HourRole, "hour"},
        {MinuteRole, "minute"},
        {TimeTextRole, "timeText"},
        {MeridiemRole, "meridiem"},
        {RepeatDaysRole, "repeatDays"},
        {RepeatTextRole, "repeatText"},
        // Not "enabled": that would collide with Item.enabled in the QML
        // delegate and shadow it.
        {EnabledRole, "alarmEnabled"},
        {SnoozeMinutesRole, "snoozeMinutes"},
        {IsSnoozedRole, "isSnoozed"},
    };
}

void AlarmModel::setUse24Hour(bool value)
{
    if (m_use24Hour == value)
        return;
    m_use24Hour = value;
    Q_EMIT use24HourChanged();
    if (!m_alarms.isEmpty()) {
        Q_EMIT dataChanged(index(0), index(m_alarms.size() - 1), {TimeTextRole, MeridiemRole});
    }
}

int AlarmModel::indexOfId(const QUuid &id) const
{
    for (int i = 0; i < m_alarms.size(); ++i) {
        if (m_alarms.at(i).id == id)
            return i;
    }
    return -1;
}

QVariantMap AlarmModel::toMap(const Alarm &alarm) const
{
    return {
        {QStringLiteral("alarmId"), alarm.id.toString(QUuid::WithoutBraces)},
        {QStringLiteral("label"), alarm.label},
        {QStringLiteral("hour"), alarm.hour},
        {QStringLiteral("minute"), alarm.minute},
        {QStringLiteral("repeatDays"), alarm.repeatDays},
        {QStringLiteral("enabled"), alarm.enabled},
        {QStringLiteral("snoozeMinutes"), alarm.snoozeMinutes},
        {QStringLiteral("timeText"), timeTextFor(alarm)},
        {QStringLiteral("repeatText"), alarm.repeatText()},
    };
}

QVariantMap AlarmModel::createDraft() const
{
    Alarm alarm;
    // Default to the top of the next hour -- the most common thing a user is
    // about to type anyway.
    const QTime now = QTime::currentTime();
    alarm.hour = (now.hour() + 1) % 24;
    alarm.minute = 0;

    QVariantMap map = toMap(alarm);
    map[QStringLiteral("alarmId")] = QString(); // Empty id marks it as new.
    return map;
}

QVariantMap AlarmModel::at(int row) const
{
    if (row < 0 || row >= m_alarms.size())
        return {};
    return toMap(m_alarms.at(row));
}

QVariantMap AlarmModel::byId(const QString &alarmId) const
{
    const int row = indexOfId(QUuid::fromString(alarmId));
    return row < 0 ? QVariantMap{} : toMap(m_alarms.at(row));
}

void AlarmModel::save(const QVariantMap &map)
{
    const QUuid id = QUuid::fromString(map.value(QStringLiteral("alarmId")).toString());
    const int row = id.isNull() ? -1 : indexOfId(id);

    Alarm alarm = row >= 0 ? m_alarms.at(row) : Alarm{};
    alarm.label = map.value(QStringLiteral("label"), alarm.label).toString();
    alarm.hour = qBound(0, map.value(QStringLiteral("hour"), alarm.hour).toInt(), 23);
    alarm.minute = qBound(0, map.value(QStringLiteral("minute"), alarm.minute).toInt(), 59);
    alarm.repeatDays = map.value(QStringLiteral("repeatDays"), alarm.repeatDays).toInt()
                       & Alarm::EveryDay;
    alarm.enabled = map.value(QStringLiteral("enabled"), alarm.enabled).toBool();
    alarm.snoozeMinutes = qBound(1,
                                 map.value(QStringLiteral("snoozeMinutes"), alarm.snoozeMinutes).toInt(),
                                 60);
    // Editing an alarm cancels any snooze it was sitting in.
    alarm.snoozeUntil = QDateTime();

    if (row >= 0) {
        m_alarms[row] = alarm;
        Q_EMIT dataChanged(index(row), index(row));
    } else {
        beginInsertRows(QModelIndex(), m_alarms.size(), m_alarms.size());
        m_alarms.append(alarm);
        endInsertRows();
        Q_EMIT countChanged();
    }

    rescheduled();
}

void AlarmModel::removeAt(int row)
{
    if (row < 0 || row >= m_alarms.size())
        return;

    beginRemoveRows(QModelIndex(), row, row);
    m_alarms.removeAt(row);
    endRemoveRows();

    Q_EMIT countChanged();
    rescheduled();
}

void AlarmModel::setEnabledAt(int row, bool enabled)
{
    if (row < 0 || row >= m_alarms.size())
        return;
    if (m_alarms.at(row).enabled == enabled)
        return;

    m_alarms[row].enabled = enabled;
    m_alarms[row].snoozeUntil = QDateTime();
    Q_EMIT dataChanged(index(row), index(row), {EnabledRole, IsSnoozedRole});
    rescheduled();
}

void AlarmModel::snooze(const QString &alarmId)
{
    const int row = indexOfId(QUuid::fromString(alarmId));
    if (row < 0)
        return;

    Alarm &alarm = m_alarms[row];
    alarm.snoozeUntil = QDateTime::currentDateTime().addSecs(alarm.snoozeMinutes * 60);
    Q_EMIT dataChanged(index(row), index(row), {IsSnoozedRole});

    m_scheduler->stopRinging();
    rescheduled();
}

void AlarmModel::dismiss(const QString &alarmId)
{
    const int row = indexOfId(QUuid::fromString(alarmId));
    if (row >= 0) {
        Alarm &alarm = m_alarms[row];
        alarm.snoozeUntil = QDateTime();
        // A one-shot alarm has done its job; a repeating one stays armed for
        // its next weekday.
        if (alarm.repeatDays == Alarm::NoDays)
            alarm.enabled = false;
        Q_EMIT dataChanged(index(row), index(row), {EnabledRole, IsSnoozedRole});
    }

    m_scheduler->stopRinging();
    rescheduled();
}

QString AlarmModel::nextAlarmText() const
{
    const QDateTime next = m_scheduler->nextFire();
    if (!next.isValid())
        return {};

    const QDateTime now = QDateTime::currentDateTime();
    const qint64 minutes = (now.secsTo(next) + 59) / 60; // Round up: "in 1 min", never "in 0 min".
    if (minutes <= 0)
        return tr("Ringing now");

    const qint64 days = minutes / (24 * 60);
    const qint64 hours = (minutes % (24 * 60)) / 60;
    const qint64 mins = minutes % 60;

    if (days > 0)
        return tr("Rings in %1 d %2 h").arg(days).arg(hours);
    if (hours > 0)
        return tr("Rings in %1 h %2 min").arg(hours).arg(mins);
    return tr("Rings in %1 min").arg(mins);
}
