extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const GROUND_ACCELERATION = 8.0  # Accelerazione a terra
const GROUND_FRICTION = 5.0      # Attrito a terra

# Riferimento al client di head tracking
var head_tracker: Node = null

# Raycast delle ruote
@onready var raycast_left: RayCast3D = $RaycastRuotaSinistraFront
@onready var raycast_right: RayCast3D = $RaycastRuotaDestraFront
@onready var raycast_back: RayCast3D = $RaycastRuotaDietro

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
	
	# Controlla se le ruote toccano il terreno (con controllo null-safe)
	var on_ground = false
	var num_wheels_grounded = 0
	
	if raycast_left and raycast_left.is_colliding():
		num_wheels_grounded += 1
	if raycast_right and raycast_right.is_colliding():
		num_wheels_grounded += 1
	if raycast_back and raycast_back.is_colliding():
		num_wheels_grounded += 1
	
	# Considera "a terra" solo se almeno 2 ruote toccano E velocità verticale bassa
	on_ground = num_wheels_grounded >= 2 and velocity.y > -2.0
	
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
			print("Aereo - Pitch: %.2f | Roll: %.2f | Velocity.y: %.2f | A terra: %d ruote | L:%s R:%s B:%s" % [pitch_input, roll_input, velocity.y, num_wheels_grounded, raycast_left != null and raycast_left.is_colliding(), raycast_right != null and raycast_right.is_colliding(), raycast_back != null and raycast_back.is_colliding()])
	else:
		# Fallback ai controlli tastiera
		pitch_input = Input.get_axis("ui_down", "ui_up")  # Su/Giù per altitudine
		roll_input = Input.get_axis("ui_left", "ui_right")  # Sinistra/Destra per sterzo
	
	# Accelerazione con SPAZIO
	var is_accelerating = Input.is_physical_key_pressed(KEY_SPACE)
	
	if is_accelerating:
		if on_ground:
			# A terra: movimento in avanti limitato, solo su piano orizzontale
			var forward = -global_transform.basis.z
			forward.y = 0  # Mantieni movimento orizzontale
			forward = forward.normalized()
			velocity.x = move_toward(velocity.x, forward.x * SPEED, GROUND_ACCELERATION * delta)
			velocity.z = move_toward(velocity.z, forward.z * SPEED, GROUND_ACCELERATION * delta)
		else:
			# In volo: mantieni velocità costante nella direzione orizzontale dell'aereo
			var forward = -global_transform.basis.z
			var forward_horizontal = Vector3(forward.x, 0, forward.z).normalized()
			# Mantieni sempre SPEED come velocità orizzontale minima
			if forward_horizontal.length() > 0.1:
				velocity.x = forward_horizontal.x * SPEED
				velocity.z = forward_horizontal.z * SPEED
	else:
		if on_ground:
			# Attrito maggiore a terra
			velocity.x = move_toward(velocity.x, 0, GROUND_FRICTION * delta)
			velocity.z = move_toward(velocity.z, 0, GROUND_FRICTION * delta)
		else:
			# Decelera gradualmente in aria
			velocity.x = move_toward(velocity.x, 0, SPEED * delta * 3.0)
			velocity.z = move_toward(velocity.z, 0, SPEED * delta * 3.0)
	
	# Rotazione aereo basata sui controlli
	# Pitch: ruota aereo su asse X (beccheggio)
	if abs(pitch_input) > 0.01:
		if on_ground:
			# A terra: solo pitch positivo (alzare muso) con limite
			if pitch_input > 0:  # Solo se vuoi alzare il muso
				rotate_object_local(Vector3.RIGHT, pitch_input * 2.0 * delta)
		else:
			# In volo: pitch libero
			rotate_object_local(Vector3.RIGHT, pitch_input * 1.5 * delta)
	
	# Roll e sterzo
	if not on_ground:
		# In volo: usa il roll (rollio)
		if abs(roll_input) > 0.01:
			rotate_object_local(Vector3.FORWARD, -roll_input * 1.2 * delta)
	else:
		# A terra: usa yaw (sterzo orizzontale)
		if abs(roll_input) > 0.01 and velocity.length() > 0.5:
			rotate_y(roll_input * 2.0 * delta)
		
		# Stabilizza gradualmente roll e limita pitch a terra
		var current_rotation = rotation
		current_rotation.z = lerp_angle(current_rotation.z, 0.0, 3.0 * delta)
		# Limita pitch: non può andare sotto 0 (nel terreno), max circa 45° (0.785 rad)
		current_rotation.x = clamp(current_rotation.x, 0.0, 0.8)
		rotation = current_rotation
	
	# Calcola la direzione "su" dell'aereo per il movimento
	var plane_up = global_transform.basis.y
	var plane_forward = -global_transform.basis.z
	
	# Applica gravità sempre
	velocity.y -= 9.8 * delta
	
	# Il pitch dell'aereo influenza il movimento verticale
	if is_accelerating and not on_ground:
		# Quando acceleri in volo, l'aereo si muove nella direzione in cui punta
		# Usa la componente verticale del vettore forward per salire/scendere
		velocity.y += plane_forward.y * SPEED * 3.0 * delta
	
	# A terra: impedisci caduta attraverso il terreno
	if on_ground and velocity.y < 0:
		velocity.y = 0
	
	# Limita velocità verticale
	velocity.y = clamp(velocity.y, -15.0, 15.0)

	move_and_slide()
