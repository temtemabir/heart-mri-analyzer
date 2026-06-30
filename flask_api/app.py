from flask import Flask, request, jsonify
import joblib
import cv2
import numpy as np

app = Flask(__name__)

# Charger le modèle
model = joblib.load("random_forest_model.pkl")

@app.route("/predict", methods=["POST"])
def predict():
    try:
        # Récupérer le fichier image
        file = request.files["file"]
        # Lire et prétraiter l'image
        image = cv2.imdecode(np.frombuffer(file.read(), np.uint8), cv2.IMREAD_GRAYSCALE)
        image = cv2.resize(image, (128, 128)).flatten() / 255.0
        # Prédire
        prediction = model.predict([image])
        probability = model.predict_proba([image])[0][1] * 100
        result = {
            "is_sick": bool(prediction[0]),
            "probability": probability
        }
        return jsonify(result)
    except Exception as e:
        return jsonify({"error": str(e)})

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000)

