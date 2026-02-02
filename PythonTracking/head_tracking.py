import sys
import subprocess

# Verifica e installa dipendenze se necessario
def check_and_install_dependencies():
    required = {
        'cv2': 'opencv-python',
        'mediapipe': 'mediapipe',
        'numpy': 'numpy',
        'websockets': 'websockets'
    }
    
    missing = []
    for module, package in required.items():
        try:
            __import__(module)
            print(f"✓ {package} installato")
        except ImportError:
            missing.append(package)
            print(f"✗ {package} mancante")
    
    if missing:
        print(f"\n⚠️  Librerie mancanti: {', '.join(missing)}")
        print("Esegui questo comando per installarle:")
        print(f"   pip install {' '.join(missing)}")
        print("\nPremi Invio per uscire...")
        input()
        sys.exit(1)

print("Controllo dipendenze...")
check_and_install_dependencies()
print("✓ Tutte le dipendenze sono installate!\n")

import cv2
import mediapipe as mp
import numpy as np
import asyncio
import websockets
import json
import os
import urllib.request
import base64

# Scarica il modello face_landmarker se non esiste
def download_face_model():
    import requests
    script_dir = os.path.dirname(os.path.abspath(__file__))
    model_path = os.path.join(script_dir, 'face_landmarker.task')
    
    if not os.path.exists(model_path):
        print("📥 Scaricamento modello face_landmarker...")
        url = "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/latest/face_landmarker.task"
        try:
            response = requests.get(url, timeout=30)
            response.raise_for_status()
            with open(model_path, 'wb') as f:
                f.write(response.content)
            print("✓ Modello scaricato!\n")
        except Exception as e:
            print(f"❌ Errore nel download del modello: {e}")
            return None
    return model_path

model_path = download_face_model()
if not model_path:
    print("Impossibile continuare senza il modello.")
    sys.exit(1)

# Variabili globali per i dati
current_data = {"pitch": 0.0, "yaw": 0.0, "roll": 0.0}
current_frame = None
clients = set()

# Server WebSocket
async def handler(websocket):
    clients.add(websocket)
    print(f"Client connesso: {websocket.remote_address}")
    try:
        await websocket.wait_closed()
    finally:
        clients.remove(websocket)
        print(f"Client disconnesso")

async def send_data():
    while True:
        if clients and current_frame is not None:
            # Codifica il frame in JPEG
            _, buffer = cv2.imencode('.jpg', current_frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
            frame_base64 = base64.b64encode(buffer).decode('utf-8')
            
            # Prepara messaggio con dati e frame
            message = json.dumps({
                "pitch": current_data["pitch"],
                "yaw": current_data["yaw"],
                "roll": current_data["roll"],
                "frame": frame_base64
            })
            websockets.broadcast(clients, message)
        await asyncio.sleep(0.033)  # ~30 FPS per il video

async def main():
    # Avvia server WebSocket
    async with websockets.serve(handler, "127.0.0.1", 8765):
        print("Server WebSocket avviato su ws://127.0.0.1:8765")
        
        # Task per inviare dati
        send_task = asyncio.create_task(send_data())
        
        # Inizializza MediaPipe FaceLandmarker con tasks API
        from mediapipe import tasks
        from mediapipe.tasks import python
        from mediapipe.tasks.python import vision
        
        base_options = python.BaseOptions(model_asset_path=model_path)
        options = vision.FaceLandmarkerOptions(
            base_options=base_options,
            running_mode=vision.RunningMode.VIDEO,
            num_faces=1,
            min_face_detection_confidence=0.5,
            min_face_presence_confidence=0.5,
            min_tracking_confidence=0.5
        )
        
        landmarker = vision.FaceLandmarker.create_from_options(options)
        print("✓ MediaPipe FaceLandmarker inizializzato\n")
        
        # Inizializza webcam
        cap = cv2.VideoCapture(0)
        if not cap.isOpened():
            print("ERRORE: Impossibile aprire la webcam")
            return
            
        print("✓ Webcam aperta - tracking in corso...")
        
        frame_count = 0
        
        # Modello 3D generico del viso
        model_points = np.array([
            (0.0, 0.0, 0.0),
            (0.0, -330.0, -65.0),
            (-225.0, 170.0, -135.0),
            (225.0, 170.0, -135.0),
            (-150.0, -150.0, -125.0),
            (150.0, -150.0, -125.0)
        ], dtype=np.float64)
        
        while True:
            success, image = cap.read()
            if not success:
                await asyncio.sleep(0.01)
                continue
            
            frame_count += 1
            img_h, img_w = image.shape[:2]
            
            # Usa MediaPipe tasks API
            image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
            mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=image_rgb)
            
            # Processa con il landmarker
            timestamp_ms = int(frame_count * 33)  # ~30 FPS
            results = landmarker.detect_for_video(mp_image, timestamp_ms)
            
            if results.face_landmarks:
                for face_landmarks in results.face_landmarks:
                    face_2d = []
                    face_3d = []
                    
                    for idx in [1, 152, 33, 263, 61, 291]:
                        lm = face_landmarks[idx]
                        x, y = int(lm.x * img_w), int(lm.y * img_h)
                        face_2d.append([x, y])
                        face_3d.append([x, y, lm.z])
                    
                    face_2d = np.array(face_2d, dtype=np.float64)
                    face_3d = np.array(face_3d, dtype=np.float64)
                    
                    focal_length = 1 * img_w
                    cam_matrix = np.array([
                        [focal_length, 0, img_w / 2],
                        [0, focal_length, img_h / 2],
                        [0, 0, 1]
                    ])
                    
                    dist_matrix = np.zeros((4, 1), dtype=np.float64)
                    success_pnp, rot_vec, trans_vec = cv2.solvePnP(face_3d, face_2d, cam_matrix, dist_matrix)
                    
                    if success_pnp:
                        rmat, _ = cv2.Rodrigues(rot_vec)
                        angles, _, _, _, _, _ = cv2.RQDecomp3x3(rmat)
                        
                        pitch = angles[0] * 360
                        yaw = angles[1] * 360
                        
                        # Roll dagli occhi
                        left_eye = face_landmarks[33]
                        right_eye = face_landmarks[263]
                        delta_y = (right_eye.y - left_eye.y) * img_h
                        delta_x = (right_eye.x - left_eye.x) * img_w
                        roll = np.degrees(np.arctan2(delta_y, delta_x))
                    else:
                        pitch = yaw = roll = 0.0
                    
                    current_data["pitch"] = float(pitch)
                    current_data["yaw"] = float(yaw)
                    current_data["roll"] = float(roll)
            
            # Aggiorna il frame corrente per l'invio
            global current_frame
            current_frame = image
            
            if frame_count % 3 == 0:
                await asyncio.sleep(0.001)
        
        cap.release()
        send_task.cancel()

if __name__ == "__main__":
    asyncio.run(main())
