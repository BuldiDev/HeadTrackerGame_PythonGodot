extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5

# Riferimento al client di head tracking
var head_tracker: Node = null

func _ready():
	# Cerca il nodo godot_client nella scena - il nodo si chiama HeadController in Main.tscn
	head_tracker = get_node_or_null("/root/Main/HeadController")
	if not head_tracker:
		head_tracker = get_node_or_null("/root/HeadController")
	if not head_tracker:
		head_tracker = get_node_or_null("/root/Main/GodotClient")
	
	if head_tracker:
		print("✓ Head tracker connesso all'aereo: ", head_tracker.name)
	else:
		push_warning("⚠ Head tracker non trovato, usando controlli tastiera")

func _physics_process(delta: float) -> void:
	var pitch_input := 0.0  # Controlla su/giù (altitudine)
	var roll_input := 0.0   # Controlla sterzo (rotazione)
	
	var is_flying = not is_on_floor()
	
	# Se il tracker è calibrato, usa i valori della testa
	if head_tracker and head_tracker.calibration_state == head_tracker.CalibrationState.CALIBRATED:
		# Pitch: movimento testa su/giù controlla altitudine
		pitch_input = head_tracker.get_normalized_pitch()  # -1 (su) a 1 (giù)
		if abs(pitch_input) < 0.15:
			pitch_input = 0.0
		
		# Roll: inclinazione testa controlla sterzo
		roll_input = head_tracker.get_normalized_roll()  # -1 (sinistra) a 1 (destra)
		if abs(roll_input) < 0.1:
			roll_input = 0.0
		
		# Debug
		if Engine.get_process_frames() % 30 == 0:
			print("Aereo - Pitch: %.2f | Roll: %.2f | Velocity.y: %.2f | Flying: %s" % [pitch_input, roll_input, velocity.y, is_flying])
	else:
		# Fallback ai controlli tastiera
		pitch_input = Input.get_axis("ui_down", "ui_up")  # Su/Giù per altitudine
		roll_input = Input.get_axis("ui_left", "ui_right")  # Sinistra/Destra per sterzo
	
	# Accelerazione con SPAZIO
	var is_accelerating = Input.is_physical_key_pressed(KEY_SPACE)
	
	if is_accelerating:
		# Muovi l'aereo in avanti nella direzione in cui sta guardando
		var forward = -global_transform.basis.z
		velocity.x = forward.x * SPEED
		velocity.z = forward.z * SPEED
	else:
		# Decelera solo movimento orizzontale
		velocity.x = move_toward(velocity.x, 0, SPEED * delta * 3.0)
		velocity.z = move_toward(velocity.z, 0, SPEED * delta * 3.0)
	
	# Roll (sterzo) funziona solo in volo
	if is_flying and abs(roll_input) > 0.01:
		rotate_y(roll_input * 1.5 * delta)
	
	# Applica gravità sempre
	velocity.y -= 9.8 * delta
	
	# Pitch controlla l'altitudine (funziona sempre per permettere decollo)
	if abs(pitch_input) > 0.01:
		# Testa su (pitch negativo) = aereo sale, testa giù (pitch positivo) = aereo scende
		velocity.y += pitch_input * 15.0 * delta
	
	# Limita velocità verticale (range più ampio)
	velocity.y = clamp(velocity.y, -15.0, 15.0)

	move_and_slide()
