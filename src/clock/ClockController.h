#pragma once

#include <QDateTime>
#include <QObject>
#include <QString>
#include <QTimer>
#include <QtQmlIntegration>

/*!
 * The single source of "now" for the whole app.
 *
 * Rather than firing a repeating 1000 ms timer -- which accumulates drift and
 * eventually updates the display visibly off the second boundary -- this
 * re-arms a single-shot timer for the exact remainder of the current second
 * after every tick.
 *
 * Time components are published both as integers and as zero-padded two
 * character strings; the flip display binds one card per character so that
 * only the digits that actually changed animate.
 */
class ClockController : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    //! Bound from AppSettings by QML; kept separate so this class has no
    //! dependency on the settings singleton.
    Q_PROPERTY(bool use24Hour READ use24Hour WRITE setUse24Hour NOTIFY use24HourChanged FINAL)

    Q_PROPERTY(QDateTime now READ now NOTIFY tick FINAL)
    Q_PROPERTY(int hour READ hour NOTIFY tick FINAL)
    Q_PROPERTY(int minute READ minute NOTIFY tick FINAL)
    Q_PROPERTY(int second READ second NOTIFY tick FINAL)
    Q_PROPERTY(QString hourText READ hourText NOTIFY tick FINAL)
    Q_PROPERTY(QString minuteText READ minuteText NOTIFY tick FINAL)
    Q_PROPERTY(QString secondText READ secondText NOTIFY tick FINAL)
    Q_PROPERTY(QString meridiem READ meridiem NOTIFY tick FINAL)
    Q_PROPERTY(QString dateText READ dateText NOTIFY tick FINAL)
    Q_PROPERTY(QString weekdayText READ weekdayText NOTIFY tick FINAL)

public:
    explicit ClockController(QObject *parent = nullptr);

    bool use24Hour() const { return m_use24Hour; }
    void setUse24Hour(bool value);

    QDateTime now() const { return m_now; }
    int hour() const;
    int minute() const { return m_now.time().minute(); }
    int second() const { return m_now.time().second(); }

    QString hourText() const;
    QString minuteText() const;
    QString secondText() const;
    QString meridiem() const;
    QString dateText() const;
    QString weekdayText() const;

public Q_SLOTS:
    /*!
     * Re-reads the wall clock and restarts the tick timer. Call this when the
     * app returns to the foreground: on Android the process is frozen while
     * backgrounded, so the pending timer fires late and the display would
     * otherwise crawl back up to the correct time one second at a time.
     */
    void refresh();

Q_SIGNALS:
    void tick();
    void use24HourChanged();

private:
    void scheduleNextTick();

    QTimer m_timer;
    QDateTime m_now;
    bool m_use24Hour = true;
};
