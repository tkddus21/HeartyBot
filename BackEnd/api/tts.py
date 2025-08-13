from fastapi import APIRouter, Body, HTTPException, Response
from gtts import gTTS
from io import BytesIO

router = APIRouter()

@router.post("/tts")
async def text_to_speech(text: str = Body(..., embed=True)):
    if not text:
        raise HTTPException(status_code=400, detail="텍스트를 입력해주세요.")

    try:
        mp3_fp = BytesIO()
        gTTS(text, lang="ko", slow=False).write_to_fp(mp3_fp)

        mp3_data = mp3_fp.getvalue()
        if len(mp3_data) < 100:
            print("TTS 생성 실패: 생성된 오디오 파일이 너무 작습니다.")
            raise HTTPException(status_code=500, detail="gTTS에서 빈 오디오 파일을 생성했습니다.")

        return Response(
            content=mp3_data,
            media_type="audio/mpeg",
            headers={"Content-Length": str(len(mp3_data))}
        )

    except Exception as e:
        print(f"TTS 생성 중 심각한 오류 발생: {e}")
        raise HTTPException(status_code=500, detail=f"TTS Error: {e}")
