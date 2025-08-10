# app/api/stt.py
import tempfile
from pathlib import Path
from fastapi import APIRouter, File, UploadFile, Request

router = APIRouter()

@router.post("/transcribe")
async def transcribe_audio(request: Request, file: UploadFile = File(...)):
    # 1) 원본 확장자 유지(없으면 .wav)
    suffix = Path(file.filename or "").suffix or ".wav"

    # 2) 파일 저장 (chunk로 안전하게)
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp_path = tmp.name
        while True:
            chunk = await file.read(1024 * 1024)
            if not chunk:
                break
            tmp.write(chunk)

    # 3) Whisper 추론(정확도 옵션)
    model = request.app.state.whisper_model
    result = model.transcribe(
        tmp_path,
        language="ko",                 # 한국어 고정 (자동언어감지로 인한 오작동 방지)
        task="transcribe",             # 번역 금지
        temperature=0.0,               # 보수적으로
        beam_size=5,                   # beam search
        best_of=5,                     # 후보 더 탐색
        patience=1.0,
        condition_on_previous_text=False,
        # 자주 나오는 단어를 힌트로 주면 더 좋아짐 (자유롭게 바꿔도 됨)
        initial_prompt="일기, 감정, 병원, 통증, 무릎, 허리, 아프다, 기분, 상태, 오늘, 괜찮다, 방문, 갈 예정이다., 예정, 계획",
    )

    return {"text": (result.get("text") or "").strip()}
