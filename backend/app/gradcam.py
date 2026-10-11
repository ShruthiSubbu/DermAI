import os
os.environ["TF_USE_LEGACY_KERAS"] = "1"

import base64
import traceback
import numpy as np
import cv2
import tensorflow as tf
import tf_keras as keras

MODEL_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "model", "dermai_best_model.keras")

_feat_model = None
_head_layers = None


def _load():
    global _feat_model, _head_layers
    if _feat_model is None:
        full_model = keras.models.load_model(MODEL_PATH, compile=False)
        base = full_model.get_layer("mobilenetv2_1.00_224")
        _feat_model = keras.Model(base.input, base.get_layer("out_relu").output)
        _head_layers = full_model.layers[2:]
    return _feat_model, _head_layers


def generate_gradcam(image_bytes: bytes, class_index: int) -> str:
    try:
        feat_model, head_layers = _load()

        nparr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        img_resized = cv2.resize(img_rgb, (224, 224))
        img_array = np.expand_dims(img_resized.astype(np.float32) / 255.0, axis=0)

        with tf.GradientTape() as tape:
            conv_out = feat_model(img_array, training=False)
            tape.watch(conv_out)
            x = conv_out
            for layer in head_layers:
                x = layer(x, training=False)
            loss = x[:, int(class_index)]

        grads = tape.gradient(loss, conv_out)
        pooled = tf.reduce_mean(grads, axis=(0, 1, 2))
        heatmap = tf.squeeze(conv_out[0] @ pooled[..., tf.newaxis]).numpy()
        heatmap = np.maximum(heatmap, 0)
        heatmap = heatmap / (heatmap.max() + 1e-8)

        heatmap = cv2.resize(heatmap, (img.shape[1], img.shape[0]))
        colored = cv2.applyColorMap(np.uint8(255 * heatmap), cv2.COLORMAP_JET)
        overlay = cv2.addWeighted(img, 0.6, colored, 0.4, 0)

        _, buf = cv2.imencode(".jpg", overlay)
        return base64.b64encode(buf).decode("utf-8")

    except Exception:
        print("GRADCAM ERROR:\n" + traceback.format_exc(), flush=True)
        return ""
