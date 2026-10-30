#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QIcon>
#include <QVariant>
#include "clipboardhelper.h"

int main(int argc, char *argv[])
{
    using namespace Qt::StringLiterals;

    qputenv("QT_QUICK_CONTROLS_STYLE", "Fusion");
    QGuiApplication app(argc, argv);
    app.setWindowIcon(QIcon(":/qt/qml/ImageAnnotator/app_icon.ico"));

    ClipboardHelper clipboardHelper;

    QQmlApplicationEngine engine;

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("ImageAnnotator", "Main");
    if (engine.rootObjects().isEmpty()) {
        return -1;
    }
    engine.rootObjects().constFirst()->setProperty(
        "clipboardHelper", QVariant::fromValue(&clipboardHelper));

    return app.exec();
}
