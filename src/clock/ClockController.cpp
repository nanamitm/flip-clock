#include "clock/ClockController.h"

#include <QLocale>
#include <QRegularExpression>

ClockController::ClockController(QObject *parent)
    : QObject(parent)
    , m_now(QDateTime::currentDateTime())
{
    m_timer.setSingleShot(true);
    m_timer.setTimerType(Qt::PreciseTimer);
    connect(&m_timer, &QTimer::timeout, this, [this] {
        m_now = QDateTime::currentDateTime();
        Q_EMIT tick();
        scheduleNextTick();
    });
    scheduleNextTick();
}

void ClockController::scheduleNextTick()
{
    // Aim at the next whole second rather than "one second from now": the
    // latter drifts by however long the previous tick's work took.
    const int msIntoSecond = static_cast<int>(QDateTime::currentMSecsSinceEpoch() % 1000);
    m_timer.start(1000 - msIntoSecond);
}

void ClockController::refresh()
{
    m_now = QDateTime::currentDateTime();
    Q_EMIT tick();
    scheduleNextTick();
}

void ClockController::setUse24Hour(bool value)
{
    if (m_use24Hour == value)
        return;
    m_use24Hour = value;
    Q_EMIT use24HourChanged();
    // The hour text and meridiem derive from this, so republish them.
    Q_EMIT tick();
}

int ClockController::hour() const
{
    const int h = m_now.time().hour();
    if (m_use24Hour)
        return h;
    // 0 -> 12, 13 -> 1, 12 -> 12.
    return ((h + 11) % 12) + 1;
}

QString ClockController::hourText() const
{
    return QStringLiteral("%1").arg(hour(), 2, 10, QLatin1Char('0'));
}

QString ClockController::minuteText() const
{
    return QStringLiteral("%1").arg(minute(), 2, 10, QLatin1Char('0'));
}

QString ClockController::secondText() const
{
    return QStringLiteral("%1").arg(second(), 2, 10, QLatin1Char('0'));
}

QString ClockController::meridiem() const
{
    if (m_use24Hour)
        return {};
    return m_now.time().hour() < 12 ? QStringLiteral("AM") : QStringLiteral("PM");
}

QString ClockController::dateText() const
{
    const QLocale locale = QLocale::system();

    // Most locales fold the weekday into their long date format ("dddd, MMMM d,
    // yyyy" in en_US, "yyyy年M月d日dddd" in ja_JP). The UI shows the weekday on
    // its own line, so strip those tokens and tidy up the separators they leave
    // behind rather than printing the day name twice.
    QString format = locale.dateFormat(QLocale::LongFormat);
    format.remove(QLatin1String("dddd"));
    format.remove(QLatin1String("ddd"));

    static const QRegularExpression leadingSeparators(QStringLiteral("^[\\s,\\-/.]+"));
    static const QRegularExpression trailingSeparators(QStringLiteral("[\\s,\\-/.]+$"));
    format.remove(leadingSeparators);
    format.remove(trailingSeparators);

    if (format.isEmpty())
        return locale.toString(m_now.date(), QLocale::ShortFormat);

    return locale.toString(m_now.date(), format);
}

QString ClockController::weekdayText() const
{
    return QLocale::system().dayName(m_now.date().dayOfWeek(), QLocale::LongFormat);
}
