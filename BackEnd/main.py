from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "공모전용 FastAPI입니다!"}