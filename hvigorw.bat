@echo off
rem ----------------------------------------------------------------------------
rem Hvigor startup script for Windows
rem ----------------------------------------------------------------------------

setlocal

rem Determine hvigor home
set HVIGOR_APP_HOME=%~dp0
if "%HVIGOR_APP_HOME:~-1%"=="\" set HVIGOR_APP_HOME=%HVIGOR_APP_HOME:~0,-1%

rem Get node from environment
if "%NODE_PATH%"=="" (
    set NODE_PATH=node
)

rem Execute hvigor
"%NODE_PATH%" "%HVIGOR_APP_HOME%\hvigor\hvigor-wrapper.js" %*

endlocal
