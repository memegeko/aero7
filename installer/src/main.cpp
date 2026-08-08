#include "installercontroller.h"

#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QCursor>
#include <QFont>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QPixmap>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QQuickStyle>
#include <QRegularExpression>
#include <QTimer>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QFontDatabase::addApplicationFont(QStringLiteral(":/assets/fonts/AdwaitaSans-Regular.ttf"));
    app.setFont(QFont(QStringLiteral("Adwaita Sans"), 10));
    const QPixmap cursorPixmap(QStringLiteral(":/assets/cursors/aero-pointer.svg"));
    if (!cursorPixmap.isNull())
        QGuiApplication::setOverrideCursor(QCursor(cursorPixmap, 2, 2));
    QCoreApplication::setApplicationName(QStringLiteral("Aero7 Setup"));
    QCoreApplication::setApplicationVersion(QStringLiteral("0.1.0"));
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Aero7 graphical installer and first-boot setup"));
    parser.addHelpOption();
    parser.addVersionOption();
    parser.addOption({QStringLiteral("oobe"), QStringLiteral("Run the installed-system first-boot flow")});
    parser.addOption({QStringLiteral("live-install"), QStringLiteral("Enable the guarded real backend")});
    parser.addOption({QStringLiteral("demo"), QStringLiteral("Force simulation mode (default)")});
    parser.addOption({QStringLiteral("backend"), QStringLiteral("Backend executable path"),
                      QStringLiteral("path"), QStringLiteral("/usr/lib/aero7/aero7-install-backend")});
    parser.addOption({QStringLiteral("screen"), QStringLiteral("Open a named screen in demo mode"),
                      QStringLiteral("id")});
    parser.addOption({QStringLiteral("advanced-drive"),
                      QStringLiteral("Open the advanced drive options in demo mode")});
    parser.addOption({QStringLiteral("screenshot"), QStringLiteral("Capture the rendered window and exit"),
                      QStringLiteral("path")});
    parser.addOption({QStringLiteral("documentation-screenshot"),
                      QStringLiteral("Render safe demo data with release-facing labels")});
    parser.addOption({QStringLiteral("size"), QStringLiteral("Capture size as WIDTHxHEIGHT"),
                      QStringLiteral("size"), QStringLiteral("1024x768")});
    parser.process(app);

    const bool oobeMode = parser.isSet(QStringLiteral("oobe"));
    const bool demoMode = parser.isSet(QStringLiteral("demo")) || !parser.isSet(QStringLiteral("live-install"));
    InstallerController controller(oobeMode, demoMode, parser.value(QStringLiteral("backend")));
    if (parser.isSet(QStringLiteral("screen"))
        && !controller.jumpToForTest(parser.value(QStringLiteral("screen")))) {
        qCritical("Unknown or disallowed demo screen");
        return 2;
    }
    if (parser.isSet(QStringLiteral("advanced-drive")))
        controller.setAdvancedDriveOptions(true);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("controller"), &controller);
    int captureWidth = 1024;
    int captureHeight = 768;
    const QRegularExpression sizeExpression(QStringLiteral("^(\\d{3,4})x(\\d{3,4})$"));
    const QRegularExpressionMatch sizeMatch = sizeExpression.match(parser.value(QStringLiteral("size")));
    if (!sizeMatch.hasMatch()) {
        qCritical("Invalid --size value");
        return 2;
    }
    captureWidth = sizeMatch.captured(1).toInt();
    captureHeight = sizeMatch.captured(2).toInt();
    const bool captureMode = parser.isSet(QStringLiteral("screenshot"));
    const bool documentationMode = parser.isSet(QStringLiteral("documentation-screenshot"));
    engine.rootContext()->setContextProperty(QStringLiteral("captureMode"), captureMode);
    engine.rootContext()->setContextProperty(QStringLiteral("documentationMode"), documentationMode);
    engine.rootContext()->setContextProperty(QStringLiteral("captureWidth"), captureWidth);
    engine.rootContext()->setContextProperty(QStringLiteral("captureHeight"), captureHeight);
    engine.load(QUrl(QStringLiteral("qrc:/qml/Main.qml")));
    if (engine.rootObjects().isEmpty())
        return 1;
    if (parser.isSet(QStringLiteral("screenshot"))) {
        const QString output = parser.value(QStringLiteral("screenshot"));
        QTimer::singleShot(700, &app, [&app, &engine, output] {
            auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());
            if (!window || !window->grabWindow().save(output))
                app.exit(3);
            else
                app.quit();
        });
    }
    return app.exec();
}
