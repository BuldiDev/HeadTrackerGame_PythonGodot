extends Node

var socket: WebSocketPeer
var pitch : float = 0.0
var yaw : float = 0.0
var roll : float = 0.0
var connected : bool = false
var python_pid : int = 0
var is_connecting : bool = false

# Texture per la webcam
var webcam_texture: ImageTexture
@export var webcam_display: TextureRect  # Opzionale: collegalo nell'editor se vuoi mostrare la webcam

# Sistema di calibrazione
enum CalibrationState { IDLE, WAITING_CENTER, CALIBRATING_RANGE, CALIBRATED }
var calibration_state: CalibrationState = CalibrationState.IDLE

# Calibrazione PITCH (su/giù - controlla altitudine)
var pitch_center: float = 0.0
var pitch_up_max: float = 0.0  # Valore negativo (più in alto)
var pitch_down_max: float = 0.0  # Valore positivo (più in basso)
var pitch_range: float = 30.0  # Range simmetrico finale
var pitch_normalized: float = 0.0  # Valore normalizzato tra -1 e 1

# Calibrazione ROLL (inclinazione laterale - controlla sterzo)
var roll_center: float = 0.0
var roll_left_max: float = 0.0  # Valore negativo (inclinato a sinistra)
var roll_right_max: float = 0.0  # Valore positivo (inclinato a destra)
var roll_range: float = 20.0  # Range simmetrico finale
var roll_normalized: float = 0.0  # Valore normalizzato tra -1 e 1

# UI di calibrazione
var calibration_ui_scene: PackedScene = preload("res://Scenes/CalibrationUI.tscn")
var calibration_ui_instance: CanvasLayer = null
var c_key_was_pressed: bool = false

signal calibration_started()
signal calibration_center_set()
signal calibration_completed(max_range: float)

func _ready():
	# Verifica e installa dipendenze Python
	await check_and_install_dependencies()
	
	# Avvia lo script Python WebSocket
	var script_path = ProjectSettings.globalize_path("res://PythonTracking/head_tracking.py")
	var python_exe = "python" if OS.get_name() == "Windows" else "python3"
	
	# Controlla se Python è installato
	var check_output = []
	var check_result = OS.execute(python_exe, ["--version"], check_output, true)
	
	if check_result != 0:
		push_error("Python non trovato! Installa Python da https://www.python.org/downloads/")
		return
	
	python_pid = OS.create_process(python_exe, [script_path])
	
	if python_pid > 0:
		print("Python avviato con PID: ", python_pid)
		print("Head tracking in esecuzione...")
		# Aspetta che il server si avvii e il modello MediaPipe si carichi
		await get_tree().create_timer(5.0).timeout
	else:
		push_error("ERRORE: Impossibile avviare Python")
		return
	
	# Ora crea il socket e connetti
	socket = WebSocketPeer.new()
	is_connecting = true
	var err = socket.connect_to_url("ws://127.0.0.1:8765")
	if err == OK:
		print("Tentativo connessione WebSocket...")
		print("\n💡 SUGGERIMENTO: Premi C in qualsiasi momento per calibrare il head tracking\n")
	else:
		print("Errore WebSocket: ", err)
		is_connecting = false

func check_and_install_dependencies() -> void:
	var python_exe = "python" if OS.get_name() == "Windows" else "python3"
	
	# Lista di moduli da verificare
	var required_modules = ["mediapipe", "cv2", "numpy", "websockets", "requests"]
	var missing_modules = []
	
	# Verifica quali moduli mancano
	for module in required_modules:
		var check_output = []
		var check_result = OS.execute(python_exe, ["-c", "import " + module], check_output, true)
		if check_result != 0:
			missing_modules.append(module)
	
	if missing_modules.size() > 0:
		print("========================================")
		print("  INSTALLAZIONE DIPENDENZE PYTHON")
		print("========================================")
		print("Moduli mancanti: ", ", ".join(missing_modules))
		print("Installazione in corso, attendere...")
		print("")
		
		# Installa dipendenze dal requirements.txt
		var requirements_path = ProjectSettings.globalize_path("res://PythonTracking/requirements.txt")
		var install_output = []
		var install_result = OS.execute(python_exe, ["-m", "pip", "install", "--user", "-r", requirements_path], install_output, true)
		
		if install_result == 0:
			print("✓ Dipendenze installate con successo!")
			print("")
			# Attendi un momento per assicurarsi che tutto sia caricato
			await get_tree().create_timer(2.0).timeout
		else:
			push_error("ERRORE nell'installazione delle dipendenze!")
			print("Output: ", install_output)
			push_error("Esegui manualmente: pip install -r PythonTracking/requirements.txt")
	else:
		print("✓ Dipendenze Python già installate")

