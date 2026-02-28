extends Node

# ── GameManager — central controller ────────────────────────────
# Connects player/enemy signals, routes damage, updates HUD,
# triggers effects, handles rounds, knockdown, and match flow.
#
# IMPORTANT: This node MUST be the LAST child of Main so that
# all sibling nodes have their @onready vars resolved before
# this _ready() runs.

enum GameState { ROUND_INTRO, FIGHTING, KNOCKDOWN, ROUND_END, MATCH_OVER }

var state: GameState = GameState.ROUND_INTRO

# ── References (set in _ready via parent tree) ──────────────────
var player: Node
var enemy: Node
var enemy_ai: Node
var hud: Node
var screen_effects: Node
var particle_manager: Node
var camera: Camera2D

var sfx_punch: AudioStreamPlayer
var sfx_deadly: AudioStreamPlayer
var sfx_whoosh_soft: AudioStreamPlayer
var sfx_whoosh_hard: AudioStreamPlayer
var sfx_whoosh_super: AudioStreamPlayer

# Combo note audio (one AudioStreamPlayer per letter)
var combo_note_sfx: Dictionary = {}
var qte_sequence_cache: Array[String] = []

# Pause menu
var pause_layer: CanvasLayer
var pause_panel: ColorRect
var is_paused: bool = false

# ── Round state ─────────────────────────────────────────────────
const ROUND_TIME: float = 30.0
const TOTAL_ROUNDS: int = 3
const WINS_NEEDED: int = 2
const KNOCKDOWN_TIME: float = 10.0
const KNOCKDOWN_MASH_NEEDED: int = 15
const KNOCKDOWN_RECOVERY_HP: float = 12.0

var current_round: int = 1
var player_wins: int = 0
var enemy_wins: int = 0
var round_timer: float = ROUND_TIME
var transition_timer: float = 0.0

# Knockdown state
var knockdown_timer: float = 0.0
var knockdown_target: String = ""  # "player" or "enemy"
var knockdown_mash_count: int = 0
var knockdown_last_key: String = ""
var knockdown_decided: bool = false  # enemy auto-decide flag

# Combo counter
var hit_combo_count: int = 0
var hit_combo_timer: float = 0.0
var overlap_timer: float = 0.0

