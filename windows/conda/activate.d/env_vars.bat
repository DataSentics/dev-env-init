@echo off
FOR /F %%i IN ("%~dp0\..\..\..\..") DO set PROJECT_ROOT=%%~fi

set PYTHONDONTWRITEBYTECODE=1
set PYTHONPATH=%PROJECT_ROOT%\src

cd %PROJECT_ROOT%