func _process(_delta):
	# Tasto C per aprire/chiudere la UI di calibrazione (con debounce)
	var c_is_pressed = Input.is_key_pressed(KEY_C)
	if c_is_pressed and not c_key_was_pressed:
		print("🔑 Tasto C premuto - Toggle UI calibrazione")
		toggle_calibration_ui()
	c_key_was_pressed = c_is_pressed
	
	if not socket:
		return
		
	socket.poll()
	
	var state = socket.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		if not connected:
			is_connecting = false
			print("✓ CONNESSO al server Python!")
			connected = true
		
		while socket.get_available_packet_count():
			var packet = socket.get_packet()
			var json_string = packet.get_string_from_utf8()
			var json_result = JSON.parse_string(json_string)
			
			if json_result:
				pitch = json_result.get("pitch", 0.0)
				yaw = json_result.get("yaw", 0.0)
				roll = json_result.get("roll", 0.0)
				
				# Durante la calibrazione, traccia i valori min/max relativi al centro
				if calibration_state == CalibrationState.CALIBRATING_RANGE:
					var pitch_offset = pitch - pitch_center
					var roll_offset = roll - roll_center
					
					if pitch_offset < pitch_up_max:
						pitch_up_max = pitch_offset
					if pitch_offset > pitch_down_max:
						pitch_down_max = pitch_offset
					
					if roll_offset < roll_left_max:
						roll_left_max = roll_offset
					if roll_offset > roll_right_max:
						roll_right_max = roll_offset
					
					print("Pitch: [%.1f, %.1f] | Roll: [%.1f, %.1f]" % [pitch_up_max, pitch_down_max, roll_left_max, roll_right_max])
				elif calibration_state == CalibrationState.CALIBRATED:
					# Aggiorna valori normalizzati
					get_normalized_pitch()
					get_normalized_roll()
					# Stampa ogni 30 frame (~1 secondo)
					if Engine.get_process_frames() % 30 == 0:
						print("Pitch: %.1f | Roll: %.1f" % [pitch_normalized, roll_normalized])
				else:
					print("Pitch: %.1f  Yaw: %.1f  Roll: %.1f" % [pitch, yaw, roll])
				
				# Decodifica il frame se presente
				if json_result.has("frame"):
					var frame_base64 = json_result["frame"]
					var frame_bytes = Marshalls.base64_to_raw(frame_base64)
					
					# Crea un'immagine dal buffer JPEG
					var image = Image.new()
					var err = image.load_jpg_from_buffer(frame_bytes)
					
					if err == OK:
						# Crea o aggiorna la texture
						if webcam_texture == null:
							webcam_texture = ImageTexture.create_from_image(image)
						else:
							webcam_texture.update(image)
						
						# Se hai collegato un TextureRect, aggiorna la visualizzazione
						if webcam_display:
							webcam_display.texture = webcam_texture
				
				# Usa questi valori!
				# rotation_degrees.z = roll
				# rotation_degrees.x = pitch
				# rotation_degrees.y = yaw
				
	elif state == WebSocketPeer.STATE_CLOSED:
		if connected:
			print("Connessione persa")
			connected = false
			is_connecting = false
		# Riprova a connettersi solo se non sta già provando
		if not is_connecting:
			is_connecting = true
			await get_tree().create_timer(2.0).timeout
			# Verifica che sia ancora chiuso prima di riconnettersi
			if socket.get_ready_state() == WebSocketPeer.STATE_CLOSED and not connected:
				socket.connect_to_url("ws://127.0.0.1:8765")

