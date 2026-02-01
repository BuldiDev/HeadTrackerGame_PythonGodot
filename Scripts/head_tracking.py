import cv2
import mediapipe as mp
import numpy as np
import socket
import json
import sys
import os

# Log per debug - salva nella stessa cartella dello script
script_dir = os.path.dirname(os.path.abspath(__file__))
log_path = os.path.join(script_dir, "python_debug.log")
log_file = open(log_path, "w", buffering=1)
sys.stdout = log_file
sys.stderr = log_file

# Server TCP
HOST = '127.0.0.1'
PORT = 5555

print("=== Script Python avviato ===")
print(f"Log salvato in: {log_path}")

server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

try:
    server_socket.bind((HOST, PORT))
    server_socket.listen(1)
    server_socket.setblocking(False)
    print(f"Server in ascolto su {HOST}:{PORT}")
except Exception as e:
    print(f"ERRORE bind: {e}")
    sys.exit(1)

print("Connetti Godot a questo indirizzo")
print("Premi 'q' per uscire")

client_socket = None

# Inizializza MediaPipe Face Mesh
print("Inizializzazione MediaPipe...")
mp_face_mesh = mp.solutions.face_mesh
mp_drawing = mp.solutions.drawing_utils
mp_drawing_styles = mp.solutions.drawing_styles

face_mesh = mp_face_mesh.FaceMesh(
    max_num_faces=1,
    refine_landmarks=True,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5
)

# Inizializza webcam
print("Apertura webcam...")
cap = cv2.VideoCapture(0)
if not cap.isOpened():
    print("ERRORE: Impossibile aprire la webcam!")
    sys.exit(1)
print("Webcam aperta con successo")
print("Loop principale avviato...")
log_file.flush()

while True:
    # Accetta connessioni in modalità non-bloccante
    if client_socket is None:
        try:
            client_socket, addr = server_socket.accept()
            client_socket.setblocking(False)
            print(f"Godot connesso da {addr}")
            log_file.flush()
        except BlockingIOError:
            pass
    
    success, image = cap.read()
    if not success:
        break
    
    # Converti a RGB per MediaPipe
    image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    results = face_mesh.process(image_rgb)
    
    img_h, img_w = image.shape[:2]
    
    if results.multi_face_landmarks:
        for face_landmarks in results.multi_face_landmarks:
            # Punti chiave per pitch e yaw
            face_2d = []
            face_3d = []
            
            for idx in [1, 152, 33, 263, 61, 291]:
                lm = face_landmarks.landmark[idx]
                x, y = int(lm.x * img_w), int(lm.y * img_h)
                face_2d.append([x, y])
                face_3d.append([x, y, lm.z])
            
            face_2d = np.array(face_2d, dtype=np.float64)
            face_3d = np.array(face_3d, dtype=np.float64)
            
            # Matrice camera
            focal_length = 1 * img_w
            cam_matrix = np.array([
                [focal_length, 0, img_w / 2],
                [0, focal_length, img_h / 2],
                [0, 0, 1]
            ])
            
            # Distorsione nulla
            dist_matrix = np.zeros((4, 1), dtype=np.float64)
            
            # Risolvi PnP per pitch e yaw
            success, rot_vec, trans_vec = cv2.solvePnP(face_3d, face_2d, cam_matrix, dist_matrix)
            
            # Ottieni rotazione
            rmat, _ = cv2.Rodrigues(rot_vec)
            angles, _, _, _, _, _ = cv2.RQDecomp3x3(rmat)
            
            # Angoli pitch e yaw
            pitch = angles[0] * 360
            yaw = angles[1] * 360
            
            # CALCOLO ROLL DAGLI OCCHI
            left_eye_outer = face_landmarks.landmark[33]
            right_eye_outer = face_landmarks.landmark[263]
            
            # Converti in coordinate pixel
            left_eye_x = left_eye_outer.x * img_w
            left_eye_y = left_eye_outer.y * img_h
            right_eye_x = right_eye_outer.x * img_w
            right_eye_y = right_eye_outer.y * img_h
            
            # Calcola l'angolo tra gli occhi
            delta_y = right_eye_y - left_eye_y
            delta_x = right_eye_x - left_eye_x
            roll = np.degrees(np.arctan2(delta_y, delta_x))
            
            # Mostra i valori
            cv2.putText(image, f"Pitch (su/giu): {int(pitch)}", (20, 50), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
            cv2.putText(image, f"Yaw (sx/dx): {int(yaw)}", (20, 80), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
            cv2.putText(image, f"Roll (inclina): {int(roll)}", (20, 110), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
            
            # Invia dati a Godot via TCP
            if client_socket:
                data = {
                    "pitch": float(pitch),
                    "yaw": float(yaw),
                    "roll": float(roll)
                }
                try:
                    message = json.dumps(data) + "\n"
                    client_socket.sendall(message.encode())
                except (BrokenPipeError, ConnectionResetError):
                    print("Godot disconnesso")
                    log_file.flush()
                    client_socket = None
    
    # Mostra l'immagine
    cv2.imshow('Head Tracking', image)
    
    if cv2.waitKey(5) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
if client_socket:
    client_socket.close()
server_socket.close()
log_file.close()
