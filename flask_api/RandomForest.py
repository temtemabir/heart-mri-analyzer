import os
import cv2
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, accuracy_score, confusion_matrix, ConfusionMatrixDisplay
import matplotlib.pyplot as plt
import joblib

# Définir le répertoire de base et les catégories
base_dir = "Converted Dataset"
categories = ["Normal", "Sick"]

data = []
labels = []

def load_images_from_folder(folder, label):
    """ Fonction récursive pour charger les images dans un dossier et ses sous-dossiers """
    for root, _, files in os.walk(folder):  # os.walk parcourt récursivement les dossiers
        for file in files:
            # Vérifier si le fichier a une extension d'image valide
            if file.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp', '.tiff')):
                file_path = os.path.join(root, file)
                try:
                    # Charger et redimensionner l'image
                    img = cv2.imread(file_path, cv2.IMREAD_GRAYSCALE)
                    if img is None:
                        print(f"Impossible de lire l'image : {file_path}")
                        continue
                    
                    img = cv2.resize(img, (128, 128))  # Redimensionner
                    data.append(img.flatten() / 255.0)  # Normaliser (0 à 1)
                    labels.append(label)
                except Exception as e:
                    print(f"Erreur avec le fichier {file_path}: {e}")

# Charger les images pour chaque catégorie
for category in categories:
    path = os.path.join(base_dir, category)
    label = categories.index(category)  # 0 pour Normal, 1 pour Sick
    
    if not os.path.exists(path):
        print(f"Répertoire introuvable : {path}")
        continue
    
    load_images_from_folder(path, label)

# Vérifier que des données ont été chargées
if len(data) == 0 or len(labels) == 0:
    print("Aucune donnée valide trouvée. Veuillez vérifier vos fichiers.")
    exit()

# Convertir les données en numpy arrays
data = np.array(data)
labels = np.array(labels)

# Diviser les données en ensembles d'entraînement et de test
X_train, X_test, y_train, y_test = train_test_split(data, labels, test_size=0.2, random_state=42)

# Entraîner le modèle
rf_model = RandomForestClassifier(n_estimators=100, random_state=42)
rf_model.fit(X_train, y_train)

# Évaluer le modèle
y_pred = rf_model.predict(X_test)
print("Accuracy:", accuracy_score(y_test, y_pred))
print("Classification Report:\n", classification_report(y_test, y_pred))

# Matrice de confusion
cm = confusion_matrix(y_test, y_pred, labels=rf_model.classes_)
disp = ConfusionMatrixDisplay(confusion_matrix=cm, display_labels=categories)
disp.plot(cmap=plt.cm.Blues)
plt.show()

# Sauvegarder le modèle
model_path = "random_forest_model.pkl"
joblib.dump(rf_model, model_path)
print(f"Modèle sauvegardé sous : {model_path}")
