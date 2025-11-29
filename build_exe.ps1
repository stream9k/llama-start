# PS2EXE 모듈 설치 (없으면)
if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Write-Host "Installing PS2EXE module..." -ForegroundColor Cyan
    Install-Module -Name ps2exe -Scope CurrentUser -Force -SkipPublisherCheck
}

# EXE 변환
Write-Host "Converting proxy_server.ps1 to LlamaManager.exe..." -ForegroundColor Cyan
Invoke-PS2EXE -InputFile "$PSScriptRoot\proxy_server.ps1" `
    -OutputFile "$PSScriptRoot\LlamaManager.exe" `
    -Title "Llama VRAM Manager" `
    -Version "1.0.0.0" `
    -Description "Llama.cpp VRAM Manager & Proxy" `
    -Copyright "User"

Write-Host "Done! LlamaManager.exe created." -ForegroundColor Green
Write-Host "You can now run LlamaManager.exe directly." -ForegroundColor Green
