cmake_minimum_required(VERSION 3.16)
project(ImageAnnotator VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick Svg)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(appImageAnnotator
    main.cpp
    clipboardhelper.cpp
    clipboardhelper.h
    app.rc
)

qt_add_qml_module(appImageAnnotator
    URI ImageAnnotator
    VERSION 1.0
    QML_FILES Main.qml
    RESOURCES
        app_icon.ico
        icons/paste.svg
        icons/copy.svg
        icons/save.svg
        icons/undo.svg
        icons/redo.svg
        icons/delete.svg
        icons/clear.svg
)

set_target_properties(appImageAnnotator PROPERTIES
    MACOSX_BUNDLE ON
)

if(CMAKE_BUILD_TYPE STREQUAL "Release")
    set_target_properties(appImageAnnotator PROPERTIES WIN32_EXECUTABLE ON)
else()
    set_target_properties(appImageAnnotator PROPERTIES WIN32_EXECUTABLE OFF)
endif()

target_link_libraries(appImageAnnotator
    PRIVATE Qt6::Quick Qt6::Svg
)

enable_testing()
add_subdirectory(tests)
