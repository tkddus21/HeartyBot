from fastapi import FastAPI
from dotenv import load_dotenv
from contextlib import asynccontextmanager
import whisper

from api import chat, emotion, tts, stt

load_dotenv(dotenv_path=".env.dev")

# 앱 시작·종료 시 모델 로딩/정리
@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.whisper_model = whisper.load_model("base")  # tiny/base/small/medium/large
    print("Whisper 모델 로드 완료")
    try:
        yield
    finally:
        app.state.whisper_model = None
        print("Whisper 모델 로드 실패")

app = FastAPI(lifespan=lifespan)

# 라우터 등록
app.include_router(chat.router)
app.include_router(emotion.router)
app.include_router(tts.router)
app.include_router(stt.router)  # STT 라우터

@app.get("/")
def root():
    return {"message": "Hello from FastAPI chatbot!"}
