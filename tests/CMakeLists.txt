find_package(Qt6 REQUIRED COMPONENTS Test Gui Quick QuickTest)

# C++ 単体テスト
qt_add_executable(tst_clipboardhelper
    tst_clipboardhelper.cpp
    ../clipboardhelper.cpp
    ../clipboardhelper.h
)

target_include_directories(tst_clipboardhelper PRIVATE ..)

target_link_libraries(tst_clipboardhelper PRIVATE
    Qt6::Test
    Qt6::Gui
)

add_test(NAME tst_clipboardhelper COMMAND tst_clipboardhelper)

# QML 単体テスト
qt_add_executable(tst_qml
    tst_qml.cpp
)

target_compile_definitions(tst_qml PRIVATE
    QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}"
)

target_link_libraries(tst_qml PRIVATE
    Qt6::QuickTest
    Qt6::Quick
)

add_test(NAME tst_qml COMMAND tst_qml)
