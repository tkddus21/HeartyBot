from fastapi import APIRouter, Body, HTTPException
from fastapi.responses import FileResponse
from openai import OpenAI
from gtts import gTTS
from datetime import datetime
import os

router = APIRouter()

OPENAI_KEY = os.getenv("OPENAI_API_KEY")
client = OpenAI(api_key=OPENAI_KEY)
GPT_MODEL = "gpt-4o-mini"

def generate_prompt(user_input: str, medicine_time: bool = False) -> str:
    today = datetime.now().strftime("%Y년 %m월 %d일")
    system_message = (
        f"너는 어르신과 대화하는 다정한 한국어 챗봇이야. "
        f"항상 공감하고 존중하는 말투를 써. 인사말은 한 번만 자연스럽게 하고 반복하지 마. "
        f"오늘은 {today}이야. 실시간 정보는 제공할 수 없으니 양해를 구하고, 가능한 정보 내에서 답변해줘."
    )

    if medicine_time:
        user_input = f"[중요 공지: 지금 약 드실 시간입니다!] {user_input}"

    return system_message, user_input

def gpt_reply(sys_prompt: str, user_input: str) -> str:
    messages = [
        {"role": "system", "content": sys_prompt},
        {"role": "user", "content": user_input}
    ]

    try:
        response = client.chat.completions.create(
            model=GPT_MODEL,
            messages=messages,
            max_tokens=200,
        )
        return response.choices[0].message.content.strip()
    except Exception as e:
        raise RuntimeError(f"GPT TTS Error: {e}")

@router.post("/chat-tts")
async def chat_tts(
    user_input: str = Body(..., embed=True),
    medicine_time: bool = Body(False, embed=True)
):
    try:
        sys_prompt, prompt = generate_prompt(user_input, medicine_time)
        generated = gpt_reply(sys_prompt, prompt)

        # 최대 2~3문장만 반환
        sentences = generated.split("다.")
        tts_text = "다.".join(sentences[:3]).strip()
        if not tts_text.endswith("다.") and len(sentences) >= 1:
            tts_text += "다."

        # TTS 처리
        tts = gTTS(tts_text, lang="ko")
        filepath = "chatbot_reply.mp3"
        tts.save(filepath)

        return FileResponse(filepath, media_type="audio/mpeg", filename="chatbot_reply.mp3")

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
