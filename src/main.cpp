#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQuickStyle>

int main(int argc, char *argv[])
{
    // Set before any QSettings is constructed: these determine where the
    // settings file (and therefore every persisted preference) ends up.
    QCoreApplication::setOrganizationName(QStringLiteral("FlipClock"));
    QCoreApplication::setOrganizationDomain(QStringLiteral("flipclock.example.com"));
    QCoreApplication::setApplicationName(QStringLiteral("FlipClock"));
    QCoreApplication::setApplicationVersion(QStringLiteral(APP_VERSION));

    QGuiApplication app(argc, argv);
    app.setWindowIcon(QIcon(QStringLiteral(":/qt/qml/FlipClock/assets/icons/appicon.svg")));

    // Pin the Controls style so Windows and Android render identically; the
    // platform default styles disagree on padding, colours and font metrics.
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("FlipClock", "Main");

    return app.exec();
}