# Victory screen
var victory_layer: CanvasLayer
var victory_panel: ColorRect
var victory_result_label: Label
var victory_score_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Get references from sibling nodes (all already initialized)
	player = get_parent().get_node("Player")
	enemy = get_parent().get_node("Enemy")
	enemy_ai = enemy.get_node("EnemyAI")
	hud = get_parent().get_node("HUD")
	screen_effects = get_parent().get_node("ScreenEffects")
	particle_manager = get_parent().get_node("ParticleManager")
	camera = get_parent().get_node("ShakeCamera") as Camera2D

	# Set up AI player reference
	enemy_ai.set_player_reference(player)

	# Set camera reference for shake
	screen_effects.set_camera(camera)

	# Load hit sound effects
	sfx_punch = AudioStreamPlayer.new()
	sfx_punch.name = "SfxPunch"
	var punch_stream = AudioStreamMP3.new()
	var punch_file = FileAccess.open("res://assets/audio/punch.mp3", FileAccess.READ)
	if punch_file:
		punch_stream.data = punch_file.get_buffer(punch_file.get_length())
		punch_file.close()
	sfx_punch.stream = punch_stream
	add_child(sfx_punch)

	sfx_deadly = AudioStreamPlayer.new()
	sfx_deadly.name = "SfxDeadly"
	var deadly_stream = AudioStreamMP3.new()
	var deadly_file = FileAccess.open("res://assets/audio/deadly strike.mp3", FileAccess.READ)
	if deadly_file:
		deadly_stream.data = deadly_file.get_buffer(deadly_file.get_length())
		deadly_file.close()
	sfx_deadly.stream = deadly_stream
	add_child(sfx_deadly)

	# Load whoosh sound effects
	sfx_whoosh_soft = _load_sfx("SfxWhooshSoft", "res://assets/audio/whoosh_suave.mp3")
	sfx_whoosh_hard = _load_sfx("SfxWhooshHard", "res://assets/audio/whoosh_fuerte.mp3")
	sfx_whoosh_super = _load_sfx("SfxWhooshSuper", "res://assets/audio/whoosh_super.mp3")

	# Pass exact sound lengths to player for dynamic cooldowns
	if player.has_method("set_attack_durations"):
		player.set_attack_durations(
			sfx_whoosh_soft.stream.get_length(),
			sfx_whoosh_hard.stream.get_length(),
			sfx_whoosh_super.stream.get_length()
		)

	# Load combo note audio files (A-K, no L) using native load() in uppercase
	var note_keys = ["A", "S", "D", "F", "G", "H", "J", "K"]
	for key in note_keys:
		var note_player = AudioStreamPlayer.new()
		note_player.name = "SfxNote" + key
		note_player.stream = load("res://assets/audio/" + key + ".wav")
		add_child(note_player)
		combo_note_sfx[key] = note_player

	# Connect signals
	player.player_hit.connect(_on_player_hit)
	player.player_dead.connect(_on_player_dead)
	player.player_knocked_down.connect(_on_player_knocked_down)
	enemy.enemy_hit.connect(_on_enemy_hit)
	enemy.enemy_dead.connect(_on_enemy_dead)
	enemy.enemy_knocked_down.connect(_on_enemy_knocked_down)
	enemy.enemy_super_activated.connect(_on_enemy_super_activated)
	
	# QTE Signals
	player.qte_started.connect(_on_qte_started)
	player.qte_progress.connect(_on_qte_progress)
	player.qte_mistake.connect(_on_qte_mistake)
	player.qte_ended.connect(_on_qte_ended)
	player.qte_missed.connect(_on_qte_missed)

	# Attack launch signals (for whoosh sounds)
	player.attack_launched.connect(_on_player_attack_launched)
	enemy.enemy_attack_launched.connect(_on_enemy_attack_launched)

	# Build UI overlays
	_build_pause_menu()
	_build_victory_screen()

	# Start first round intro
	_start_round_intro()

# ── Main loop ───────────────────────────────────────────────────
func _process(delta: float) -> void:
	if is_paused:
		return

	match state:
		GameState.ROUND_INTRO:
			transition_timer -= delta
			if transition_timer <= 0:
				_start_fighting()
		GameState.FIGHTING:
			_update_hud()
			_check_power_pulse()
			# Round timer
			round_timer -= delta
			hud.update_timer(maxf(round_timer, 0.0))
			if round_timer <= 0:
				_end_round_by_time()
			# Combo timer
			if hit_combo_timer > 0:
				hit_combo_timer -= delta
				if hit_combo_timer <= 0:
					hit_combo_count = 0
					hud.update_combo(0)

		GameState.KNOCKDOWN:
			_process_knockdown(delta)
		GameState.ROUND_END:
			transition_timer -= delta
			if transition_timer <= 0:
				_start_next_round()
		GameState.MATCH_OVER:
			pass  # Victory screen handles input

func _check_power_pulse() -> void:
	screen_effects.set_yellow_pulse(player.power >= 1.0)

# ── Round flow ──────────────────────────────────────────────────
func _start_round_intro() -> void:
	state = GameState.ROUND_INTRO
	transition_timer = 2.0
	player.is_dead = true  # Freeze player during intro
	hud.update_round(current_round)
	hud.update_score(player_wins, enemy_wins)
	hud.show_transition("Round " + str(current_round))

func _start_fighting() -> void:
	state = GameState.FIGHTING
	round_timer = ROUND_TIME
	player.is_dead = false  # Unfreeze
	enemy.is_dead = false
	hud.hide_transition()
	hud.update_timer(round_timer)

func _end_round_by_time() -> void:
	# Whoever has more HP wins
	if player.hp > enemy.hp:
		_award_round("player")
	elif enemy.hp > player.hp:
		_award_round("enemy")
	else:
		_award_round("draw")

