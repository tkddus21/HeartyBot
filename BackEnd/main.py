from fastapi import FastAPI, File, UploadFile
from api import chat, emotion, tts
from dotenv import load_dotenv

import whisper

import tempfile
load_dotenv(dotenv_path=".env.dev")


app = FastAPI()

app.include_router(chat.router)
app.include_router(emotion.router)
app.include_router(tts.router)


model = whisper.load_model("base")  # tiny, base, small, medium, large 중 선택


@app.get("/")
@app.post("/transcribe/")
async def transcribe_audio(file: UploadFile = File(...)):
    # 업로드된 파일을 임시 파일로 저장
    with tempfile.NamedTemporaryFile(delete=False, suffix=".mp3") as tmp:
        contents = await file.read()
        tmp.write(contents)
        tmp_path = tmp.name

    # Whisper 모델로 변환
    result = model.transcribe(tmp_path)
    return {"text": result["text"]}

def root():
    return {"message": "Hello from FastAPI chatbot!"}
