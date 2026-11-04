@echo off
setlocal

if not defined QT_DIR set "QT_DIR=C:\Qt\6.11.2\mingw_64"
if exist "%QT_DIR%\bin" set "PATH=%QT_DIR%\bin;%PATH%"

where cppcheck >nul 2>nul
if errorlevel 1 (
    where winget >nul 2>nul
    if errorlevel 1 (
        echo ERROR: cppcheck was not found and winget is unavailable.
        echo Install Cppcheck manually or install winget, then rerun this script.
        exit /b 1
    )

    echo Cppcheck was not found. Installing it with winget...
    winget install --id Cppcheck.Cppcheck -e --accept-package-agreements --accept-source-agreements
    if errorlevel 1 (
        echo ERROR: Failed to install Cppcheck with winget.
        exit /b 1
    )

    if exist "%ProgramFiles%\Cppcheck\cppcheck.exe" (
        set "PATH=%ProgramFiles%\Cppcheck;%PATH%"
    )
    if exist "%ProgramFiles(x86)%\Cppcheck\cppcheck.exe" (
        set "PATH=%ProgramFiles(x86)%\Cppcheck;%PATH%"
    )

    where cppcheck >nul 2>nul
    if errorlevel 1 (
        echo ERROR: Cppcheck was installed, but cppcheck.exe was not found on PATH.
        echo Restart the terminal and rerun this script.
        exit /b 1
    )
)

where qmllint >nul 2>nul
if errorlevel 1 (
    echo ERROR: qmllint was not found. Set QT_DIR to your Qt installation or add qmllint to PATH.
    exit /b 1
)

pushd "%~dp0"
if errorlevel 1 (
    echo ERROR: Could not switch to the project directory.
    exit /b 1
)

set "LOG_FILE=%~dp0static_analysis.log"
set "FAILED=0"

echo =========================================
echo Running Cppcheck...
echo =========================================
> "%LOG_FILE%" echo Static analysis log - %DATE% %TIME%
>> "%LOG_FILE%" echo.
>> "%LOG_FILE%" echo ===== Cppcheck =====
cppcheck --enable=warning,style,performance,portability ^
         --library=qt ^
         --language=c++ ^
         --std=c++17 ^
         --inline-suppr ^
         --suppress=missingIncludeSystem ^
         --suppress=missingInclude ^
         --suppress=unusedFunction ^
         --suppress=unmatchedSuppression ^
         --error-exitcode=1 ^
         main.cpp clipboardhelper.cpp tests/tst_clipboardhelper.cpp >> "%LOG_FILE%" 2>&1
if errorlevel 1 set "FAILED=1"

echo.
echo =========================================
echo Running qmllint...
echo =========================================
>> "%LOG_FILE%" echo.
>> "%LOG_FILE%" echo ===== qmllint =====
qmllint --bare -I "%QT_DIR%\qml" Main.qml tests/tst_main.qml >> "%LOG_FILE%" 2>&1
if errorlevel 1 set "FAILED=1"

if "%FAILED%"=="1" (
    echo.
    echo Static analysis FAILED. See "%LOG_FILE%" for details.
    popd
    exit /b 1
)

echo.
echo Static analysis completed successfully. See "%LOG_FILE%" for details.
popd
exit /b 0
