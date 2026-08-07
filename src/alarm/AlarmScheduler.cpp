#include "alarm/AlarmScheduler.h"

#include "alarm/AlarmModel.h"

namespace {
/*!
 * Never sleep longer than an hour in one go. Re-arming periodically makes the
 * schedule self-correcting when the wall clock jumps -- a DST transition, a
 * time zone change, or the device waking from suspend -- instead of firing an
 * hour early or late.
 */
constexpr qint64 kMaxSleepMs = 60 * 60 * 1000;
} // namespace

AlarmScheduler::AlarmScheduler(AlarmModel *model)
    : QObject(model)
    , m_model(model)
{
    m_timer.setSingleShot(true);
    m_timer.setTimerType(Qt::PreciseTimer);
    connect(&m_timer, &QTimer::timeout, this, &AlarmScheduler::onTimeout);
}

QString AlarmScheduler::ringingAlarmId() const
{
    return m_ringingId.isNull() ? QString() : m_ringingId.toString(QUuid::WithoutBraces);
}

void AlarmScheduler::reschedule()
{
    m_timer.stop();

    const QDateTime now = QDateTime::currentDateTime();
    QDateTime earliest;
    QUuid earliestId;

    for (const Alarm &alarm : m_model->alarms()) {
        const QDateTime fire = alarm.nextFire(now);
        if (!fire.isValid())
            continue;
        if (!earliest.isValid() || fire < earliest) {
            earliest = fire;
            earliestId = alarm.id;
        }
    }

    const bool changed = earliest != m_nextFire;
    m_nextFire = earliest;
    m_nextId = earliestId;

    if (m_nextFire.isValid()) {
        const qint64 delay = now.msecsTo(m_nextFire);
        m_timer.start(static_cast<int>(qBound(qint64(0), delay, kMaxSleepMs)));
    }

    if (changed)
        Q_EMIT nextFireChanged();
}

void AlarmScheduler::onTimeout()
{
    if (!m_nextFire.isValid())
        return;

    // Woke up early because of the one-hour cap (or because the clock moved
    // backwards): go back to sleep for the remainder.
    if (QDateTime::currentDateTime() < m_nextFire) {
        reschedule();
        return;
    }

    m_ringingId = m_nextId;
    Q_EMIT ringingChanged();
    Q_EMIT alarmTriggered(ringingAlarmId());

    // Arm whatever comes next; dismiss()/snooze() will reschedule again once
    // the user deals with this one.
    reschedule();
}

void AlarmScheduler::stopRinging()
{
    if (m_ringingId.isNull())
        return;
    m_ringingId = QUuid();
    Q_EMIT ringingChanged();
}
