@echo off
REM Build application <&>
set "NAME=viewer"
if not "%NAME%"=="" call :build "%NAME%"
goto :eof

:build
echo Building %1 ^& copying
exit /b 0
