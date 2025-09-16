# ddobaki_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


---

# HeartyBot
당신의 마음을 듣는 따뜻한 AI 챗봇

HeartyBot은 FastAPI와 Flutter로 개발된 음성/텍스트 기반의 AI 챗봇 프로젝트입니다. 바쁜 일상 속에서 대화 상대가 필요하거나, 자신의 감정을 편안하게 이야기하고 싶은 사람들을 위해 따뜻한 말벗이 되어주는 것을 목표로 합니다. 사용자의 음성을 실시간으로 인식하고, 텍스트 분석을 통해 감정을 이해하며, 자연스러운 음성으로 답변합니다.

주요 기능
실시간 음성 대화: 사용자의 목소리를 Whisper 모델로 즉시 텍스트로 변환하여, 실제 사람과 대화하는 것처럼 자연스러운 소통이 가능합니다.

감정 분석 및 공감: OpenAI API를 활용해 대화 내용 속 사용자의 감정을 파악하고, 그에 맞는 위로와 격려의 메시지를 전달합니다.

텍스트 채팅: 음성 사용이 어려운 환경을 위해 기본적인 텍스트 기반 채팅을 지원합니다.

음성 답변 (TTS): 챗봇의 답변을 자연스러운 목소리로 들려주어 더욱 생동감 있는 대화 경험을 제공합니다.


사용 기술 (Tech Stack)

BackEnd: FastAPI (Python)를 사용하여 비동기 처리를 통해 빠르고 효율적인 API 서버를 구축했습니다.

FrontEnd: Flutter를 채택하여 Android, iOS 등 다양한 플랫폼에서 동일한 UI와 경험을 제공하는 크로스플랫폼 앱을 개발했습니다.

STT (Speech-to-Text): OpenAI-Whisper 모델을 활용하여 높은 정확도의 음성-텍스트 변환 기능을 구현했습니다.

AI Chat: OpenAI API (GPT)를 연동하여 문맥을 이해하고 감성적인 답변을 생성하는 챗봇 로직을 구현했습니다.

Database: Firebase를 사용하여 사용자 인증 및 채팅 데이터를 실시간으로 동기화하고 관리합니다.

---

## 📂 프로젝트 구조

```
HeartyBot/
├─ BackEnd/                 # FastAPI 서버 (Python)
│  ├─ api/                  # API 라우터 (chat, emotion, tts, stt 등)
│  ├─ services/             # 비즈니스 로직 모듈
│  ├─ utils/                # 유틸리티 함수
│  ├─ main.py               # FastAPI 앱 진입점
│  └─ requirements.txt      # Python 의존성 목록
│
└─ FrontEnd/                # Flutter 앱
   ├─ android/              # Android 플랫폼 코드
   ├─ ios/                  # iOS 플랫폼 코드
   ├─ linux/                # Linux 빌드 관련
   ├─ macos/                # macOS 빌드 관련
   ├─ windows/              # Windows 빌드 관련
   ├─ lib/                  # Flutter Dart 코드 (UI/로직)
   ├─ assets/               # 이미지, 폰트 등 리소스
   └─ test/                 # 테스트 코드
```

---

## ⚙️ 사전 준비

- Python 3.9 이상
- Flutter SDK (stable)
- Firebase 프로젝트
  - Android: `FrontEnd/android/app/google-services.json`
  - iOS: `FrontEnd/ios/Runner/GoogleService-Info.plist`
  - Web: `FrontEnd/web/index.html`에 Firebase SDK 추가
- ffmpeg (Whisper 실행에 필요)
---

## 🔑 Environment Variables

- 모든 환경 변수는 `secrets/.env` 파일에서 관리합니다.  
- 이 `secrets` 폴더는 별도의 Private Repository(Submodule)로 관리되며, 프로젝트를 클론할 때 반드시 submodule을 초기화해야 합니다.

### 코드에서 불러오기
- **Python (BackEnd)**  
  ```python
  from dotenv import load_dotenv
  import os

  load_dotenv("secrets/.env")
  api_key = os.getenv("OPENAI_API_KEY")

- **Node.js (FrontEnd)**
    ```js
   import dotenv from "dotenv";
   dotenv.config({ path: "secrets/.env" });

   const apiKey = process.env.OPENAI_API_KEY;
   ```

---

## 📦 백엔드 설치 & 실행

```bash
cd BackEnd
python -m venv venv
source venv/bin/activate   # (Windows: venv\Scripts\activate)
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

- API 문서 확인: http://localhost:8000/docs  
- 헬스체크: http://localhost:8000/health  

---

## 📦 requirements.txt

```txt
# ───────── 기본 서버 ─────────
fastapi
uvicorn
python-dotenv
requests

# ───────── AI/음성 ─────────
openai
gtts
speechrecognition

# ───────── Whisper ─────────
openai-whisper
torch>=2.0.0
```

---

## 🎤 ffmpeg 설치 가이드

### 🔹 Ubuntu / Debian (Linux)
```bash
sudo apt-get update
sudo apt-get install ffmpeg
```

### 🔹 macOS (Homebrew)
```bash
brew install ffmpeg
```

