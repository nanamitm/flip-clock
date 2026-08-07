#pragma once

#include "alarm/Alarm.h"
// Full definition required: moc needs the complete type behind the
// `scheduler` pointer property.
#include "alarm/AlarmScheduler.h"

#include <QAbstractListModel>
#include <QVariantMap>
#include <QtQmlIntegration>

/*!
 * The user's alarms, persisted as JSON under QStandardPaths::AppDataLocation.
 *
 * QML sees each alarm as a QVariantMap (see at() / save()) instead of a live
 * object: the edit sheet mutates a copy, so dismissing it discards the changes
 * without any undo bookkeeping here.
 */
class AlarmModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int count READ rowCount NOTIFY countChanged FINAL)
    Q_PROPERTY(bool use24Hour READ use24Hour WRITE setUse24Hour NOTIFY use24HourChanged FINAL)
    Q_PROPERTY(AlarmScheduler *scheduler READ scheduler CONSTANT FINAL)
    //! Human-readable "Rings in 7 h 12 min", or empty when nothing is armed.
    Q_PROPERTY(QString nextAlarmText READ nextAlarmText NOTIFY scheduleChanged FINAL)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        LabelRole,
        HourRole,
        MinuteRole,
        TimeTextRole,
        MeridiemRole,
        RepeatDaysRole,
        RepeatTextRole,
        EnabledRole,
        SnoozeMinutesRole,
        IsSnoozedRole,
    };
    Q_ENUM(Roles)

    explicit AlarmModel(QObject *parent = nullptr);
    ~AlarmModel() override;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool use24Hour() const { return m_use24Hour; }
    void setUse24Hour(bool value);

    AlarmScheduler *scheduler() const { return m_scheduler; }
    QString nextAlarmText() const;

    //! C++-side access for AlarmScheduler; not exposed to QML.
    const QList<Alarm> &alarms() const { return m_alarms; }

    //! A blank alarm map for the "new alarm" sheet, defaulted to the next hour.
    Q_INVOKABLE QVariantMap createDraft() const;
    //! The alarm at \a row as an editable map, or an empty map if out of range.
    Q_INVOKABLE QVariantMap at(int row) const;

    //! Inserts or updates depending on whether \a alarm's id is already known.
    Q_INVOKABLE void save(const QVariantMap &alarm);
    Q_INVOKABLE void removeAt(int row);
    Q_INVOKABLE void setEnabledAt(int row, bool enabled);

    //! Re-arms \a alarmId to ring again after its snooze interval.
    Q_INVOKABLE void snooze(const QString &alarmId);
    /*!
     * Stops \a alarmId ringing. One-shot alarms switch themselves off; repeating
     * alarms stay armed for their next weekday.
     */
    Q_INVOKABLE void dismiss(const QString &alarmId);

    //! Lookup used by the ringing screen to title itself.
    Q_INVOKABLE QVariantMap byId(const QString &alarmId) const;

Q_SIGNALS:
    void countChanged();
    void use24HourChanged();
    void scheduleChanged();

private:
    int indexOfId(const QUuid &id) const;
    QVariantMap toMap(const Alarm &alarm) const;
    QString timeTextFor(const Alarm &alarm) const;

    void load();
    void persist();
    //! Emitted after any change that can move the next ring time.
    void rescheduled();

    QString storagePath() const;

    QList<Alarm> m_alarms;
    AlarmScheduler *m_scheduler = nullptr;
    bool m_use24Hour = true;
};
