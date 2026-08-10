#include "app/DesktopController.h"

#ifdef Q_OS_WIN
#  include <QAction>
#  include <QIcon>
#  include <QMenu>
#  include <QSystemTrayIcon>
#endif

DesktopController::DesktopController(QObject *parent)
    : QObject(parent)
{
#ifdef Q_OS_WIN
    m_menu = new QMenu;
    auto *showCompact = m_menu->addAction(tr("Show compact clock"));
    auto *openFullApp = m_menu->addAction(tr("Open full app"));
    auto *disableClickThrough = m_menu->addAction(tr("Turn off click-through"));
    m_menu->addSeparator();
    auto *quit = m_menu->addAction(tr("Quit Flip Clock"));

    connect(showCompact, &QAction::triggered, this, &DesktopController::showCompactRequested);
    connect(openFullApp, &QAction::triggered, this, &DesktopController::openFullAppRequested);
    connect(disableClickThrough, &QAction::triggered,
            this, &DesktopController::disableClickThroughRequested);
    connect(quit, &QAction::triggered, this, &DesktopController::quitRequested);

    m_tray = new QSystemTrayIcon(
        QIcon(QStringLiteral(":/qt/qml/FlipClock/assets/icons/appicon.png")), this);
    m_tray->setToolTip(tr("Flip Clock"));
    m_tray->setContextMenu(m_menu);
    m_tray->show();
#endif
}

DesktopController::~DesktopController()
{
#ifdef Q_OS_WIN
    // QSystemTrayIcon does not own its context menu.  Hiding first avoids a
    // stale icon surviving in Explorer briefly while the app is closing.
    if (m_tray)
        m_tray->hide();
    delete m_menu;
#endif
}
