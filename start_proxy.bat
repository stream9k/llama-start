@echo off
cd /d "%~dp0"

echo =============================================
echo  Llama VRAM Manager Starting...
echo =============================================
echo.

REM 기존 프록시 강제 종료 (8033 포트)
echo Terminating existing processes on port 8033...
powershell -ExecutionPolicy Bypass -NoProfile -Command "Get-NetTCPConnection -LocalPort 8033 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique | ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }"

REM Llama 서버도 종료 (8034 포트)
powershell -ExecutionPolicy Bypass -NoProfile -Command "Get-NetTCPConnection -LocalPort 8034 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique | ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }"

REM 포트 해제 대기 (최대 5초)
echo Waiting for ports to be released...
timeout /t 2 /nobreak >nul

REM 프록시 서버 시작 (Foreground)
echo Starting proxy server...
echo Press Ctrl+C to stop the server.
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0proxy_server.ps1"

echo.
echo Proxy server stopped.
pause
