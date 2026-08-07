#pragma once

// Full definition required: moc needs the complete type behind the `laps`
// pointer property.
#include "timing/LapModel.h"

#include <QElapsedTimer>
#include <QObject>
#include <QTimer>
#include <QtQmlIntegration>

/*!
 * Stopwatch with lap recording.
 *
 * As with CountdownTimer, QElapsedTimer is the source of truth and the
 * repeating QTimer exists only to trigger repaints, so the reading stays
 * correct even if repaints are delayed or the system clock is changed.
 */
class Stopwatch : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(qint64 elapsedMs READ elapsedMs NOTIFY elapsedChanged FINAL)
    Q_PROPERTY(QString elapsedText READ elapsedText NOTIFY elapsedChanged FINAL)
    Q_PROPERTY(bool running READ isRunning NOTIFY runningChanged FINAL)
    //! True once started, until reset -- distinguishes "paused" from "cleared".
    Q_PROPERTY(bool started READ isStarted NOTIFY elapsedChanged FINAL)
    Q_PROPERTY(LapModel *laps READ laps CONSTANT FINAL)

public:
    explicit Stopwatch(QObject *parent = nullptr);

    qint64 elapsedMs() const;
    QString elapsedText() const;
    bool isRunning() const { return m_running; }
    bool isStarted() const { return m_running || m_accumulatedMs > 0; }
    LapModel *laps() const { return m_laps; }

public Q_SLOTS:
    void start();
    void stop();
    void reset();
    void lap();

Q_SIGNALS:
    void elapsedChanged();
    void runningChanged();

private:
    //! ~30 fps: the hundredths digit blurs, which is exactly how a stopwatch
    //! reads, without burning a repaint every frame.
    static constexpr int kTickIntervalMs = 33;

    QTimer m_ticker;
    QElapsedTimer m_segment;
    LapModel *m_laps = nullptr;
    //! Time from all previous run segments; the current one is added live.
    qint64 m_accumulatedMs = 0;
    bool m_running = false;
};
