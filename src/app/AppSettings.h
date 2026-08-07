#pragma once

#include <QColor>
#include <QObject>
#include <QSettings>
#include <QStringList>
#include <QtQmlIntegration>

/*!
 * Every user preference in the app, persisted through QSettings.
 *
 * Exposed to QML as a singleton so any page can read and write a preference
 * without threading it through properties. Each setter writes through to
 * QSettings immediately -- there is no explicit save step, and a crash never
 * loses more than the change in flight.
 */
class AppSettings : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool use24Hour READ use24Hour WRITE setUse24Hour NOTIFY use24HourChanged FINAL)
    Q_PROPERTY(bool showSeconds READ showSeconds WRITE setShowSeconds NOTIFY showSecondsChanged FINAL)
    Q_PROPERTY(bool showDate READ showDate WRITE setShowDate NOTIFY showDateChanged FINAL)
    Q_PROPERTY(bool keepScreenOn READ keepScreenOn WRITE setKeepScreenOn NOTIFY keepScreenOnChanged FINAL)
    Q_PROPERTY(QString themeId READ themeId WRITE setThemeId NOTIFY themeIdChanged FINAL)
    Q_PROPERTY(QString fontFamily READ fontFamily WRITE setFontFamily NOTIFY fontFamilyChanged FINAL)
    Q_PROPERTY(FlipStyle flipStyle READ flipStyle WRITE setFlipStyle NOTIFY flipStyleChanged FINAL)
    Q_PROPERTY(qreal digitScale READ digitScale WRITE setDigitScale NOTIFY digitScaleChanged FINAL)
    Q_PROPERTY(int lastTimerSeconds READ lastTimerSeconds WRITE setLastTimerSeconds NOTIFY lastTimerSecondsChanged FINAL)
    Q_PROPERTY(QStringList availableFontFamilies READ availableFontFamilies CONSTANT FINAL)

public:
    enum FlipStyle {
        SplitFlap = 0, //!< Classic mechanical split-flap animation.
        Fade = 1,      //!< Cross-fade between digits.
        Instant = 2,   //!< No animation at all.
    };
    Q_ENUM(FlipStyle)

    explicit AppSettings(QObject *parent = nullptr);

    bool use24Hour() const { return m_use24Hour; }
    void setUse24Hour(bool value);

    bool showSeconds() const { return m_showSeconds; }
    void setShowSeconds(bool value);

    bool showDate() const { return m_showDate; }
    void setShowDate(bool value);

    bool keepScreenOn() const { return m_keepScreenOn; }
    void setKeepScreenOn(bool value);

    QString themeId() const { return m_themeId; }
    void setThemeId(const QString &value);

    QString fontFamily() const { return m_fontFamily; }
    void setFontFamily(const QString &value);

    FlipStyle flipStyle() const { return m_flipStyle; }
    void setFlipStyle(FlipStyle value);

    qreal digitScale() const { return m_digitScale; }
    void setDigitScale(qreal value);

    int lastTimerSeconds() const { return m_lastTimerSeconds; }
    void setLastTimerSeconds(int value);

    QStringList availableFontFamilies() const;

Q_SIGNALS:
    void use24HourChanged();
    void showSecondsChanged();
    void showDateChanged();
    void keepScreenOnChanged();
    void themeIdChanged();
    void fontFamilyChanged();
    void flipStyleChanged();
    void digitScaleChanged();
    void lastTimerSecondsChanged();

private:
    //! True when the system locale formats times with an AM/PM marker.
    static bool localePrefers24Hour();

    QSettings m_settings;

    bool m_use24Hour;
    bool m_showSeconds;
    bool m_showDate;
    bool m_keepScreenOn;
    QString m_themeId;
    QString m_fontFamily;
    FlipStyle m_flipStyle;
    qreal m_digitScale;
    int m_lastTimerSeconds;
};
