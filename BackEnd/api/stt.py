from fastapi import APIRouter, UploadFile, File, HTTPException, Request
from pydantic import BaseModel
import tempfile
import os

router = APIRouter(prefix="/stt", tags=["stt"])

class TranscribeOut(BaseModel):
    text: str

@router.post("/transcribe", response_model=TranscribeOut)
async def transcribe_audio(request: Request, file: UploadFile = File(...)):
    # 간단한 MIME 체크 (선택)
    if file.content_type not in {
        "audio/mpeg", "audio/mp3", "audio/wav", "audio/x-wav",
        "audio/m4a", "audio/x-m4a", "audio/webm", "audio/ogg"
    }:
        raise HTTPException(status_code=400, detail=f"Unsupported content type: {file.content_type}")

    # 앱 시작 시 로딩한 모델 가져오기
    model = getattr(request.app.state, "whisper_model", None)
    if model is None:
        raise HTTPException(status_code=500, detail="Whisper model not loaded")

    # 업로드 파일을 임시 파일로 저장 (whisper는 파일 경로 필요)
    suffix = os.path.splitext(file.filename or "")[1] or ".mp3"
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            contents = await file.read()
            tmp.write(contents)
            tmp_path = tmp.name

        # 동기 호출이라 I/O 스레드 점유가 걱정되면 run_in_executor 고려
        result = model.transcribe(tmp_path)
        text = result.get("text", "").strip()
        return TranscribeOut(text=text)
    finally:
        try:
            if 'tmp_path' in locals() and os.path.exists(tmp_path):
                os.remove(tmp_path)
        except Exception:
            pass
