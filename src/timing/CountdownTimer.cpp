#include "timing/CountdownTimer.h"

namespace {
//! Fast enough for a smooth progress ring without repainting every frame.
constexpr int kTickIntervalMs = 50;
} // namespace

CountdownTimer::CountdownTimer(QObject *parent)
    : QObject(parent)
{
    m_ticker.setInterval(kTickIntervalMs);
    m_ticker.setTimerType(Qt::PreciseTimer);
    connect(&m_ticker, &QTimer::timeout, this, &CountdownTimer::onTick);
}

void CountdownTimer::setDurationSeconds(int seconds)
{
    const qint64 ms = qMax(1, seconds) * 1000LL;
    if (m_durationMs == ms)
        return;

    m_durationMs = ms;
    Q_EMIT durationChanged();

    // Changing the duration only makes sense as a fresh start; a running
    // countdown keeps its own duration until it is reset.
    if (m_state == Idle || m_state == Finished) {
        m_consumedMs = 0;
        setState(Idle);
        Q_EMIT remainingChanged();
    }
}

qint64 CountdownTimer::remainingMs() const
{
    qint64 consumed = m_consumedMs;
    if (m_state == Running)
        consumed += m_elapsed.elapsed();
    return qMax(0LL, m_durationMs - consumed);
}

QString CountdownTimer::remainingText() const
{
    // Round up so the display shows "1" for the whole final second rather than
    // sitting on "0" while time is still left.
    const qint64 totalSeconds = (remainingMs() + 999) / 1000;
    const qint64 hours = totalSeconds / 3600;
    const qint64 minutes = (totalSeconds % 3600) / 60;
    const qint64 seconds = totalSeconds % 60;

    if (hours > 0) {
        return QStringLiteral("%1:%2:%3")
            .arg(hours)
            .arg(minutes, 2, 10, QLatin1Char('0'))
            .arg(seconds, 2, 10, QLatin1Char('0'));
    }
    return QStringLiteral("%1:%2")
        .arg(minutes, 2, 10, QLatin1Char('0'))
        .arg(seconds, 2, 10, QLatin1Char('0'));
}

qreal CountdownTimer::progress() const
{
    if (m_durationMs <= 0)
        return 0.0;
    return 1.0 - static_cast<qreal>(remainingMs()) / static_cast<qreal>(m_durationMs);
}

void CountdownTimer::setState(State state)
{
    if (m_state == state)
        return;
    m_state = state;
    Q_EMIT stateChanged();
}

void CountdownTimer::start()
{
    m_consumedMs = 0;
    m_elapsed.start();
    m_ticker.start();
    setState(Running);
    Q_EMIT remainingChanged();
}

void CountdownTimer::pause()
{
    if (m_state != Running)
        return;

    m_consumedMs += m_elapsed.elapsed();
    m_ticker.stop();
    setState(Paused);
    Q_EMIT remainingChanged();
}

void CountdownTimer::resume()
{
    if (m_state != Paused)
        return;

    m_elapsed.start();
    m_ticker.start();
    setState(Running);
    Q_EMIT remainingChanged();
}

void CountdownTimer::reset()
{
    m_ticker.stop();
    m_consumedMs = 0;
    setState(Idle);
    Q_EMIT remainingChanged();
}

void CountdownTimer::addSeconds(int seconds)
{
    const qint64 delta = seconds * 1000LL;
    // Keep at least one second on the clock so "+1 min" on a nearly finished
    // timer does not immediately re-trigger the finish.
    m_durationMs = qMax(m_consumedMs + (m_state == Running ? m_elapsed.elapsed() : 0) + 1000,
                        m_durationMs + delta);
    Q_EMIT durationChanged();
    Q_EMIT remainingChanged();

    // Adding time to a finished countdown puts it back to work.
    if (m_state == Finished && remainingMs() > 0) {
        m_elapsed.start();
        m_ticker.start();
        setState(Running);
    }
}

void CountdownTimer::acknowledge()
{
    if (m_state != Finished)
        return;
    reset();
}

void CountdownTimer::onTick()
{
    Q_EMIT remainingChanged();

    if (remainingMs() > 0)
        return;

    m_ticker.stop();
    m_consumedMs = m_durationMs;
    setState(Finished);
    Q_EMIT finished();
}