func _award_round(winner: String) -> void:
	# Screen shake at end of round
	screen_effects.shake(8.0, 0.5)

	if winner == "player":
		player_wins += 1
	elif winner == "enemy":
		enemy_wins += 1
	# Draw: no one gets a point

	hud.update_score(player_wins, enemy_wins)
	hud.hide_knockdown()

	# Check match over
	if player_wins >= WINS_NEEDED or enemy_wins >= WINS_NEEDED or current_round >= TOTAL_ROUNDS:
		_show_match_result()
	else:
		# Transition to next round
		state = GameState.ROUND_END
		transition_timer = 2.5
		player.is_dead = true  # Freeze during transition
		enemy.is_dead = true
		var winner_text = "Jugador gana el round!" if winner == "player" else ("Enemigo gana el round!" if winner == "enemy" else "Empate!")
		hud.show_transition(winner_text + "\n" + str(player_wins) + " - " + str(enemy_wins))

func _start_next_round() -> void:
	current_round += 1
	player.reset_for_round()
	enemy.reset_for_round()
	enemy_ai.reset_for_round()
	# Reset combo
	hit_combo_count = 0
	hit_combo_timer = 0.0
	hud.update_combo(0)
	hud.hide_transition()
	_start_round_intro()

# ── Knockdown system ────────────────────────────────────────────
func _on_player_knocked_down() -> void:
	if state != GameState.FIGHTING:
		return
	state = GameState.KNOCKDOWN
	knockdown_target = "player"
	knockdown_timer = KNOCKDOWN_TIME
	knockdown_mash_count = 0
	knockdown_last_key = ""
	player.is_dead = true  # Freeze
	player.sprite.rotation = deg_to_rad(90)  # Fallen visual
	enemy.is_dead = true  # Enemy waits

func _on_enemy_knocked_down() -> void:
	if state != GameState.FIGHTING:
		return
	state = GameState.KNOCKDOWN
	knockdown_target = "enemy"
	knockdown_timer = KNOCKDOWN_TIME
	knockdown_decided = false
	enemy.is_dead = true
	enemy.sprite.rotation = deg_to_rad(-90)  # Fallen visual
	player.is_dead = true  # Player waits

func _process_knockdown(delta: float) -> void:
	knockdown_timer -= delta
	var count_display: int = ceili(knockdown_timer)
	
	if knockdown_target == "player":
		hud.show_knockdown(count_display, true)
		# Player mashes A and D to get up
		if Input.is_action_just_pressed("move_left"):
			if knockdown_last_key != "A":
				knockdown_mash_count += 1
				knockdown_last_key = "A"
		elif Input.is_action_just_pressed("move_right"):
			if knockdown_last_key != "D":
				knockdown_mash_count += 1
				knockdown_last_key = "D"
		
		if knockdown_mash_count >= KNOCKDOWN_MASH_NEEDED:
			_recover_from_knockdown("player")
			return
	else:
		hud.show_knockdown(count_display, false)
		# Enemy auto-decides once whether to get up
		if not knockdown_decided and knockdown_timer < 7.0:
			knockdown_decided = true
			var recover_chance: float = 0.30  # Normal
			var diff = GameSettings.difficulty
			if diff == 1:  # Difícil
				recover_chance = 0.50
			elif diff == 2:  # Extremo
				recover_chance = 0.80
			if randf() < recover_chance:
				_recover_from_knockdown("enemy")
				return

	# Time's up — loser doesn't get up
	if knockdown_timer <= 0:
		hud.hide_knockdown()
		_award_round("player" if knockdown_target == "enemy" else "enemy")

func _recover_from_knockdown(who: String) -> void:
	hud.hide_knockdown()
	if who == "player":
		player.is_dead = false
		player.hp = KNOCKDOWN_RECOVERY_HP
		player.sprite.rotation = 0
		enemy.is_dead = false
		# Separate enemy to opposite corner
		if player.position.x < 400:
			enemy.position.x = 620
		else:
			enemy.position.x = 180
		enemy._clamp_to_ring()
	else:
		enemy.is_dead = false
		enemy.hp = KNOCKDOWN_RECOVERY_HP
		enemy.sprite.rotation = 0
		player.is_dead = false
		# Separate player to opposite corner
		if enemy.position.x < 400:
			player.position.x = 620
		else:
			player.position.x = 180
		player._clamp_to_ring()
	state = GameState.FIGHTING

