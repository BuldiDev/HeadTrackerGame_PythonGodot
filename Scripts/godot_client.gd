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

func _exit_tree():
	socket.close()
	
	# Chiudi il processo Python
	if python_pid > 0:
		OS.kill(python_pid)
		print("Processo Python terminato")