### 🔹 Windows
1. [FFmpeg Windows builds (gyan.dev)](https://www.gyan.dev/ffmpeg/builds/) 에서 **release full** ZIP 다운로드  
2. 압축 해제 후 `bin/` 폴더 안의 `ffmpeg.exe` 확인  
3. `bin` 경로를 **환경 변수 PATH**에 추가  
   - 제어판 → 시스템 → 고급 시스템 설정 → 환경 변수 → Path  
   - 예: `C:\ffmpeg\bin`
4. 설치 확인:
   ```powershell
   ffmpeg -version
   ```

---

## 📱 프론트엔드 실행 (Flutter)

```bash
cd FrontEnd
flutter pub get

# Android 에뮬레이터
flutter run -d emulator-5554

# iOS 시뮬레이터
flutter run -d ios

# Web
flutter run -d chrome
```

---

## 🚀 API 예시

### 기본 라우트
```bash
GET / → {"message": "Hello from FastAPI chatbot!"}
```

### 에코 API (예시)
```python
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()

class EchoIn(BaseModel):
    msg: str

@app.post("/echo")
def echo(body: EchoIn):
    return {"echo": body.msg}
```

---

##  체크리스트

- [ ] `.env.dev` 작성 (`OPENAI_API_KEY` 필수)  
- [ ] ffmpeg 설치 완료  
- [ ] Firebase 설정 파일(Android/iOS/Web) 추가  
- [ ] `uvicorn main:app --reload` 정상 실행  
- [ ] Flutter 앱에서 API 호출 확인  
---
# English version
---
# HeartyBot

A voice/text chatbot project built with FastAPI + Flutter  
(Integrated with OpenAI API, Whisper, Firebase)

---

## 📂 Project Structure

```
HeartyBot/
├─ BackEnd/                 # FastAPI server (Python)
│  ├─ api/                  # API routers (chat, emotion, tts, stt, etc.)
│  ├─ services/             # Business logic modules
│  ├─ utils/                # Utility functions
│  ├─ main.py               # FastAPI entry point
│  └─ requirements.txt      # Python dependencies
│
└─ FrontEnd/                # Flutter app
   ├─ android/              # Android platform code
   ├─ ios/                  # iOS platform code
   ├─ linux/                # Linux build files
   ├─ macos/                # macOS build files
   ├─ windows/              # Windows build files
   ├─ lib/                  # Flutter Dart code (UI/logic)
   ├─ assets/               # Assets (images, fonts, etc.)
   └─ test/                 # Test code
```

---

## ⚙️ Prerequisites

- Python 3.9+
- Flutter SDK (stable)
- Firebase project
  - Android: `FrontEnd/android/app/google-services.json`
  - iOS: `FrontEnd/ios/Runner/GoogleService-Info.plist`
  - Web: `FrontEnd/web/index.html` with Firebase SDK snippet
- ffmpeg (required by Whisper)

---

## 🔑 Environment Variables

### Create `.env.dev`

Create a file at `BackEnd/.env.dev` with the following content:

```env
# OpenAI API Key (required)
OPENAI_API_KEY=sk-xxxxxxx

# Whisper model type (tiny / base / small / medium / large)
WHISPER_MODEL=base

# App environment (optional: dev / prod)
APP_ENV=dev
```

> ⚠️ Never commit `.env.dev` to GitHub. (It is already included in `.gitignore`)

---

## 📦 Backend Setup & Run

```bash
cd BackEnd
python -m venv venv
source venv/bin/activate   # (Windows: venv\Scripts\activate)
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

- API docs: http://localhost:8000/docs  
- Health check: http://localhost:8000/health  

---

## 📦 requirements.txt

```txt
# ───────── Core server ─────────
fastapi
uvicorn
python-dotenv
requests

# ───────── AI / Voice ─────────
openai
gtts
speechrecognition

# ───────── Whisper ─────────
openai-whisper
torch>=2.0.0
```

---

## 🎤 ffmpeg Installation Guide

### 🔹 Ubuntu / Debian (Linux)
```bash
sudo apt-get update
sudo apt-get install ffmpeg
```

### 🔹 macOS (Homebrew)
```bash
brew install ffmpeg
```

### 🔹 Windows
1. Download **release full** ZIP from [FFmpeg Windows builds (gyan.dev)](https://www.gyan.dev/ffmpeg/builds/)  
2. Extract and locate `bin/ffmpeg.exe`  
3. Add the `bin` path to **Environment Variables → Path**  
   - Example: `C:\ffmpeg\bin`
4. Verify installation:
   ```powershell
   ffmpeg -version
   ```

---

## 📱 Frontend Setup (Flutter)

```bash
cd FrontEnd
flutter pub get

# Android emulator
flutter run -d emulator-5554

# iOS simulator
flutter run -d ios

# Web
flutter run -d chrome
```

---

## 🚀 API Examples

### Root route
```bash
GET / → {"message": "Hello from FastAPI chatbot!"}
```

### Echo API (example)
```python
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()

class EchoIn(BaseModel):
    msg: str

@app.post("/echo")
def echo(body: EchoIn):
    return {"echo": body.msg}
```

---

##  Checklist

- [ ] Create `.env.dev` (`OPENAI_API_KEY` required)  
- [ ] Install ffmpeg  
- [ ] Add Firebase config files (Android/iOS/Web)  
- [ ] Run backend with `uvicorn main:app --reload`  
- [ ] Verify Flutter app can call the API


👥 팀원 및 역할 (Team & Roles)
본 프로젝트는 아래 팀원들의 협력을 통해 개발되었습니다. 

김건후	백엔드 개발, FastAPI 서버 구축	
윤준식	프론트엔드 개발, Flutter UI/UX 구현	
이상연	백엔드 개발, Whisper 기능 개발	