# ── HUD updates ─────────────────────────────────────────────────
func _update_hud() -> void:
	hud.update_player_hp(player.hp)
	hud.update_player_stamina(player.stamina)
	hud.update_player_power(player.power)
	hud.update_enemy_hp(enemy.hp)
	hud.update_enemy_stamina(enemy.stamina)
	hud.update_enemy_power(enemy.power)

# ── Hit detection (distance-based, checked every physics frame) ─
func _physics_process(_delta: float) -> void:
	if state != GameState.FIGHTING:
		return
	_check_player_hits_enemy()
	_check_enemy_hits_player()
	# Enforce minimum separation (85px)
	var sep_dist = player.position.distance_to(enemy.position)
	if sep_dist < 85.0 and sep_dist > 0.1:
		var push = (enemy.position - player.position).normalized()
		enemy.position = player.position + push * 85.0
		enemy._clamp_to_ring()

func _check_player_hits_enemy() -> void:
	if not player.is_attacking:
		return
	if player.punch_collision.disabled:
		return

	# Compute positions
	var player_punch_pos: Vector2 = player.global_position + Vector2(0, -45)
	var enemy_body_pos: Vector2 = enemy.global_position

	# Distance check
	var dist: float = player_punch_pos.distance_to(enemy_body_pos)
	if dist < 55.0:
		if player.current_attack_type == "special_startup":
			player.start_qte()
			return
			
		var dmg: float = player.get_current_damage()
		var particle_type: String = "special" if player.is_special else "normal"

		# Apply damage to enemy
		enemy.take_damage(dmg)
		var stagger_dir: Vector2 = (enemy.position - player.position).normalized()
		enemy.apply_stagger(stagger_dir, 15.0)
		enemy_ai.on_enemy_damaged()

		# Player gains power on connect
		player.on_punch_connected()

		# Combo counter
		hit_combo_count += 1
		hit_combo_timer = 2.0
		hud.update_combo(hit_combo_count)

		# Sound effect
		if player.current_attack_type == "soft":
			_play_sfx_safe(sfx_punch)
		else:
			_play_sfx_safe(sfx_deadly)

		# Effects
		var hit_pos: Vector2 = (player_punch_pos + enemy_body_pos) / 2.0
		particle_manager.spawn_hit_particles(hit_pos, particle_type)
		screen_effects.shake(3.0, 0.15)

		# Disable punch to prevent multi-hit in same attack
		player.punch_collision.disabled = true

func _check_enemy_hits_player() -> void:
	if player.is_in_qte:
		return
	if not enemy.is_attacking:
		return
	if enemy.punch_collision.disabled:
		return

	# Compute positions
	var enemy_punch_pos: Vector2 = enemy.global_position + Vector2(0, 65)
	var player_body_pos: Vector2 = player.global_position

	var dist: float = enemy_punch_pos.distance_to(player_body_pos)
	if dist < 60.0:
		var dmg: float = enemy.get_current_damage()
		var particle_type: String = "super" if enemy.is_super_attacking else "normal"

		# Apply damage to player
		player.take_damage(dmg)

		# Reset combo when player takes damage
		hit_combo_count = 0
		hit_combo_timer = 0.0
		hud.update_combo(0)

		# Enemy gains power on connect
		enemy.on_punch_connected()

		# Sound effect
		if enemy.is_super_attacking:
			_play_sfx_safe(sfx_deadly)
		else:
			_play_sfx_safe(sfx_punch)

		# Effects
		var hit_pos: Vector2 = (enemy_punch_pos + player_body_pos) / 2.0
		particle_manager.spawn_hit_particles(hit_pos, particle_type)
		screen_effects.shake(5.0, 0.2)
		screen_effects.trigger_red_flash()

		# Disable punch to prevent multi-hit in same attack
		enemy.punch_collision.disabled = true

