#include "timing/LapModel.h"

#include <limits>

LapModel::LapModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

QString LapModel::formatDuration(qint64 ms)
{
    const qint64 hundredths = (ms / 10) % 100;
    const qint64 totalSeconds = ms / 1000;
    const qint64 hours = totalSeconds / 3600;
    const qint64 minutes = (totalSeconds % 3600) / 60;
    const qint64 seconds = totalSeconds % 60;

    if (hours > 0) {
        return QStringLiteral("%1:%2:%3.%4")
            .arg(hours)
            .arg(minutes, 2, 10, QLatin1Char('0'))
            .arg(seconds, 2, 10, QLatin1Char('0'))
            .arg(hundredths, 2, 10, QLatin1Char('0'));
    }
    return QStringLiteral("%1:%2.%3")
        .arg(minutes, 2, 10, QLatin1Char('0'))
        .arg(seconds, 2, 10, QLatin1Char('0'))
        .arg(hundredths, 2, 10, QLatin1Char('0'));
}

int LapModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_laps.size();
}

QVariant LapModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_laps.size())
        return {};

    const Lap &lap = m_laps.at(index.row());
    switch (role) {
    case LapNumberRole:
        return lap.number;
    case LapTextRole:
        return formatDuration(lap.lapMs);
    case TotalTextRole:
        return formatDuration(lap.totalMs);
    case IsFastestRole:
        // A single lap is neither fastest nor slowest -- there is nothing to
        // compare it against, and highlighting it both ways looks broken.
        return m_laps.size() > 1 && lap.number == m_fastestNumber;
    case IsSlowestRole:
        return m_laps.size() > 1 && lap.number == m_slowestNumber;
    default:
        return {};
    }
}

QHash<int, QByteArray> LapModel::roleNames() const
{
    return {
        {LapNumberRole, "lapNumber"},
        {LapTextRole, "lapText"},
        {TotalTextRole, "totalText"},
        {IsFastestRole, "isFastest"},
        {IsSlowestRole, "isSlowest"},
    };
}

void LapModel::addLap(qint64 totalMs)
{
    const qint64 previousTotal = m_laps.isEmpty() ? 0 : m_laps.first().totalMs;

    beginInsertRows(QModelIndex(), 0, 0);
    m_laps.prepend(Lap{static_cast<int>(m_laps.size()) + 1, totalMs - previousTotal, totalMs});
    endInsertRows();

    updateExtremes();
    Q_EMIT countChanged();
}

void LapModel::updateExtremes()
{
    m_fastestNumber = -1;
    m_slowestNumber = -1;
    if (m_laps.size() < 2)
        return;

    qint64 fastest = std::numeric_limits<qint64>::max();
    qint64 slowest = std::numeric_limits<qint64>::min();
    for (const Lap &lap : std::as_const(m_laps)) {
        if (lap.lapMs < fastest) {
            fastest = lap.lapMs;
            m_fastestNumber = lap.number;
        }
        if (lap.lapMs > slowest) {
            slowest = lap.lapMs;
            m_slowestNumber = lap.number;
        }
    }

    Q_EMIT dataChanged(index(0), index(m_laps.size() - 1), {IsFastestRole, IsSlowestRole});
}

void LapModel::clear()
{
    if (m_laps.isEmpty())
        return;

    beginResetModel();
    m_laps.clear();
    m_fastestNumber = -1;
    m_slowestNumber = -1;
    endResetModel();

    Q_EMIT countChanged();
}
