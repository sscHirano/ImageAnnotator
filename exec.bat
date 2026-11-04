@echo off
echo =========================================
echo Setting up Qt Environment for Execution
echo =========================================

REM Set the paths for Qt and MinGW DLLs
set QT_DIR=C:\Qt\6.11.1\mingw_64
set MINGW_DIR=C:\Qt\Tools\mingw1310_64\bin

set PATH=%MINGW_DIR%;%QT_DIR%\bin;%PATH%

echo =========================================
echo Running App...
echo =========================================

if exist .\build\appImageAnnotator.exe (
    .\build\appImageAnnotator.exe
) else (
    echo Error: appImageAnnotator.exe not found! Please run build_windows.bat first.
    exit /b 1
)
