extends Node

# ── GameManager — central controller ────────────────────────────
# Connects player/enemy signals, routes damage, updates HUD,
# triggers effects, and handles game over + restart.
#
# IMPORTANT: This node MUST be the LAST child of Main so that
# all sibling nodes have their @onready vars resolved before
# this _ready() runs.

enum GameState { FIGHTING, GAME_OVER }

var state: GameState = GameState.FIGHTING

# ── References (set in _ready via parent tree) ──────────────────
# We store these as Node so we can call custom script methods.
# Godot 4.6 doesn't let us type them as the script class (no class_name).
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

func _ready() -> void:
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
	var punch_file = FileAccess.open("res://punch.mp3", FileAccess.READ)
	if punch_file:
		punch_stream.data = punch_file.get_buffer(punch_file.get_length())
		punch_file.close()
	sfx_punch.stream = punch_stream
	add_child(sfx_punch)

	sfx_deadly = AudioStreamPlayer.new()
	sfx_deadly.name = "SfxDeadly"
	var deadly_stream = AudioStreamMP3.new()
	var deadly_file = FileAccess.open("res://deadly strike.mp3", FileAccess.READ)
	if deadly_file:
		deadly_stream.data = deadly_file.get_buffer(deadly_file.get_length())
		deadly_file.close()
	sfx_deadly.stream = deadly_stream
	add_child(sfx_deadly)

	# Load whoosh sound effects
	sfx_whoosh_soft = _load_sfx("SfxWhooshSoft", "res://whoosh_suave.mp3")
	sfx_whoosh_hard = _load_sfx("SfxWhooshHard", "res://whoosh_fuerte.mp3")
	sfx_whoosh_super = _load_sfx("SfxWhooshSuper", "res://whoosh_super.mp3")

	# Connect signals
	player.player_hit.connect(_on_player_hit)
	player.player_dead.connect(_on_player_dead)
	enemy.enemy_hit.connect(_on_enemy_hit)
	enemy.enemy_dead.connect(_on_enemy_dead)
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

func _process(_delta: float) -> void:
	if state == GameState.FIGHTING:
		_update_hud()
		_check_power_pulse()
	elif state == GameState.GAME_OVER:
		if Input.is_action_just_pressed("restart"):
			get_tree().reload_current_scene()

# ── HUD updates ─────────────────────────────────────────────────
func _update_hud() -> void:
	hud.update_player_hp(player.hp)
	hud.update_player_stamina(player.stamina)
	hud.update_player_power(player.power)
	hud.update_enemy_hp(enemy.hp)
	hud.update_enemy_stamina(enemy.stamina)
	hud.update_enemy_power(enemy.power)

func _check_power_pulse() -> void:
	screen_effects.set_yellow_pulse(player.power >= 1.0)

# ── Hit detection (distance-based, checked every physics frame) ─
func _physics_process(_delta: float) -> void:
	if state != GameState.FIGHTING:
		return
	_check_player_hits_enemy()
	_check_enemy_hits_player()

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
	if dist < 85.0:
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
	if dist < 90.0:
		var dmg: float = enemy.get_current_damage()
		var particle_type: String = "super" if enemy.is_super_attacking else "normal"

		# Apply damage to player
		player.take_damage(dmg)

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
	state = GameState.GAME_OVER
	screen_effects.show_game_over(false)

func _on_enemy_dead() -> void:
	state = GameState.GAME_OVER
	screen_effects.show_game_over(true)

func _on_enemy_super_activated() -> void:
	enemy_ai.activate_super()

func _on_qte_started(sequence: Array[String], time_limit: float) -> void:
	enemy_ai.set_qte_slowdown(true)
	hud.start_qte(sequence, time_limit)

func _on_qte_progress(current_index: int, sequence_size: int) -> void:
	hud.update_qte_progress(current_index)

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
