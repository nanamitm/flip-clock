#pragma once

#include <QDateTime>
#include <QObject>
#include <QTimer>
#include <QUuid>
#include <QtQmlIntegration>

class AlarmModel;

/*!
 * Arms a single timer for whichever alarm rings first.
 *
 * Keeping one timer rather than one per alarm means the cost is independent of
 * how many alarms exist, and there is a single place that has to survive the
 * long-delay clamp below.
 *
 * \note This only rings while the app is running. Firing from a stopped
 * process needs Android's AlarmManager, which this build deliberately does not
 * use.
 */
class AlarmScheduler : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Obtained from AlarmModel.scheduler")

    Q_PROPERTY(QDateTime nextFire READ nextFire NOTIFY nextFireChanged FINAL)
    //! Id of the alarm currently ringing, empty when silent.
    Q_PROPERTY(QString ringingAlarmId READ ringingAlarmId NOTIFY ringingChanged FINAL)

public:
    explicit AlarmScheduler(AlarmModel *model);

    QDateTime nextFire() const { return m_nextFire; }
    QString ringingAlarmId() const;

    //! Recomputes the next fire time from the model. Cheap; call after any edit.
    void reschedule();

    //! Clears the ringing state without touching the alarm itself.
    void stopRinging();

Q_SIGNALS:
    void nextFireChanged();
    void ringingChanged();
    void alarmTriggered(const QString &alarmId);

private:
    void onTimeout();

    AlarmModel *m_model;
    QTimer m_timer;
    QDateTime m_nextFire;
    QUuid m_nextId;
    QUuid m_ringingId;
};