# ── Signal handlers ─────────────────────────────────────────────
func _on_player_hit(_damage: float) -> void:
	pass  # Damage already applied in _check_enemy_hits_player

func _on_enemy_hit(_damage: float) -> void:
	pass  # Damage already applied in _check_player_hits_enemy

func _on_player_dead() -> void:
	pass  # Handled by knockdown system

func _on_enemy_dead() -> void:
	pass  # Handled by knockdown system

func _on_enemy_super_activated() -> void:
	enemy_ai.activate_super()

func _on_qte_started(sequence: Array[String], time_limit: float) -> void:
	enemy_ai.set_qte_slowdown(true)
	qte_sequence_cache = sequence.duplicate()
	hud.start_qte(sequence, time_limit)

func _on_qte_progress(current_index: int, sequence_size: int) -> void:
	hud.update_qte_progress(current_index)
	# Play the note for the key that was just completed
	if current_index > 0 and current_index <= qte_sequence_cache.size():
		var completed_key = qte_sequence_cache[current_index - 1]
		if combo_note_sfx.has(completed_key):
			var note: AudioStreamPlayer = combo_note_sfx[completed_key]
			# Last note plays louder for resolution feel
			if current_index == sequence_size:
				note.volume_db = 6.0
			else:
				note.volume_db = 0.0
			note.stop()
			note.play()

func _on_qte_mistake(multiplier: float) -> void:
	hud.show_qte_mistake()
	screen_effects.shake(2.0, 0.1)

func _on_qte_ended() -> void:
	enemy_ai.set_qte_slowdown(false)
	hud.end_qte()

func _on_qte_missed() -> void:
	hud.show_miss_text()
	screen_effects.shake(2.0, 0.1)

# ── Attack launch handlers (whoosh sounds) ──────────────────────
func _on_player_attack_launched(attack_type: String) -> void:
	match attack_type:
		"soft":
			_play_sfx_safe(sfx_whoosh_soft)
		"hard":
			_play_sfx_safe(sfx_whoosh_hard)
		"super":
			_play_sfx_safe(sfx_whoosh_super)

func _on_enemy_attack_launched(is_super: bool) -> void:
	if is_super:
		_play_sfx_safe(sfx_whoosh_super)
	else:
		_play_sfx_safe(sfx_whoosh_soft)

# ── Audio helpers ───────────────────────────────────────────────
func _play_sfx_safe(sfx: AudioStreamPlayer) -> void:
	if not sfx.playing:
		sfx.play()

func _load_sfx(node_name: String, path: String) -> AudioStreamPlayer:
	var player_node = AudioStreamPlayer.new()
	player_node.name = node_name
	var stream = AudioStreamMP3.new()
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		stream.data = file.get_buffer(file.get_length())
		file.close()
	player_node.stream = stream
	add_child(player_node)
	return player_node

