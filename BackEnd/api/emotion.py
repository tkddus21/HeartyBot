from fastapi import APIRouter, HTTPException, Body
from openai import OpenAI
import os

router = APIRouter()

OPENAI_KEY = os.getenv("OPENAI_API_KEY")
client = OpenAI(api_key=OPENAI_KEY)
GPT_MODEL = "gpt-4o-mini"


def gpt_sentiment(user_input: str) -> dict:
    sys_prompt = (
        "너는 텍스트 감정분석기야. 사용자의 텍스트가 긍정/부정/중립 중 어느 것에 가까운지 판단해. "
        "결과는 반드시 '감정: [긍정/부정/중립], 이유: [한 문장]'으로 출력해."
    )

    messages = [
        {"role": "system", "content": sys_prompt},
        {"role": "user", "content": user_input}
    ]

    try:
        response = client.chat.completions.create(
            model=GPT_MODEL,
            messages=messages,
            max_tokens=100,
        )
        answer = response.choices[0].message.content.strip()

        label, reason = "알수없음", ""
        if answer.startswith("감정:"):
            try:
                label = answer.split(",")[0].split(":")[1].strip()
                reason = answer.split("이유:")[1].strip()
            except:
                reason = answer
        else:
            reason = answer

        return {"emotion": label, "reason": reason}
    except Exception as e:
        raise RuntimeError(f"GPT Sentiment Error: {e}")


@router.post("/emotion")
async def emotion_api(
    user_input: str = Body(..., embed=True)
):
    try:
        res = gpt_sentiment(user_input)
        return res
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
