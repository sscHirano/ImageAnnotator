@echo off
cd /d "%~dp0"
echo =========================================
echo Cleaning intermediate files...
echo =========================================

call :CleanDir build
call :CleanDir build_release

echo =========================================
echo Clean complete. Executables are preserved.
echo =========================================
pause
goto :eof

:CleanDir
if not exist "%~1" exit /b
echo Cleaning %~1...
cd "%~1"
for %%F in (*.*) do (
    if /I not "%%~xF"==".exe" del /q "%%F"
)
for /d %%D in (*) do (
    rmdir /s /q "%%D"
)
cd ..
exit /b