# ── Match result (victory/defeat screen) ────────────────────────
func _build_victory_screen() -> void:
	victory_layer = CanvasLayer.new()
	victory_layer.name = "VictoryLayer"
	victory_layer.layer = 15
	victory_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(victory_layer)

	victory_panel = ColorRect.new()
	victory_panel.name = "VictoryPanel"
	victory_panel.color = Color(0, 0, 0, 0.75)
	victory_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	victory_panel.visible = false
	victory_layer.add_child(victory_panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.offset_left = -200
	vbox.offset_right = 200
	vbox.offset_top = -120
	vbox.offset_bottom = 120
	vbox.add_theme_constant_override("separation", 15)
	victory_panel.add_child(vbox)

	# Result label
	var result_lbl = Label.new()
	result_lbl.name = "ResultLabel"
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_lbl.add_theme_font_size_override("font_size", 42)
	vbox.add_child(result_lbl)
	victory_result_label = result_lbl

	# Score label
	var score_lbl = Label.new()
	score_lbl.name = "ScoreLabel"
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.add_theme_font_size_override("font_size", 24)
	score_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	vbox.add_child(score_lbl)
	victory_score_label = score_lbl

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Rematch button
	var btn_rematch = Button.new()
	btn_rematch.text = "REVANCHA"
	btn_rematch.add_theme_font_size_override("font_size", 24)
	var style_r = StyleBoxFlat.new()
	style_r.bg_color = Color(0.376, 0.267, 0.123, 1)
	btn_rematch.add_theme_stylebox_override("normal", style_r)
	btn_rematch.pressed.connect(_on_rematch_pressed)
	vbox.add_child(btn_rematch)

	# Menu button
	var btn_menu = Button.new()
	btn_menu.text = "MENÚ PRINCIPAL"
	btn_menu.add_theme_font_size_override("font_size", 24)
	var style_m = StyleBoxFlat.new()
	style_m.bg_color = Color(0.376, 0.267, 0.123, 1)
	btn_menu.add_theme_stylebox_override("normal", style_m)
	btn_menu.pressed.connect(_on_victory_menu_pressed)
	vbox.add_child(btn_menu)

func _show_match_result() -> void:
	state = GameState.MATCH_OVER
	player.is_dead = true
	enemy.is_dead = true

	# Screen shake
	screen_effects.shake(10.0, 0.5)

	var won: bool = player_wins > enemy_wins
	victory_panel.visible = true

	if won:
		victory_result_label.text = "¡GANASTE!"
		victory_result_label.add_theme_color_override("font_color", Color8(80, 240, 80))
	else:
		victory_result_label.text = "PERDISTE"
		victory_result_label.add_theme_color_override("font_color", Color8(240, 60, 60))

	victory_score_label.text = str(player_wins) + " - " + str(enemy_wins)

func _on_rematch_pressed() -> void:
	victory_panel.visible = false
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_victory_menu_pressed() -> void:
	victory_panel.visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")

# ── Pause menu ──────────────────────────────────────────────────
func _build_pause_menu() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.name = "PauseLayer"
	pause_layer.layer = 10
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)

	# Dark overlay
	pause_panel = ColorRect.new()
	pause_panel.name = "PausePanel"
	pause_panel.color = Color(0, 0, 0, 0.7)
	pause_panel.anchors_preset = Control.PRESET_FULL_RECT
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.visible = false
	pause_layer.add_child(pause_panel)

	# Centered VBox
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.offset_left = -150
	vbox.offset_right = 150
	vbox.offset_top = -80
	vbox.offset_bottom = 80
	vbox.add_theme_constant_override("separation", 20)
	pause_panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	# Resume button
	var btn_resume = Button.new()
	btn_resume.text = "REANUDAR"
	btn_resume.add_theme_font_size_override("font_size", 24)
	var style_resume = StyleBoxFlat.new()
	style_resume.bg_color = Color(0.376, 0.267, 0.123, 1)
	btn_resume.add_theme_stylebox_override("normal", style_resume)
	btn_resume.pressed.connect(_on_resume_pressed)
	vbox.add_child(btn_resume)

	# Main menu button
	var btn_menu = Button.new()
	btn_menu.text = "MENÚ PRINCIPAL"
	btn_menu.add_theme_font_size_override("font_size", 24)
	var style_menu = StyleBoxFlat.new()
	style_menu.bg_color = Color(0.376, 0.267, 0.123, 1)
	btn_menu.add_theme_stylebox_override("normal", style_menu)
	btn_menu.pressed.connect(_on_menu_pressed)
	vbox.add_child(btn_menu)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if state == GameState.MATCH_OVER:
			return
		if is_paused:
			_resume_game()
		else:
			_pause_game()
		get_viewport().set_input_as_handled()

func _pause_game() -> void:
	is_paused = true
	pause_panel.visible = true
	get_tree().paused = true

func _resume_game() -> void:
	is_paused = false
	pause_panel.visible = false
	get_tree().paused = false

func _on_resume_pressed() -> void:
	_resume_game()

func _on_menu_pressed() -> void:
	_resume_game()
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")
