@echo off
setlocal
echo =========================================
echo Setting up Qt Environment...
echo =========================================

set QT_DIR=C:\Qt\6.11.2\mingw_64
set CMAKE_DIR=C:\Qt\Tools\CMake_64\bin
set NINJA_DIR=C:\Qt\Tools\Ninja
set MINGW_DIR=C:\Qt\Tools\mingw1310_64\bin

set PATH=%CMAKE_DIR%;%NINJA_DIR%;%MINGW_DIR%;%QT_DIR%\bin;%PATH%
set CMAKE_PREFIX_PATH=%QT_DIR%

echo.
echo =========================================
echo Configuring Project (CMake)...
echo =========================================
cmake -S . -B build -G Ninja
if %ERRORLEVEL% neq 0 (
    echo CMake configure failed!
    exit /b %ERRORLEVEL%
)

echo.
echo =========================================
echo Building Tests...
echo =========================================
cmake --build build --target tst_clipboardhelper tst_qml
if %ERRORLEVEL% neq 0 (
    echo Test build failed!
    exit /b %ERRORLEVEL%
)

echo.
echo =========================================
echo Running Tests (ctest)...
echo =========================================
cd build
ctest --output-on-failure
set TEST_STATUS=%ERRORLEVEL%
cd ..

if %TEST_STATUS% neq 0 (
    echo.
    echo Tests FAILED!
    exit /b %TEST_STATUS%
)

echo.
echo All tests passed successfully!
endlocal
