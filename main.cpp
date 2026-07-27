#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "clipboardhelper.h"

int main(int argc, char *argv[])
{
    using namespace Qt::StringLiterals;

    QGuiApplication app(argc, argv);

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
