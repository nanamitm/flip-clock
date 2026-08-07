#pragma once

#include <QObject>
#include <QtQmlIntegration>

/*!
 * Keeps the display from sleeping while the clock is on screen.
 *
 * Windows uses SetThreadExecutionState; Android sets FLAG_KEEP_SCREEN_ON on
 * the activity window. On any other platform this is a no-op, so QML can bind
 * to it unconditionally.
 */
class ScreenAwake : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged FINAL)
    //! False on platforms where the request cannot be made at all, so the
    //! settings UI can grey out the toggle instead of lying about it.
    Q_PROPERTY(bool supported READ isSupported CONSTANT FINAL)

public:
    explicit ScreenAwake(QObject *parent = nullptr);
    ~ScreenAwake() override;

    bool isEnabled() const { return m_enabled; }
    void setEnabled(bool value);

    static bool isSupported();

Q_SIGNALS:
    void enabledChanged();

private:
    static void apply(bool keepAwake);

    bool m_enabled = false;
};