# Funzioni UI di calibrazione
func toggle_calibration_ui():
	if calibration_ui_instance:
		# Chiudi la UI se è già aperta
		close_calibration_ui()
	else:
		# Apri la UI di calibrazione
		open_calibration_ui()

func open_calibration_ui():
	if calibration_ui_instance:
		return  # Già aperta
	
	print("\n🎯 Apertura UI di calibrazione...")
	calibration_ui_instance = calibration_ui_scene.instantiate()
	
	# Lo script è sul nodo Control figlio, non sul CanvasLayer
	var control_node = calibration_ui_instance.get_node("Control")
	if control_node:
		control_node.head_tracker = self
	
	# Aggiungi la UI come overlay sulla scena principale
	get_tree().root.add_child(calibration_ui_instance)
	
	# Avvia automaticamente la calibrazione
	start_calibration()

func close_calibration_ui():
	if calibration_ui_instance:
		print("🚪 Chiusura UI di calibrazione")
		calibration_ui_instance.queue_free()
		calibration_ui_instance = null

# Funzioni di calibrazione
func start_calibration():
	print("\n=== INIZIO CALIBRAZIONE ===")
	calibration_state = CalibrationState.WAITING_CENTER
	pitch_up_max = 0.0
	pitch_down_max = 0.0
	roll_left_max = 0.0
	roll_right_max = 0.0
	calibration_started.emit()
	print("Fase 1: Posizionati al CENTRO e premi SPAZIO")

func set_center():
	if calibration_state == CalibrationState.WAITING_CENTER:
		pitch_center = pitch
		roll_center = roll
		print("✓ Centro impostato - Pitch: %.2f, Roll: %.2f" % [pitch_center, roll_center])
		calibration_state = CalibrationState.CALIBRATING_RANGE
		calibration_center_set.emit()
		print("Fase 2: Muovi la testa in TUTTE le direzioni (massimo movimento)")
		print("Su/Giù (per altitudine), Inclina testa Sinistra/Destra (per sterzare)")
		print("Premi SPAZIO quando hai fatto i movimenti massimi")

func complete_calibration():
	if calibration_state == CalibrationState.CALIBRATING_RANGE:
		# Calcola le distanze dal centro per PITCH
		var up_distance = abs(pitch_up_max)
		var down_distance = abs(pitch_down_max)
		pitch_range = min(up_distance, down_distance)
		
		# Calcola le distanze dal centro per ROLL
		var roll_left_distance = abs(roll_left_max)
		var roll_right_distance = abs(roll_right_max)
		roll_range = min(roll_left_distance, roll_right_distance)
		
		print("\n=== CALIBRAZIONE COMPLETATA ===")
		print("PITCH (Su/Giù) - Centro: %.2f | Range: ±%.2f (Su: %.2f, Giù: %.2f)" % [pitch_center, pitch_range, pitch_up_max, pitch_down_max])
		print("ROLL (Sterzo) - Centro: %.2f | Range: ±%.2f (Sx: %.2f, Dx: %.2f)\n" % [roll_center, roll_range, roll_left_max, roll_right_max])
		
		calibration_state = CalibrationState.CALIBRATED
		calibration_completed.emit(pitch_range)

func get_normalized_pitch() -> float:
	if calibration_state != CalibrationState.CALIBRATED:
		return 0.0
	
	# Calcola distanza dal centro
	var offset = pitch - pitch_center
	
	# Normalizza tra -1 e 1
	if pitch_range > 0:
		pitch_normalized = clamp(offset / pitch_range, -1.0, 1.0)
	else:
		pitch_normalized = 0.0
	
	return pitch_normalized

func get_normalized_roll() -> float:
	if calibration_state != CalibrationState.CALIBRATED:
		return 0.0
	
	# Calcola distanza dal centro
	var offset = roll - roll_center
	
	# Normalizza tra -1 e 1
	if roll_range > 0:
		roll_normalized = clamp(offset / roll_range, -1.0, 1.0)
	else:
		roll_normalized = 0.0
	
	return roll_normalized

func _exit_tree():
	socket.close()
	
	# Chiudi il processo Python
	if python_pid > 0:
		OS.kill(python_pid)
		print("Processo Python terminato")
