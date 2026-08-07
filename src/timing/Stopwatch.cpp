#include "timing/Stopwatch.h"

#include "timing/LapModel.h"

Stopwatch::Stopwatch(QObject *parent)
    : QObject(parent)
    , m_laps(new LapModel(this))
{
    m_ticker.setInterval(kTickIntervalMs);
    m_ticker.setTimerType(Qt::PreciseTimer);
    connect(&m_ticker, &QTimer::timeout, this, &Stopwatch::elapsedChanged);
}

qint64 Stopwatch::elapsedMs() const
{
    return m_running ? m_accumulatedMs + m_segment.elapsed() : m_accumulatedMs;
}

QString Stopwatch::elapsedText() const
{
    return LapModel::formatDuration(elapsedMs());
}

void Stopwatch::start()
{
    if (m_running)
        return;

    m_segment.start();
    m_ticker.start();
    m_running = true;
    Q_EMIT runningChanged();
    Q_EMIT elapsedChanged();
}

void Stopwatch::stop()
{
    if (!m_running)
        return;

    m_accumulatedMs += m_segment.elapsed();
    m_ticker.stop();
    m_running = false;
    Q_EMIT runningChanged();
    Q_EMIT elapsedChanged();
}

void Stopwatch::reset()
{
    m_ticker.stop();
    const bool wasRunning = m_running;
    m_running = false;
    m_accumulatedMs = 0;
    m_laps->clear();

    if (wasRunning)
        Q_EMIT runningChanged();
    Q_EMIT elapsedChanged();
}

void Stopwatch::lap()
{
    // Laps only mean something while the watch is actually counting.
    if (!m_running)
        return;
    m_laps->addLap(elapsedMs());
}
