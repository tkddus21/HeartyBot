from fastapi import FastAPI
from dotenv import load_dotenv

from api import chat, emotion, tts, stt

import whisper
from contextlib import asynccontextmanager

load_dotenv()

# 앱 라이프사이클에 모델 로딩을 묶기 (앱 시작 시 1회 로딩)
@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.whisper_model = whisper.load_model("base")  # tiny/base/small/medium/large
    try:
        yield
    finally:
        # 필요 시 정리 작업
        app.state.whisper_model = None

app = FastAPI(lifespan=lifespan)

# 다른 라우터들
app.include_router(chat.router)
app.include_router(emotion.router)
app.include_router(tts.router)
app.include_router(stt.router)  # 👈 STT 라우터 추가

@app.get("/")
def root():
    return {"message": "Hello from FastAPI chatbot!"}
