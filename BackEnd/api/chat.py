from fastapi import APIRouter, HTTPException, Body
from datetime import datetime
from openai import OpenAI
import os

router = APIRouter()

OPENAI_KEY = os.getenv("OPENAI_API_KEY")
if not OPENAI_KEY:
    raise RuntimeError("환경변수 OPENAI_API_KEY가 설정되어 있지 않습니다.")
client = OpenAI(api_key=OPENAI_KEY)
GPT_MODEL = "gpt-4o-mini"


def gpt_chatbot(user_input: str, medicine_time: bool = False) -> str:
    today = datetime.now().strftime("%Y년 %m월 %d일")
    sys_prompt = (
        f"너는 어르신과 대화하는 다정한 한국어 챗봇이야. "
        f"항상 공감하고 존중하는 말투를 써. 인사말은 한 번만 자연스럽게 하고 반복하지 마. "
        f"오늘은 {today}이야. 실시간 정보는 제공할 수 없으니 양해를 구하고, 가능한 정보 내에서 답변해줘."
    )
    if medicine_time:
        user_input = f"[중요 공지: 지금 약 드실 시간입니다!] {user_input}"

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
        raise RuntimeError(f"GPT Chatbot Error: {e}")


@router.post("/chat")
async def chat(
    user_input: str = Body(..., embed=True),
    medicine_time: bool = Body(False, embed=True)
):
    try:
        reply = gpt_chatbot(user_input, medicine_time)
        return {"response": reply}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
