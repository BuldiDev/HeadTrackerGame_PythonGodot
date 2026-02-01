extends Node

var socket = WebSocketPeer.new()
var pitch : float = 0.0
var yaw : float = 0.0
var roll : float = 0.0
var connected : bool = false
var python_pid : int = 0
var is_connecting : bool = false

func _ready():
	# Avvia lo script Python WebSocket
	var script_path = ProjectSettings.globalize_path("res://Scripts/head_tracking_websocket.py")
	var python_exe = "python" if OS.get_name() == "Windows" else "python3"
	
	python_pid = OS.create_process(python_exe, [script_path])
	
	if python_pid > 0:
		print("Python avviato con PID: ", python_pid)
		# Aspetta che il server si avvii
		await get_tree().create_timer(2.0).timeout
	else:
		print("ERRORE: Impossibile avviare Python")
		return
	
	# Connetti al server WebSocket
	is_connecting = true
	var err = socket.connect_to_url("ws://127.0.0.1:8765")
	if err == OK:
		print("Tentativo connessione WebSocket...")
	else:
		print("Errore WebSocket: ", err)
		is_connecting = false

func _process(_delta):
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
				
				# Usa questi valori!
				# rotation_degrees.z = roll
				# rotation_degrees.x = pitch
				# rotation_degrees.y = yaw
				
	elif state == WebSocketPeer.STATE_CLOSED:
		if connected:
			print("Connessione persa")
			is_connecting = false
		# Riprova a connettersi solo se non sta già provando
		if not is_connecting:
			is_connecting = true
			await get_tree().create_timer(2.0).timeout
			if not connected:  # Verifica ancora se non connesso
				await get_tree().create_timer(2.0).timeout
		socket.connect_to_url("ws://127.0.0.1:8765")

func _exit_tree():
	socket.close()
	
	# Chiudi il processo Python
	if python_pid > 0:
		OS.kill(python_pid)
		print("Processo Python terminato")
