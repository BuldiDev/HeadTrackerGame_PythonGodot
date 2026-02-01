extends Node

var tcp : StreamPeerTCP
var pitch : float = 0.0
var yaw : float = 0.0
var roll : float = 0.0

func _ready():
	tcp = StreamPeerTCP.new()
	var result = tcp.connect_to_host("127.0.0.1", 5555)
	if result == OK:
		print("Connessione a Python in corso...")
	else:
		print("Errore connessione")

func _process(_delta):
	if tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		var available_bytes = tcp.get_available_bytes()
		if available_bytes > 0:
			var data = tcp.get_string(available_bytes)
			var lines = data.split("\n", false)
			
			for line in lines:
				var json_result = JSON.parse_string(line)
				if json_result:
					pitch = json_result.get("pitch", 0.0)
					yaw = json_result.get("yaw", 0.0)
					roll = json_result.get("roll", 0.0)
					
					# Usa questi valori come vuoi!
					# Esempio: ruota un nodo
					# rotation_degrees.z = roll
					# rotation_degrees.x = pitch
					# rotation_degrees.y = yaw
					
	elif tcp.get_status() == StreamPeerTCP.STATUS_CONNECTING:
		pass # Ancora in connessione
	elif tcp.get_status() == StreamPeerTCP.STATUS_ERROR or tcp.get_status() == StreamPeerTCP.STATUS_NONE:
		print("Connessione persa, riconnessione...")
		tcp.connect_to_host("127.0.0.1", 5555)

func _exit_tree():
	tcp.disconnect_from_host()
