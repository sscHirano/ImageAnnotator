#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QIcon>
#include "clipboardhelper.h"

int main(int argc, char *argv[])
{
    using namespace Qt::StringLiterals;

    qputenv("QT_QUICK_CONTROLS_STYLE", "Fusion");
    QGuiApplication app(argc, argv);
    app.setWindowIcon(QIcon(":/qt/qml/ImageAnnotator/app_icon.ico"));

    ClipboardHelper clipboardHelper;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("ClipboardHelper", &clipboardHelper);

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("ImageAnnotator", "Main");

    return app.exec();
}
