from fastapi import FastAPI
from api import chat, emotion, tts
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()

app.include_router(chat.router)
app.include_router(emotion.router)
app.include_router(tts.router)

@app.get("/")
def root():
    return {"message": "Hello from FastAPI chatbot!"}
