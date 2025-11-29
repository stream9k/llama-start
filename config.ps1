# =============================================
# LLAMA SERVER CONFIGURATION
# =============================================

$Config = @{
    # Llama Server Binary Path
    # (상대 경로) 현재 폴더의 llama-server.exe
    LlamaBinary        = "$PSScriptRoot\llama-server.exe"

    # Model Directory
    # (상대 경로) 현재 폴더
    ModelDir           = "$PSScriptRoot"
    
    # ModelPath는 실행 시 선택된 파일로 동적으로 설정됩니다.
    ModelPath          = ""

    # Server Settings
    ServerHost         = "127.0.0.1"
    ServerPort         = 8034  # 실제 llama-server가 내부적으로 사용할 포트 (외부 노출 X)
    ProxyPort          = 8033  # 클라이언트가 접속할 공개 포트 (Proxy가 점유)

    # Performance Settings
    CtxSize            = 8192  # VRAM 부족 시 줄이세요 (예: 4096, 8192)
    Threads            = 6

    # Logging
    LogFile            = "$PSScriptRoot\llama_log.txt"

    # Auto-Shutdown Settings
    IdleTimeout        = 3600  # 초 단위 (이 시간 동안 요청이 없으면 서버 종료)

    # Ignored URL Patterns (Polling requests that shouldn't wake/keep server alive)
    # 정규식 패턴 배열입니다.
    IgnoredUrlPatterns = @(
        "^GET /health",
        "^GET /v1/models",
        "^GET /props",
        "^GET /$"  # Root path check
    )
}
