# Head Tracking per Godot

Sistema di tracking della testa usando MediaPipe e webcam.

## 🚀 Installazione Rapida

### Windows
1. Fai doppio click su `setup.bat`
2. Attendi il completamento dell'installazione
3. Avvia il progetto Godot

### Linux/Mac
1. Apri un terminale in questa cartella
2. Esegui: `chmod +x setup.sh && ./setup.sh`
3. Avvia il progetto Godot

## 📋 Requisiti

- **Python 3.8 o superiore** ([Download](https://www.python.org/downloads/))
  - Durante l'installazione su Windows, seleziona "Add Python to PATH"
- Webcam funzionante

## 🛠️ Installazione Manuale

Se gli script automatici non funzionano:

```bash
# Installa le dipendenze
pip install -r requirements.txt
```

## ▶️ Avvio Manuale (per testing)

```bash
# Windows
python head_tracking.py

# Linux/Mac
python3 head_tracking.py
```

Il server WebSocket si avvierà su `ws://127.0.0.1:8765`

## 📦 Dipendenze Installate

- `mediapipe` - Face tracking AI
- `opencv-python` - Computer vision
- `numpy` - Calcoli numerici
- `websockets` - Comunicazione con Godot

## ⚙️ Come Funziona

1. Godot avvia automaticamente `head_tracking.py` all'avvio
2. Lo script Python:
   - Apre la webcam
   - Rileva il volto con MediaPipe
   - Calcola pitch, yaw, roll
   - Invia i dati via WebSocket a Godot
3. Godot riceve i dati e li usa per animazioni/controlli

## 🐛 Problemi Comuni

### "Python non trovato"
- Installa Python da [python.org](https://www.python.org/downloads/)
- Aggiungi Python al PATH

### "Webcam non funziona"
- Controlla i permessi della webcam
- Chiudi altre applicazioni che usano la webcam

### "ModuleNotFoundError"
- Esegui di nuovo `setup.bat` o `setup.sh`
- O manualmente: `pip install mediapipe opencv-python numpy websockets`

## 📝 Note

- Il modello MediaPipe viene scaricato automaticamente al primo avvio (~20 MB)
- La finestra di preview della webcam mostra i valori di tracking in tempo reale
- Premi 'q' sulla finestra di preview per chiudere manualmente
