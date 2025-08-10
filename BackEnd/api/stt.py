# import tempfile
# from fastapi import APIRouter, File, UploadFile, Request

# router = APIRouter()

# @router.post("/transcribe")
# async def transcribe_audio(request: Request, file: UploadFile = File(...)):
#     # 업로드된 파일 임시 저장
#     with tempfile.NamedTemporaryFile(delete=False, suffix=".mp3") as tmp:
#         contents = await file.read()
#         tmp.write(contents)
#         tmp_path = tmp.name

#     # main.py에서 로드된 Whisper 모델 사용
#     model = request.app.state.whisper_model
#     result = model.transcribe(tmp_path)
#     return {"text": result["text"]}
import os
import tempfile
import subprocess
from pathlib import Path
from fastapi import APIRouter, File, UploadFile, Request

router = APIRouter()

CT_SUFFIX = {
    "audio/wav": ".wav",
    "audio/x-wav": ".wav",
    "audio/mpeg": ".mp3",
    "audio/mp3": ".mp3",
    "audio/mp4": ".m4a",
    "audio/aac": ".m4a",
    "video/mp4": ".m4a",
    "audio/ogg": ".ogg",
    "audio/webm": ".webm",
}

@router.post("/transcribe")
async def transcribe_audio(request: Request, file: UploadFile = File(...)):
    # 1) 업로드 포맷에 맞게 임시 저장
    ctype = (file.content_type or "").lower()
    orig_suffix = Path(file.filename or "").suffix.lower()
    suffix = CT_SUFFIX.get(ctype) or (orig_suffix if orig_suffix in
              {".wav",".mp3",".m4a",".mp4",".aac",".ogg",".webm"} else ".wav")

    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp_path = tmp.name
        while True:
            chunk = await file.read(1024 * 1024)
            if not chunk:
                break
            tmp.write(chunk)

    # 2) ffmpeg로 16kHz mono WAV로 정규화 (Whisper가 가장 안정적으로 먹음)
    with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as norm:
        norm_path = norm.name

    try:
        subprocess.run(
            ["ffmpeg", "-y", "-i", tmp_path, "-ac", "1", "-ar", "16000", norm_path],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True
        )

        model = request.app.state.whisper_model
        result = model.transcribe(norm_path)  # language='ko' 등을 옵션으로 줄 수 있음
        return {"text": (result.get("text") or "").strip()}

    finally:
        # 3) 임시파일 정리
        for p in (tmp_path, norm_path):
            try:
                os.remove(p)
            except OSError:
                pass
