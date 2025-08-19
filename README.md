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

## ⚙️ 환경 변수 설정

이 프로젝트는 OpenAI API를 사용합니다.  
실행 전 [OpenAI API Keys](https://platform.openai.com/account/api-keys)에서 키를 발급받으세요.

프로젝트 루트(`BackEnd/`)에 `.env.dev` 파일을 만들고 다음 내용을 작성합니다:


⚠️ 주의:  
- `.env.dev`는 **절대 GitHub에 올리지 마세요.** (`.gitignore`에 추가되어 있습니다)  
- 각 사용자(심사자)는 **직접 API 키를 발급받아 설정**해야 합니다.  

---

## 📦 설치 방법

### 1. Python 환경 준비
Python 3.9 이상을 권장합니다.

```bash
cd BackEnd
python -m venv venv
source venv/bin/activate   # (Windows: venv\Scripts\activate)
pip install -r requirements.txt
