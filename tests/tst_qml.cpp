#include <QtQuickTest/quicktest.h>
#include <QQmlEngine>
#include <QDir>

#ifndef QUICK_TEST_SOURCE_DIR
#define QUICK_TEST_SOURCE_DIR "."
#endif

class Setup : public QObject
{
    Q_OBJECT
public:
    Setup() {}

public slots:
    void qmlEngineAvailable(QQmlEngine *engine)
    {
        // プロジェクトルートをインポートパスに追加
        engine->addImportPath(QDir(QUICK_TEST_SOURCE_DIR).filePath(".."));
    }
};

QUICK_TEST_MAIN_WITH_SETUP(qml_tests, Setup)

#include "tst_qml.moc"
