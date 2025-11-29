try {
    # =============================================
    # LLAMA PROXY SERVER (SINGLE FILE)
    # =============================================

    # .NET 네임스페이스 로드
    Add-Type -AssemblyName System.Net.Http

    # 현재 스크립트/EXE 위치 감지 (PS2EXE 호환)
    if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
        $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }
    else {
        # EXE로 실행될 때
        $ScriptPath = Split-Path -Parent ([Environment]::GetCommandLineArgs()[0])
    }

    # 만약 위 방법으로 실패하면 현재 디렉토리 사용
    if (-not $ScriptPath) {
        $ScriptPath = Get-Location
    }

    Write-Host "Detected Execution Path: $ScriptPath" -ForegroundColor DarkGray

    # =============================================
    # [CONFIGURATION]
    # =============================================
    $Config = @{
        # Llama Server Binary Path
        # (상대 경로) 현재 폴더의 llama-server.exe
        LlamaBinary        = "$ScriptPath\llama-server.exe"

        # Model Directory
        # (상대 경로) 현재 폴더
        ModelDir           = "$ScriptPath"
        
        # ModelPath는 실행 시 선택된 파일로 동적으로 설정됩니다.
        ModelPath          = ""

        # Server Settings
        ServerHost         = "127.0.0.1"
        ServerPort         = 8034  # 실제 llama-server가 내부적으로 사용할 포트 (외부 노출 X)
        ProxyPort          = 8033  # 클라이언트가 접속할 공개 포트 (Proxy가 점유)

        # Performance Settings
        CtxSize            = 8192  # 기본값 (실행 시 선택 가능)
        Threads            = 6

        # Logging
        LogFile            = "$ScriptPath\llama_log.txt"

        # Auto-Shutdown Settings
        IdleTimeout        = 3600  # 초 단위 (이 시간 동안 요청이 없으면 서버 종료)

        # Ignored URL Patterns (Polling requests that shouldn't wake/keep server alive)
        IgnoredUrlPatterns = @(
            "^GET /health",
            "^GET /v1/models",
            "^GET /props",
            "^GET /$"  # Root path check
        )
    }

    # [External Config Override]
    # 같은 폴더에 config.ps1이 있으면 로드하여 설정을 덮어씁니다.
    $ExternalConfigPath = "$ScriptPath\config.ps1"
    if (Test-Path $ExternalConfigPath) {
        Write-Host "Loading external configuration from: $ExternalConfigPath" -ForegroundColor Gray
        # 임시 변수에 로드
        . $ExternalConfigPath
        # 로드된 $Config가 있으면 병합 (여기서는 간단히 덮어쓰기)
        # 주의: config.ps1이 $Config를 새로 정의하므로 그대로 사용됨
    }
    
    # =============================================
    # [SERVER MANAGER LOGIC]
    # =============================================
    
    # 전역 변수로 프로세스 핸들 관리
    $global:LlamaProcess = $null
    
    function Get-LlamaServerStatus {
        # 1. 프로세스 객체 확인
        if ($global:LlamaProcess -and -not $global:LlamaProcess.HasExited) {
            return $true
        }
        if ($global:LlamaProcess -and $global:LlamaProcess.HasExited) {
            Write-Host "[Manager] Process $($global:LlamaProcess.Id) has exited (Code: $($global:LlamaProcess.ExitCode))." -ForegroundColor DarkGray
            $global:LlamaProcess = $null
        }
        
        # 2. 포트 리스닝 확인 (이중 체크)
        $tcpConnection = Get-NetTCPConnection -LocalPort $Config.ServerPort -ErrorAction SilentlyContinue
        if ($tcpConnection -and $tcpConnection.State -eq 'Listen') {
            return $true
        }

        return $false
    }
    
    function Start-LlamaServer {
        if (Get-LlamaServerStatus) {
            Write-Host "[Manager] Server is already running." -ForegroundColor Yellow
            return $true
        }

        Write-Host "[Manager] Starting llama-server on port $($Config.ServerPort)..." -ForegroundColor Cyan

        try {
            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.FileName = $Config.LlamaBinary
            $processInfo.Arguments = @(
                "-m `"$($Config.ModelPath)`"",
                "--host $($Config.ServerHost)",
                "--port $($Config.ServerPort)",
                "--ctx-size $($Config.CtxSize)",
                "--threads $($Config.Threads)",
                "--log-file `"$($Config.LogFile)`""
            ) -join " "
            
            $processInfo.WorkingDirectory = $ScriptPath
            $processInfo.CreateNoWindow = $true
            $processInfo.UseShellExecute = $false
            
            $global:LlamaProcess = New-Object System.Diagnostics.Process
            $global:LlamaProcess.StartInfo = $processInfo
            
            if ($global:LlamaProcess.Start()) {
                Write-Host "[Manager] Process started (PID: $($global:LlamaProcess.Id))" -ForegroundColor Green
                
                # 서버가 포트를 열 때까지 잠시 대기 (Health Check)
                $maxRetries = 30
                $retryCount = 0
                $serverReady = $false

                while ($retryCount -lt $maxRetries) {
                    Start-Sleep -Milliseconds 500
                    $tcpConnection = Get-NetTCPConnection -LocalPort $Config.ServerPort -ErrorAction SilentlyContinue
                    if ($tcpConnection -and $tcpConnection.State -eq 'Listen') {
                        $serverReady = $true
                        break
                    }
                    $retryCount++
                    Write-Host "." -NoNewline
                }
                Write-Host ""

                if ($serverReady) {
                    Write-Host "[Manager] Server is ready to accept connections." -ForegroundColor Green
                    return $true
                }
                else {
                    Write-Host "[Manager] Timeout waiting for server port $($Config.ServerPort)." -ForegroundColor Red
                    Stop-LlamaServer
                    return $false
                }
            }
            else {
                Write-Host "[ERROR] Failed to start process." -ForegroundColor Red
                return $false
            }
        }
        catch {
            Write-Host "[ERROR] Exception starting server: $_" -ForegroundColor Red
            return $false
        }
    }
    
    function Stop-LlamaServer {
        Write-Host "[Manager] Stopping llama-server..." -ForegroundColor Yellow
        
        # 1. 전역 변수로 추적된 프로세스 종료
        if ($global:LlamaProcess -and -not $global:LlamaProcess.HasExited) {
            try {
                $global:LlamaProcess.Kill()
                $global:LlamaProcess.WaitForExit(3000)
                Write-Host "[Manager] Process killed (PID: $($global:LlamaProcess.Id))" -ForegroundColor Green
            }
            catch {
                Write-Host "[Manager] Failed to kill process: $_" -ForegroundColor Red
            }
        }

        # 2. 혹시 남아있을 수 있는 고아 프로세스 정리 (포트 기준)
        $orphanProcesses = Get-NetTCPConnection -LocalPort $Config.ServerPort -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique
        if ($orphanProcesses) {
            foreach ($processId in $orphanProcesses) {
                try {
                    Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
                    Write-Host "[Manager] Cleaned up orphan process (PID: $processId)" -ForegroundColor Gray
                }
                catch {}
            }
        }

        $global:LlamaProcess = $null
    }
    
    # =============================================
    # [INTERACTIVE SETUP]
    # =============================================
    
    # 1. Model Selection
    Write-Host "Scanning for models in: $($Config.ModelDir)" -ForegroundColor Cyan
    if (-not (Test-Path $Config.ModelDir)) {
        Write-Error "Model directory not found: $($Config.ModelDir)"
        exit 1
    }
    
    $ModelFiles = Get-ChildItem -Path $Config.ModelDir -Filter "*.gguf" | Sort-Object Name
    if ($ModelFiles.Count -eq 0) {
        Write-Error "No .gguf files found in $($Config.ModelDir)"
        exit 1
    }
    
    if ($ModelFiles.Count -eq 1) {
        $SelectedModel = $ModelFiles[0]
        Write-Host "Auto-selected model: $($SelectedModel.Name)" -ForegroundColor Green
    }
    else {
        Write-Host "`nAvailable Models:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $ModelFiles.Count; $i++) {
            Write-Host " [$($i+1)] $($ModelFiles[$i].Name)"
        }
        
        while ($true) {
            $Selection = Read-Host "`nSelect a model (1-$($ModelFiles.Count))"
            if ($Selection -match "^\d+$" -and [int]$Selection -ge 1 -and [int]$Selection -le $ModelFiles.Count) {
                $SelectedModel = $ModelFiles[[int]$Selection - 1]
                break
            }
            Write-Host "Invalid selection. Please try again." -ForegroundColor Red
        }
        Write-Host "Selected model: $($SelectedModel.Name)" -ForegroundColor Green
    }
    $Config.ModelPath = $SelectedModel.FullName
    Write-Host "Model Path set to: $($Config.ModelPath)`n" -ForegroundColor Gray
    
    # 2. Context Size Selection
    Write-Host "Select Context Size (VRAM Usage):" -ForegroundColor Yellow
    Write-Host " [1] 4096  (Low VRAM)"
    Write-Host " [2] 8192  (Medium)"
    Write-Host " [3] 16384 (High)"
    Write-Host " [4] Custom Input"
    
    while ($true) {
        $CtxSelection = Read-Host "`nSelect Context Size (1-4)"
        switch ($CtxSelection) {
            "1" { $Config.CtxSize = 4096; break }
            "2" { $Config.CtxSize = 8192; break }
            "3" { $Config.CtxSize = 16384; break }
            "4" {
                while ($true) {
                    $CustomCtx = Read-Host "Enter Custom Context Size"
                    if ($CustomCtx -match "^\d+$") {
                        $Config.CtxSize = [int]$CustomCtx
                        break
                    }
                    Write-Host "Invalid input. Please enter a number." -ForegroundColor Red
                }
                break
            }
            default { Write-Host "Invalid selection. Please try again." -ForegroundColor Red; continue }
        }
        break
    }
    Write-Host "Context Size set to: $($Config.CtxSize)`n" -ForegroundColor Green
    
    # 3. Idle Timeout Selection
    Write-Host "Select Idle Timeout (Seconds):" -ForegroundColor Yellow
    Write-Host " Examples: 600 (10 mins), 3600 (1 hour), 7200 (2 hours)"
    
    while ($true) {
        $TimeoutInput = Read-Host "`nEnter Idle Timeout in seconds (Default: $($Config.IdleTimeout))"
        if ([string]::IsNullOrWhiteSpace($TimeoutInput)) {
            break
        }
        if ($TimeoutInput -match "^\d+$") {
            $Config.IdleTimeout = [int]$TimeoutInput
            break
        }
        Write-Host "Invalid input. Please enter a number." -ForegroundColor Red
    }
    Write-Host "Idle Timeout set to: $($Config.IdleTimeout) seconds`n" -ForegroundColor Green
    
    # =============================================
    # [PROXY SERVER LOGIC]
    # =============================================
    
    # [Startup Check] 포트 8033 점유 프로세스 강제 종료
    # 이전 실행이 비정상 종료되어 포트를 잡고 있는 경우를 방지합니다.
    Write-Host "Checking for existing processes on port $($Config.ProxyPort)..." -ForegroundColor DarkGray
    $ExistingProcesses = Get-NetTCPConnection -LocalPort $Config.ProxyPort -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique
    if ($ExistingProcesses) {
        foreach ($PID_ in $ExistingProcesses) {
            try {
                # 현재 내 프로세스(PID)는 종료하면 안 됨
                if ($PID_ -ne $PID) {
                    Write-Host "[Startup] Killing stale process (PID: $PID_) on port $($Config.ProxyPort)..." -ForegroundColor Yellow
                    Stop-Process -Id $PID_ -Force -ErrorAction SilentlyContinue
                }
            }
            catch {
                Write-Host "[Startup] Failed to kill process ${PID_}: $_" -ForegroundColor Red
            }
        }
        # 포트 해제 대기
        Start-Sleep -Milliseconds 500
    }
    
    # 상태 변수
    $LastActivityTime = Get-Date
    $Listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse("0.0.0.0"), $Config.ProxyPort)
    
    # Runspace Pool 설정
    $RunspacePool = [runspacefactory]::CreateRunspacePool(1, 10)
    $RunspacePool.Open()
    
    # 연결 처리 스크립트 블록
    $ConnectionHandler = {
        param($Client, $ServerPort, $InitialBuffer, $InitialBytesRead)
        
        try {
            $Stream = $Client.GetStream()
            
            $ServerClient = New-Object System.Net.Sockets.TcpClient
            $ServerClient.Connect("127.0.0.1", $ServerPort)
            $ServerStream = $ServerClient.GetStream()

            if ($InitialBytesRead -gt 0) {
                $ServerStream.Write($InitialBuffer, 0, $InitialBytesRead)
            }

            $Task1 = $Stream.CopyToAsync($ServerStream)
            $Task2 = $ServerStream.CopyToAsync($Stream)

            [System.Threading.Tasks.Task]::WhenAny($Task1, $Task2).Wait()
        }
        catch {
            Write-Host "[Proxy] Connection Error: $_" -ForegroundColor Red
        }
        finally {
            if ($Client) { $Client.Close() }
            if ($ServerClient) { $ServerClient.Close() }
        }
    }
    
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host " Llama VRAM Manager Proxy Started" -ForegroundColor Cyan
    Write-Host " Listening on Port: $($Config.ProxyPort)" -ForegroundColor Cyan
    Write-Host " Target Server Port: $($Config.ServerPort)" -ForegroundColor Cyan
    Write-Host " Idle Timeout: $($Config.IdleTimeout) seconds" -ForegroundColor Cyan
    Write-Host " Press Ctrl+C to stop the server" -ForegroundColor Yellow
    Write-Host "=============================================" -ForegroundColor Cyan
    
    try {
        $Listener.Start()
        
        Write-Host "Opening browser..." -ForegroundColor Cyan
        Start-Process "http://127.0.0.1:$($Config.ProxyPort)"

        while ($true) {
            if ($Listener.Pending()) {
                $Client = $Listener.AcceptTcpClient()
                $Stream = $Client.GetStream()

                $Buffer = New-Object byte[] 4096
                if ($Stream.DataAvailable) {
                    $BytesRead = $Stream.Read($Buffer, 0, $Buffer.Length)
                    $RequestString = [System.Text.Encoding]::UTF8.GetString($Buffer, 0, $BytesRead)
                    
                    $IsIgnoredRequest = $false
                    if ($Config.IgnoredUrlPatterns) {
                        foreach ($Pattern in $Config.IgnoredUrlPatterns) {
                            if ($RequestString -match $Pattern) {
                                $IsIgnoredRequest = $true
                                break
                            }
                        }
                    }

                    $ServerIsRunning = Get-LlamaServerStatus

                    if ($IsIgnoredRequest -and (-not $ServerIsRunning)) {
                        $Client.Close()
                        continue
                    }

                    if (-not $IsIgnoredRequest) {
                        if (-not $ServerIsRunning) {
                            Write-Host "[Proxy] Active request detected. Waking up server..." -ForegroundColor Cyan
                            $started = Start-LlamaServer
                            if (-not $started) {
                                Write-Host "[Proxy] Failed to start server. Rejecting connection." -ForegroundColor Red
                                $Client.Close()
                                continue
                            }
                        }
                        $LastActivityTime = Get-Date
                    }

                    $PowerShell = [powershell]::Create()
                    $PowerShell.RunspacePool = $RunspacePool
                    
                    [void]$PowerShell.AddScript($ConnectionHandler).AddArgument($Client).AddArgument($Config.ServerPort).AddArgument($Buffer).AddArgument($BytesRead)
                    $null = $PowerShell.BeginInvoke()
                }
                else {
                    $Client.Close()
                }
            }
            else {
                $IdleDuration = (Get-Date) - $LastActivityTime
                if ($IdleDuration.TotalSeconds -gt $Config.IdleTimeout) {
                    if (Get-LlamaServerStatus) {
                        Write-Host "[Proxy] Idle timeout reached ($($Config.IdleTimeout)s). Stopping server..." -ForegroundColor Yellow
                        Stop-LlamaServer
                    }
                }
                
                Start-Sleep -Milliseconds 100
            }
        }
    }
    catch {
        Write-Host "[ERROR] Proxy crashed: $_" -ForegroundColor Red
    }
    finally {
        $Listener.Stop()
        $RunspacePool.Close()
        $RunspacePool.Dispose()
        Stop-LlamaServer
    }
}
catch {
    Write-Host "`n[FATAL ERROR] An unhandled exception occurred:" -ForegroundColor Red
    Write-Host $_ -ForegroundColor Red
}
finally {
    Write-Host "`nPress Enter to exit..." -ForegroundColor Gray
    Read-Host
}
