@echo off
echo =============================================
echo  Force Killing Llama Proxy & Server...
echo =============================================
echo.

echo [1/2] Killing Proxy (Port 8033)...
powershell -ExecutionPolicy Bypass -NoProfile -Command "Get-NetTCPConnection -LocalPort 8033 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique | ForEach-Object { Write-Host 'Killing PID:' $_; Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }"

echo [2/2] Killing Llama Server (Port 8034)...
powershell -ExecutionPolicy Bypass -NoProfile -Command "Get-NetTCPConnection -LocalPort 8034 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique | ForEach-Object { Write-Host 'Killing PID:' $_; Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }"

echo.
echo Done.
pause
