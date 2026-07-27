@echo off
set QT_DIR=C:\Qt\6.11.1\mingw_64
set CMAKE_DIR=C:\Qt\Tools\CMake_64\bin
set NINJA_DIR=C:\Qt\Tools\Ninja
set MINGW_DIR=C:\Qt\Tools\mingw1310_64\bin

set PATH=%CMAKE_DIR%;%NINJA_DIR%;%MINGW_DIR%;%QT_DIR%\bin;%PATH%
set CMAKE_PREFIX_PATH=%QT_DIR%

echo =========================================
echo Cleaning previous builds...
echo =========================================
if exist "build_release" rmdir /s /q build_release
if exist "ImageAnnotator_Release" rmdir /s /q ImageAnnotator_Release

echo =========================================
echo Building Release version...
echo =========================================
cmake -S . -B build_release -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build_release
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Build failed!
    pause
    exit /b %ERRORLEVEL%
)

echo =========================================
echo Creating Distribution Folder...
echo =========================================
mkdir ImageAnnotator_Release
copy build_release\appImageAnnotator.exe ImageAnnotator_Release\

echo =========================================
echo Gathering Qt Dependencies (windeployqt)...
echo =========================================
windeployqt --qmldir . --release ImageAnnotator_Release\appImageAnnotator.exe

echo =========================================
echo Done!
echo =========================================
echo [SUCCESS]
echo The "ImageAnnotator_Release" folder has been created.
echo You can zip this entire folder and share it with other Windows users!
pause
