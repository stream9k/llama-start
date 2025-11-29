# Llama Server VRAM Manager

This project is a PowerShell script that saves VRAM by **automatically starting `llama-server.exe` only when there is a request** and **automatically shutting it down when idle for a certain period**.

## 🚀 Features

- **On-Demand Execution**: Automatically wakes up the server when a client calls the API.
- **Auto-Shutdown**: Shuts down the server to release VRAM if there are no requests for a configured time (default 120 seconds).
- **Transparent Proxy**: Clients can always connect to the same port (8033) without needing to know if the server is off.

## 📂 File Structure & Requirements

This project can be used in two ways.

### 1. Single Executable Method (Recommended)

The easiest way.

- **Required Files**:
  - `LlamaManager.exe` (Just run this file!)
  - `llama-server.exe` (Original Llama Server)
  - `.gguf` model files
- **Optional Files**:
  - `config.ps1` (Place it together if you want to change settings, it will be loaded automatically)

### 2. Batch File Method (Script Source)

Use this if you want to modify the code or run it as a script.

- **Required Files**:
  - `start_proxy.bat` (Launcher)
  - `proxy_server.ps1` (Core Logic)
  - `llama-server.exe`
  - `.gguf` model files
- **Optional Files**:
  - `config.ps1` (Configuration File)
  - `kill_proxy.bat` (For forced termination)

## 🚀 How to Use

### Method A: Run LlamaManager.exe (Easy)

1. Double-click `LlamaManager.exe`.
2. Select a model, enter VRAM capacity (Context Size), and Idle Timeout.
3. The browser will open automatically, and it's ready to use.

### Method B: Run start_proxy.bat

1. Double-click `start_proxy.bat`.
2. The rest of the process is the same as above.

### Forced Termination (In case of issues)

Use this when the server does not shut down properly or the port remains occupied.

- Run `kill_proxy.bat` to forcibly terminate processes using ports 8033 and 8034.

## ⚠️ Caution

- **Port Conflicts**: Ensure that ports 8033 (Proxy) and 8034 (Server) are not being used by other programs.
- **Administrator Privileges**: In some cases, administrator privileges may be required to listen on ports.
- **Paths**: If file paths contain spaces, ensure they are properly quoted (handled in config.ps1).

---

# Llama Server VRAM Manager (Korean)

이 프로젝트는 `llama-server.exe`를 항상 켜두지 않고, **요청이 있을 때만 자동으로 실행**하고 **일정 시간 사용하지 않으면 자동으로 종료**하여 VRAM을 절약하는 PowerShell 스크립트입니다.

## 🚀 기능

- **자동 실행 (On-Demand)**: 클라이언트가 API를 호출하면 자동으로 서버를 깨웁니다.
- **자동 종료 (Auto-Shutdown)**: 설정된 시간(기본 120초) 동안 요청이 없으면 서버를 종료하여 VRAM을 해제합니다.
- **투명한 프록시**: 클라이언트는 서버가 꺼져있는지 알 필요 없이 항상 동일한 포트(8033)로 접속하면 됩니다.

## 📂 파일 구조 및 필요 파일

이 프로젝트는 두 가지 방식으로 사용할 수 있습니다.

### 1. 단일 실행 파일 방식 (추천)

가장 간편한 방법입니다.

- **필수 파일**:
  - `LlamaManager.exe` (이 파일 하나만 실행하면 됩니다!)
  - `llama-server.exe` (Llama 서버 원본)
  - `.gguf` 모델 파일들
- **선택 파일**:
  - `config.ps1` (설정을 변경하고 싶을 때 같이 두면 자동으로 읽어옵니다)

### 2. 배치 파일 방식 (스크립트 원본 사용)

코드를 수정하거나 스크립트로 실행하고 싶을 때 사용합니다.

- **필수 파일**:
  - `start_proxy.bat` (실행 파일)
  - `proxy_server.ps1` (핵심 로직)
  - `llama-server.exe`
  - `.gguf` 모델 파일들
- **선택 파일**:
  - `config.ps1` (설정 파일)
  - `kill_proxy.bat` (강제 종료용)

## 🚀 사용 방법

### 방법 A: LlamaManager.exe 실행 (간편)

1. `LlamaManager.exe`를 더블 클릭합니다.
2. 모델을 선택하고, VRAM 용량(Context Size)과 유휴 시간(Idle Timeout)을 입력합니다.
3. 자동으로 브라우저가 열리고 사용 준비가 완료됩니다.

### 방법 B: start_proxy.bat 실행

1. `start_proxy.bat`를 더블 클릭합니다.
2. 나머지 과정은 위와 동일합니다.

### 강제 종료 (문제 발생 시)

서버가 정상적으로 종료되지 않거나 포트가 계속 점유 중일 때 사용하세요.

- `kill_proxy.bat` 파일을 실행하면 8033, 8034 포트를 사용하는 프로세스를 강제로 종료합니다.

## ⚠️ 주의사항

- **포트 충돌**: 8033(Proxy)과 8034(Server) 포트가 다른 프로그램에서 사용 중인지 확인하세요.
- **관리자 권한**: 경우에 따라 포트 리스닝을 위해 관리자 권한이 필요할 수 있습니다.
- **경로**: 파일 경로에 공백이 있다면 따옴표 처리가 잘 되어있는지 확인하세요 (config.ps1에서 처리됨).
