@echo off
echo =========================================
echo Setting up Qt Environment...
echo =========================================

set QT_DIR=C:\Qt\6.11.1\mingw_64
set CMAKE_DIR=C:\Qt\Tools\CMake_64\bin
set NINJA_DIR=C:\Qt\Tools\Ninja
set MINGW_DIR=C:\Qt\Tools\mingw1310_64\bin

set PATH=%CMAKE_DIR%;%NINJA_DIR%;%MINGW_DIR%;%QT_DIR%\bin;%PATH%
set CMAKE_PREFIX_PATH=%QT_DIR%

echo =========================================
echo Configuring Project (CMake)...
echo =========================================
cmake -S . -B build -G Ninja

echo.
echo =========================================
echo Building Project...
echo =========================================
cmake --build build
if %ERRORLEVEL% neq 0 (
    echo.
    echo =========================================
    echo Build FAILED! Stopping.
    echo =========================================
    exit /b %ERRORLEVEL%
)

echo =========================================
echo Build completed.
echo =========================================
