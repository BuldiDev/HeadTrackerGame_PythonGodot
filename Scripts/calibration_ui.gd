extends Control

@export var head_tracker: Node

# Riferimenti ai nodi UI
@onready var instruction_label: Label = $VBoxContainer/InstructionLabel
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressContainer/ProgressBar
@onready var progress_container: VBoxContainer = $VBoxContainer/ProgressContainer

func _ready():
	if not head_tracker:
		head_tracker = get_node_or_null("/root/Main/GodotClient")
		if not head_tracker:
			head_tracker = get_node_or_null("/root/GodotClient")
	
	if head_tracker:
		# Connetti ai segnali di calibrazione
		head_tracker.calibration_started.connect(_on_calibration_started)
		head_tracker.calibration_center_set.connect(_on_center_set)
		head_tracker.calibration_completed.connect(_on_calibration_completed)
	
	# Nascondi il progresso all'inizio
	if progress_container:
		progress_container.visible = false
	
	update_ui()

func _process(_delta):
	update_ui()
	
	# Gestisci SPAZIO per avanzare nella calibrazione
	if Input.is_action_just_pressed("ui_accept") and head_tracker:
		if head_tracker.calibration_state == head_tracker.CalibrationState.IDLE:
			head_tracker.start_calibration()
		elif head_tracker.calibration_state == head_tracker.CalibrationState.WAITING_CENTER:
			head_tracker.set_center()
		elif head_tracker.calibration_state == head_tracker.CalibrationState.CALIBRATING_RANGE:
			head_tracker.complete_calibration()
	
	# Gestisci ESC per chiudere
	if Input.is_action_just_pressed("ui_cancel"):
		if head_tracker:
			head_tracker.close_calibration_ui()

func update_ui():
	if not head_tracker:
		if instruction_label:
			instruction_label.text = "ERRORE: Head tracker non trovato"
		return
	
	if not instruction_label:
		return
	
	match head_tracker.calibration_state:
		head_tracker.CalibrationState.IDLE:
			instruction_label.text = "CALIBRAZIONE HEAD TRACKING\n\nPremi SPAZIO per iniziare"
			if status_label:
				status_label.text = "In attesa..."
			if progress_container:
				progress_container.visible = false
		
		head_tracker.CalibrationState.WAITING_CENTER:
			instruction_label.text = "FASE 1: CENTRO\n\nPosiziona la testa al CENTRO\nGuarda dritto davanti a te\n\nPremi SPAZIO quando sei pronto"
			if status_label:
				status_label.text = "Pitch: %.1f | Roll: %.1f" % [head_tracker.pitch, head_tracker.roll]
			if progress_container:
				progress_container.visible = false
		
		head_tracker.CalibrationState.CALIBRATING_RANGE:
			instruction_label.text = "FASE 2: RANGE DI MOVIMENTO\n\nMuovi la testa Su/Giù e Inclina Sinistra/Destra\nFai i movimenti più ampi possibili\n\nPremi SPAZIO quando hai finito"
			if status_label:
				var pitch_offset = head_tracker.pitch - head_tracker.pitch_center
				var roll_offset = head_tracker.roll - head_tracker.roll_center
				status_label.text = "Pitch: [%.1f, %.1f] | Roll: [%.1f, %.1f]" % [head_tracker.pitch_up_max, head_tracker.pitch_down_max, head_tracker.roll_left_max, head_tracker.roll_right_max]
			if progress_container:
				progress_container.visible = true
			if progress_bar:
				var pitch_up_dist = abs(head_tracker.pitch_up_max)
				var pitch_down_dist = abs(head_tracker.pitch_down_max)
				var roll_left_dist = abs(head_tracker.roll_left_max)
				var roll_right_dist = abs(head_tracker.roll_right_max)
				var total_range = min(pitch_up_dist, pitch_down_dist) + min(roll_left_dist, roll_right_dist)
				progress_bar.value = total_range
		
		head_tracker.CalibrationState.CALIBRATED:
			instruction_label.text = "✓ CALIBRAZIONE COMPLETATA!\n\nRange: ±%.1f gradi\n\nPuoi iniziare a giocare!"
			if head_tracker.pitch_range > 0:
				instruction_label.text = "✓ CALIBRAZIONE COMPLETATA!\n\nPitch: ±%.1f | Roll: ±%.1f\n\nPuoi iniziare a giocare!" % [head_tracker.pitch_range, head_tracker.roll_range]
			if status_label:
				var pitch_norm = head_tracker.get_normalized_pitch()
				var roll_norm = head_tracker.get_normalized_roll()
				status_label.text = "Pitch: %.2f | Roll: %.2f" % [pitch_norm, roll_norm]
			if progress_container:
				progress_container.visible = false

func _on_calibration_started():
	print("UI: Calibrazione iniziata")

func _on_center_set():
	print("UI: Centro impostato")

func _on_calibration_completed(max_range: float):
	print("UI: Calibrazione completata con range: ", max_range)
	# Chiudi automaticamente la UI dopo 3 secondi
	await get_tree().create_timer(3.0).timeout
	if head_tracker:
		head_tracker.close_calibration_ui()
