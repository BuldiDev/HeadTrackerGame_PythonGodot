import cv2
import mediapipe as mp
import numpy as np
import asyncio
import websockets
import json

# Variabili globali per i dati
current_data = {"pitch": 0.0, "yaw": 0.0, "roll": 0.0}
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
        if clients:
            message = json.dumps(current_data)
            websockets.broadcast(clients, message)
        await asyncio.sleep(0.01)  # 100 FPS

async def main():
    # Avvia server WebSocket
    async with websockets.serve(handler, "127.0.0.1", 8765):
        print("Server WebSocket avviato su ws://127.0.0.1:8765")
        
        # Task per inviare dati
        send_task = asyncio.create_task(send_data())
        
        # Inizializza MediaPipe
        mp_face_mesh = mp.solutions.face_mesh
        face_mesh = mp_face_mesh.FaceMesh(
            max_num_faces=1,
            refine_landmarks=True,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5
        )
        
        # Inizializza webcam
        cap = cv2.VideoCapture(0)
        print("Webcam aperta. Premi 'q' per uscire")
        
        while True:
            success, image = cap.read()
            if not success:
                break
            
            # Processa immagine
            image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
            results = face_mesh.process(image_rgb)
            
            img_h, img_w = image.shape[:2]
            
            if results.multi_face_landmarks:
                for face_landmarks in results.multi_face_landmarks:
                    # Calcola pitch, yaw, roll
                    face_2d = []
                    face_3d = []
                    
                    for idx in [1, 152, 33, 263, 61, 291]:
                        lm = face_landmarks.landmark[idx]
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
                    success, rot_vec, trans_vec = cv2.solvePnP(face_3d, face_2d, cam_matrix, dist_matrix)
                    
                    rmat, _ = cv2.Rodrigues(rot_vec)
                    angles, _, _, _, _, _ = cv2.RQDecomp3x3(rmat)
                    
                    pitch = angles[0] * 360
                    yaw = angles[1] * 360
                    
                    # Roll dagli occhi
                    left_eye = face_landmarks.landmark[33]
                    right_eye = face_landmarks.landmark[263]
                    delta_y = (right_eye.y - left_eye.y) * img_h
                    delta_x = (right_eye.x - left_eye.x) * img_w
                    roll = np.degrees(np.arctan2(delta_y, delta_x))
                    
                    # Aggiorna dati globali
                    current_data["pitch"] = float(pitch)
                    current_data["yaw"] = float(yaw)
                    current_data["roll"] = float(roll)
                    
                    # Mostra valori
                    cv2.putText(image, f"Pitch: {int(pitch)}", (20, 50), 
                               cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                    cv2.putText(image, f"Yaw: {int(yaw)}", (20, 80), 
                               cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                    cv2.putText(image, f"Roll: {int(roll)}", (20, 110), 
                               cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
            
            cv2.imshow('Head Tracking', image)
            
            if cv2.waitKey(5) & 0xFF == ord('q'):
                break
            
            await asyncio.sleep(0.001)  # Permette al loop async di girare
        
        cap.release()
        cv2.destroyAllWindows()
        send_task.cancel()

if __name__ == "__main__":
    asyncio.run(main())
