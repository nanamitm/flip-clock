#include "app/AppSettings.h"

#include <QFontDatabase>
#include <QLocale>

namespace {

constexpr auto kUse24Hour = "clock/use24Hour";
constexpr auto kShowSeconds = "clock/showSeconds";
constexpr auto kShowDate = "clock/showDate";
constexpr auto kKeepScreenOn = "clock/keepScreenOn";
constexpr auto kThemeId = "appearance/themeId";
constexpr auto kFontFamily = "appearance/fontFamily";
constexpr auto kFlipStyle = "appearance/flipStyle";
constexpr auto kDigitScale = "appearance/digitScale";
constexpr auto kLastTimerSeconds = "timer/lastSeconds";

} // namespace

/*!
 * Assigns \a value to \a member, writes it to \a key and emits \a signal.
 * Returns early when nothing changed so bindings do not churn.
 */
#define FC_STORE(member, key, signal, value) \
    do { \
        if ((member) == (value)) \
            return; \
        (member) = (value); \
        m_settings.setValue(QString::fromLatin1(key), QVariant::fromValue(member)); \
        Q_EMIT signal(); \
    } while (false)

AppSettings::AppSettings(QObject *parent)
    : QObject(parent)
{
    m_use24Hour = m_settings.value(QString::fromLatin1(kUse24Hour), localePrefers24Hour()).toBool();
    m_showSeconds = m_settings.value(QString::fromLatin1(kShowSeconds), true).toBool();
    m_showDate = m_settings.value(QString::fromLatin1(kShowDate), true).toBool();
    m_keepScreenOn = m_settings.value(QString::fromLatin1(kKeepScreenOn), false).toBool();
    m_themeId = m_settings.value(QString::fromLatin1(kThemeId), QStringLiteral("midnight")).toString();
    m_fontFamily = m_settings.value(QString::fromLatin1(kFontFamily), QString()).toString();
    m_flipStyle = static_cast<FlipStyle>(
        m_settings.value(QString::fromLatin1(kFlipStyle), static_cast<int>(SplitFlap)).toInt());
    m_digitScale = m_settings.value(QString::fromLatin1(kDigitScale), 1.0).toDouble();
    m_lastTimerSeconds = m_settings.value(QString::fromLatin1(kLastTimerSeconds), 300).toInt();

    // Guard against a settings file hand-edited (or written by a future
    // version) into a range the UI cannot represent.
    if (m_flipStyle < SplitFlap || m_flipStyle > Instant)
        m_flipStyle = SplitFlap;
    m_digitScale = qBound(0.4, m_digitScale, 1.0);
    if (m_lastTimerSeconds <= 0)
        m_lastTimerSeconds = 300;
}

bool AppSettings::localePrefers24Hour()
{
    const QString format = QLocale::system().timeFormat(QLocale::ShortFormat);
    return !format.contains(QLatin1String("AP"), Qt::CaseInsensitive);
}

void AppSettings::setUse24Hour(bool value)
{
    FC_STORE(m_use24Hour, kUse24Hour, use24HourChanged, value);
}

void AppSettings::setShowSeconds(bool value)
{
    FC_STORE(m_showSeconds, kShowSeconds, showSecondsChanged, value);
}

void AppSettings::setShowDate(bool value)
{
    FC_STORE(m_showDate, kShowDate, showDateChanged, value);
}

void AppSettings::setKeepScreenOn(bool value)
{
    FC_STORE(m_keepScreenOn, kKeepScreenOn, keepScreenOnChanged, value);
}

void AppSettings::setThemeId(const QString &value)
{
    FC_STORE(m_themeId, kThemeId, themeIdChanged, value);
}

void AppSettings::setFontFamily(const QString &value)
{
    FC_STORE(m_fontFamily, kFontFamily, fontFamilyChanged, value);
}

void AppSettings::setFlipStyle(FlipStyle value)
{
    // Stored as a plain int rather than the enum: QSettings backends (notably
    // the Windows registry) cannot round-trip a custom enum QVariant.
    if (m_flipStyle == value)
        return;
    m_flipStyle = value;
    m_settings.setValue(QString::fromLatin1(kFlipStyle), static_cast<int>(m_flipStyle));
    Q_EMIT flipStyleChanged();
}

void AppSettings::setDigitScale(qreal value)
{
    FC_STORE(m_digitScale, kDigitScale, digitScaleChanged, qBound(0.4, value, 1.0));
}

void AppSettings::setLastTimerSeconds(int value)
{
    FC_STORE(m_lastTimerSeconds, kLastTimerSeconds, lastTimerSecondsChanged, qMax(1, value));
}

QStringList AppSettings::availableFontFamilies() const
{
    // Private families are foundry-internal faces that the user never asked
    // for and that often fail to render digits at all.
    QStringList families;
    const QStringList all = QFontDatabase::families();
    families.reserve(all.size());
    for (const QString &family : all) {
        if (QFontDatabase::isPrivateFamily(family))
            continue;
        families.append(family);
    }
    families.prepend(QString()); // "System default"
    return families;
}
