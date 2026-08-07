#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QTimer>
#include <QtQmlIntegration>

/*!
 * A single countdown timer.
 *
 * Elapsed time comes from QElapsedTimer (monotonic) rather than the wall
 * clock, so changing the system time or crossing a DST boundary mid-countdown
 * cannot make it finish early or late. The repeating QTimer only drives
 * repainting; it is never the source of truth for how much time is left.
 */
class CountdownTimer : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(State state READ state NOTIFY stateChanged FINAL)
    Q_PROPERTY(int durationSeconds READ durationSeconds WRITE setDurationSeconds NOTIFY durationChanged FINAL)
    Q_PROPERTY(qint64 remainingMs READ remainingMs NOTIFY remainingChanged FINAL)
    Q_PROPERTY(QString remainingText READ remainingText NOTIFY remainingChanged FINAL)
    //! 0.0 at the start, 1.0 when finished; drives the progress ring.
    Q_PROPERTY(qreal progress READ progress NOTIFY remainingChanged FINAL)
    Q_PROPERTY(bool running READ isRunning NOTIFY stateChanged FINAL)

public:
    enum State {
        Idle,     //!< Nothing started; showing the configured duration.
        Running,
        Paused,
        Finished, //!< Reached zero and waiting to be acknowledged.
    };
    Q_ENUM(State)

    explicit CountdownTimer(QObject *parent = nullptr);

    State state() const { return m_state; }
    bool isRunning() const { return m_state == Running; }

    int durationSeconds() const { return m_durationMs / 1000; }
    void setDurationSeconds(int seconds);

    qint64 remainingMs() const;
    QString remainingText() const;
    qreal progress() const;

public Q_SLOTS:
    void start();
    void pause();
    void resume();
    void reset();
    //! Extends (or, with a negative value, trims) the running countdown.
    void addSeconds(int seconds);
    //! Acknowledges the Finished state and returns to Idle.
    void acknowledge();

Q_SIGNALS:
    void stateChanged();
    void durationChanged();
    void remainingChanged();
    void finished();

private:
    void setState(State state);
    void onTick();

    QTimer m_ticker;
    QElapsedTimer m_elapsed;
    State m_state = Idle;
    qint64 m_durationMs = 300 * 1000;
    //! Time already consumed before the current run segment (i.e. before a pause).
    qint64 m_consumedMs = 0;
};
