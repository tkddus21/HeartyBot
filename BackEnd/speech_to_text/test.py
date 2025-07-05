import torch
print("✅ CUDA 사용 가능:", torch.cuda.is_available())

# 3. 파일 업로드
from google.colab import files
uploaded = files.upload()

# 4. Whisper로 음성 → 텍스트 변환
import whisper

model = whisper.load_model("small")  # base, small, medium, large 선택 가능
result = model.transcribe(list(uploaded.keys())[0], language="Korean")

print("📝 변환된 텍스트:")
print(result["text"])