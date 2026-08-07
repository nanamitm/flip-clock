#pragma once

#include <QColor>
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QtQmlIntegration>

/*!
 * The colour palette currently in effect, plus the catalogue of palettes the
 * user can choose from.
 *
 * QML binds \c themeId to AppSettings::themeId; this class deliberately does
 * not read the settings itself, so the flow stays one-directional
 * (settings -> theme -> UI) and the palettes stay unit-testable in isolation.
 */
class ThemeManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString themeId READ themeId WRITE setThemeId NOTIFY themeChanged FINAL)
    Q_PROPERTY(QString themeName READ themeName NOTIFY themeChanged FINAL)
    Q_PROPERTY(bool isDark READ isDark NOTIFY themeChanged FINAL)

    Q_PROPERTY(QColor background READ background NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor surface READ surface NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor surfaceAlt READ surfaceAlt NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor cardTop READ cardTop NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor cardBottom READ cardBottom NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor digit READ digit NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor divider READ divider NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor accent READ accent NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor textPrimary READ textPrimary NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor textSecondary READ textSecondary NOTIFY themeChanged FINAL)

    //! One entry per palette: { id, name, background, cardTop, digit, accent }.
    Q_PROPERTY(QVariantList themes READ themes CONSTANT FINAL)

public:
    struct Palette
    {
        QString id;
        QString name;
        bool dark = true;
        QColor background;
        QColor surface;
        QColor surfaceAlt;
        QColor cardTop;
        QColor cardBottom;
        QColor digit;
        QColor divider;
        QColor accent;
        QColor textPrimary;
        QColor textSecondary;
    };

    explicit ThemeManager(QObject *parent = nullptr);

    QString themeId() const { return m_palette.id; }
    void setThemeId(const QString &id);

    QString themeName() const { return m_palette.name; }
    bool isDark() const { return m_palette.dark; }

    QColor background() const { return m_palette.background; }
    QColor surface() const { return m_palette.surface; }
    QColor surfaceAlt() const { return m_palette.surfaceAlt; }
    QColor cardTop() const { return m_palette.cardTop; }
    QColor cardBottom() const { return m_palette.cardBottom; }
    QColor digit() const { return m_palette.digit; }
    QColor divider() const { return m_palette.divider; }
    QColor accent() const { return m_palette.accent; }
    QColor textPrimary() const { return m_palette.textPrimary; }
    QColor textSecondary() const { return m_palette.textSecondary; }

    QVariantList themes() const;

Q_SIGNALS:
    void themeChanged();

private:
    static const QList<Palette> &catalogue();

    Palette m_palette;
};
