#pragma once

#include <QObject>
#include <QtQmlIntegration>

class QMenu;
class QSystemTrayIcon;

/*!
 * Windows shell integration for the compact clock.  The notification-area
 * menu is deliberately also the escape hatch for click-through mode, where
 * the clock window itself cannot receive a mouse click.
 */
class DesktopController : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit DesktopController(QObject *parent = nullptr);
    ~DesktopController() override;

Q_SIGNALS:
    void showCompactRequested();
    void openFullAppRequested();
    void disableClickThroughRequested();
    void quitRequested();

private:
    QSystemTrayIcon *m_tray = nullptr;
    QMenu *m_menu = nullptr;
};
