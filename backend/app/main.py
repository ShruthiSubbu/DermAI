from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import numpy as np
import json
import io
from PIL import Image
import tensorflow as tf
import uvicorn

from app.gradcam import generate_gradcam

# ─── PATHS ───────────────────────────────────────────────────────────────────
TFLITE_PATH   = "app/model/dermai_model.tflite"
LABELMAP_PATH = "app/model/dermai_label_map.json"

# ─── APP ─────────────────────────────────────────────────────────────────────
app = FastAPI(title="DermAI API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── GLOBALS ─────────────────────────────────────────────────────────────────
interpreter = None
idx2label = None

@app.on_event("startup")
def startup_event():
    global interpreter, idx2label

    interpreter = tf.lite.Interpreter(model_path=TFLITE_PATH)
    interpreter.allocate_tensors()

    with open(LABELMAP_PATH) as f:
        raw = json.load(f)
        idx2label = raw["idx2label"]

    print("TFLite model loaded successfully!")

# ─── HEALTH ──────────────────────────────────────────────────────────────────
@app.get("/health")
def health():
    return {"status": "ok", "model": "MobileNetV2-TFLite", "classes": 43}

# ─── ANALYSE ─────────────────────────────────────────────────────────────────
@app.post("/analyse")
async def analyse(file: UploadFile = File(...)):
    contents = await file.read()
    img = Image.open(io.BytesIO(contents)).convert("RGB")
    img_resized = img.resize((224, 224))
    img_array = np.array(img_resized, dtype=np.float32) / 255.0
    img_input = np.expand_dims(img_array, axis=0)

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    interpreter.set_tensor(input_details[0]['index'], img_input)
    interpreter.invoke()
    preds = interpreter.get_tensor(output_details[0]['index'])[0]

    top5_idx = np.argsort(preds)[::-1][:5]
    top5 = [
        {
            "condition": idx2label[str(i)],
            "confidence": round(float(preds[i]) * 100, 2)
        }
        for i in top5_idx
    ]

    pred_label = top5[0]["condition"]
    confidence = top5[0]["confidence"]

    top_class_index = int(top5_idx[0])
    
    try:
        heatmap_b64 = generate_gradcam(contents, top_class_index)
    except Exception as e:
        import traceback
        with open(r'D:\8Queens\DermAI\gradcam_error.txt', 'w') as f:
            f.write(traceback.format_exc())
        heatmap_b64 = ""

    return JSONResponse({
        "prediction": pred_label,
        "confidence": confidence,
        "top5": top5,
        "gradcam": heatmap_b64
    })

if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000)