extends CharacterBody2D

# ── Signals ──────────────────────────────────────────────────────
signal player_hit(damage: float)
signal player_attacked(hit: bool)
signal player_dead()
signal player_knocked_down()
signal attack_launched(attack_type: String)
signal tongue_hit()

# QTE Signals
signal qte_started(sequence: Array[String], time_limit: float)
signal qte_progress(current_index: int, sequence_size: int)
signal qte_mistake(multiplier: float)
signal qte_ended()
signal qte_missed()

# ── Constants ────────────────────────────────────────────────────
const SPEED: float = 200.0
const MIN_Y: float = 230.0
const MAX_Y: float = 420.0
const TOP_LEFT_X: float = 230.0
const TOP_RIGHT_X: float = 570.0
const BOT_LEFT_X: float = 140.0
const BOT_RIGHT_X: float = 660.0	

const MAX_HP: float = 100.0
const STAMINA_REGEN: float = 0.42
const SOFT_ATTACK_STAMINA_COST: float = 0.15
const BLOCK_STAMINA_DRAIN: float = 0.25
const ATTACK_COOLDOWN: float = 0.18

# Tongue grab constants
const TONGUE_COOLDOWN: float = 3.0
const TONGUE_RANGE: float = 130.0
const TONGUE_EXTEND_TIME: float = 0.15
const ATTACK_DURATION: float = 0.15
const SOFT_ATTACK_DAMAGE: float = 8.0
const SPECIAL_DAMAGE: float = 35.0
const SPECIAL_COOLDOWN: float = 0.3
const POWER_PER_HIT: float = 0.25
const HIT_FLASH_DURATION: float = 0.2
const COMBO_TIMEOUT: float = 1.5
const DASH_SPEED: float = 600.0
const DASH_DURATION: float = 0.12
const DASH_COOLDOWN: float = 0.8

const QTE_TIME_LIMIT: float = 3.5
const QTE_PENALTY_PER_MISTAKE: float = 0.15
const QTE_TIMEOUT_PENALTY: float = 0.10

# Dynamic cooldowns based on whoosh audio length
var attack_durations = {
	"soft": 0.18,
	"hard": 0.30,
	"super": 0.30
}

# ── State ────────────────────────────────────────────────────────
var hp: float = MAX_HP
var stamina: float = 1.0
var power: float = 0.0
var attack_cooldown_timer: float = 0.0
var attack_active_timer: float = 0.0
var is_attacking: bool = false
var is_special: bool = false
var current_attack_type: String = ""
var hit_timer: float = 0.0
var is_dead: bool = false
var attack_direction: Vector2 = Vector2(0, -1)  # Direction of last attack

# Dash state
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO

# Tongue grab state
var tongue_cooldown_timer: float = 0.0
var is_tongue_active: bool = false
var tongue_timer: float = 0.0
var tongue_retract_timer: float = 0.0
var tongue_line: Line2D

var is_blocking: bool = false
var is_block_broken: bool = false
var block_broken_timer: float = 0.0
var combo_count: int = 0
var combo_timer: float = 0.0

var is_in_qte: bool = false
var qte_sequence: Array[String] = []
var qte_current_index: int = 0
var qte_timer: float = 0.0
var qte_damage_multiplier: float = 1.0

# QTE Key Mapping — home row ASDFGHJKL
const QTE_ACTIONS = {
	"move_left": "A", "move_down": "S", "move_right": "D",
	"qte_f": "F", "qte_g": "G", "qte_h": "H",
	"soft_attack": "J", "hard_attack": "K", "special": "L"
}
var qte_keys = ["A", "S", "D", "F", "G", "H", "J", "K"]
var qte_action_names = ["move_left", "move_down", "move_right", "qte_f", "qte_g", "qte_h", "soft_attack", "hard_attack"]

# ── Node references ─────────────────────────────────────────────
@onready var sprite: Sprite2D = $Sprite
@onready var punch_area: Area2D = $PunchArea
@onready var punch_collision: CollisionShape2D = $PunchArea/PunchCollision

var tex_idle: Texture2D
var tex_punch: Texture2D
var tex_walk_frames: Array[Texture2D] = []
var walk_frame_index: int = 0
var walk_frame_timer: float = 0.0
const WALK_FRAME_SPEED: float = 0.1  # seconds per frame
var is_moving_visual: bool = false

# ── Ready ────────────────────────────────────────────────────────
func _ready() -> void:
	var img_idle = Image.new()
	if img_idle.load("res://assets/images/rana_quieto.png") == OK:
		tex_idle = ImageTexture.create_from_image(img_idle)
		
	var img_punch = Image.new()
	if img_punch.load("res://sprites/Player-punch.png") == OK:
		tex_punch = ImageTexture.create_from_image(img_punch)

	# Load walk animation frames
	for i in range(100):
		var path = "res://assets/walk_frames/player/frame_" + str(i) + ".png"
		if not FileAccess.file_exists(path):
			break
		var frame_img = Image.new()
		if frame_img.load(path) == OK:
			tex_walk_frames.append(ImageTexture.create_from_image(frame_img))

	if tex_idle != null:
		sprite.texture = tex_idle
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_apply_sprite_scale(tex_idle)
	else:
		_build_placeholder_sprite()

	_build_shadow()
	punch_collision.disabled = true
	position = Vector2(400, 400)
	z_index = 1

func _apply_sprite_scale(tex: Texture2D) -> void:
	var s = tex.get_size()
	if s.y > 0:
		var scale_factor = 90.0 / s.y
		sprite.scale = Vector2(scale_factor, scale_factor)

# ── Pixel art player sprite (Little Mac style, from behind) ─────
func _build_placeholder_sprite() -> void:
	var w: int = 30
	var h: int = 50
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var skin: Color = Color8(232, 184, 120)
	var hair: Color = Color8(42, 26, 10)
	var green: Color = Color8(60, 180, 48)
	var green_d: Color = Color8(40, 140, 32)
	var red: Color = Color8(220, 48, 48)
	var black: Color = Color8(24, 24, 24)
	var white: Color = Color8(230, 230, 230)

	# Hair
	_fr(img, 10, 1, 10, 4, hair)
	# Head
	_fr(img, 9, 5, 12, 6, skin)
	# Neck
	_fr(img, 12, 11, 6, 2, skin)
	# Tank top (green with white stripe)
	_fr(img, 8, 13, 14, 11, green)
	_fr(img, 14, 13, 2, 11, white)
	# Shoulder outline
	_fr(img, 7, 13, 1, 2, green_d)
	_fr(img, 22, 13, 1, 2, green_d)
	# Arms (skin)
	_fr(img, 4, 13, 3, 9, skin)
	_fr(img, 23, 13, 3, 9, skin)
	# Gloves (red)
	_fr(img, 2, 22, 6, 6, red)
	_fr(img, 22, 22, 6, 6, red)
	# Glove highlights
	_fr(img, 3, 22, 2, 1, Color8(255, 100, 100))
	_fr(img, 23, 22, 2, 1, Color8(255, 100, 100))
	# Belt
	_fr(img, 8, 24, 14, 2, black)
	# Shorts
	_fr(img, 9, 26, 12, 7, green)
	_fr(img, 9, 26, 12, 1, green_d)
	# Left leg
	_fr(img, 10, 33, 5, 10, skin)
	# Right leg
	_fr(img, 16, 33, 5, 10, skin)
	# Shoes
	_fr(img, 9, 43, 6, 5, black)
	_fr(img, 15, 43, 6, 5, black)
	# Shoe soles
	_fr(img, 9, 47, 6, 1, Color8(80, 80, 80))
	_fr(img, 15, 47, 6, 1, Color8(80, 80, 80))

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _build_shadow() -> void:
	var sw: int = 36
	var sh: int = 10
	var img: Image = Image.create(sw, sh, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = sw / 2.0
	var cy: float = sh / 2.0
	for px: int in range(sw):
		for py: int in range(sh):
			var dx: float = (float(px) - cx) / cx
			var dy: float = (float(py) - cy) / cy
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(px, py, Color(0, 0, 0, 0.25))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var shadow: Sprite2D = Sprite2D.new()
	shadow.name = "ShadowSprite"
	shadow.texture = tex
	shadow.position = Vector2(0, 26)
	shadow.z_index = -1
	add_child(shadow)

	# Tongue visual (pink line)
	tongue_line = Line2D.new()
	tongue_line.name = "TongueLine"
	tongue_line.width = 4.0
	tongue_line.default_color = Color8(255, 100, 150)
	tongue_line.z_index = 5
	tongue_line.visible = false
	tongue_line.add_point(Vector2.ZERO)
	tongue_line.add_point(Vector2.ZERO)
	add_child(tongue_line)

# ── Tongue grab ─────────────────────────────────────────────────
func _start_tongue() -> void:
	is_tongue_active = true
	tongue_timer = TONGUE_EXTEND_TIME
	tongue_cooldown_timer = TONGUE_COOLDOWN
	tongue_line.visible = true
	tongue_line.set_point_position(0, Vector2.ZERO)
	tongue_line.set_point_position(1, Vector2.ZERO)

func _handle_tongue(delta: float) -> void:
	if tongue_cooldown_timer > 0 and not is_tongue_active:
		tongue_cooldown_timer -= delta
	# Handle retract visual (tongue stays visible briefly after hit)
	if tongue_retract_timer > 0:
		tongue_retract_timer -= delta
		if tongue_retract_timer <= 0:
			tongue_line.visible = false
			tongue_line.default_color = Color8(255, 100, 150)  # Reset to pink
			tongue_line.width = 4.0
	if not is_tongue_active:
		return
	tongue_timer -= delta
	# Animate tongue extending toward attack_direction
	var progress: float = 1.0 - clampf(tongue_timer / TONGUE_EXTEND_TIME, 0.0, 1.0)
	var end_pos: Vector2 = attack_direction * TONGUE_RANGE * progress
	tongue_line.set_point_position(1, end_pos)
	if tongue_timer <= 0:
		tongue_hit.emit()
		is_tongue_active = false
		# Hide immediately on miss (game_manager will call show_tongue_hit on connect)
		tongue_line.visible = false

func show_tongue_hit() -> void:
	# Keep tongue visible briefly with bright green to show successful grab
	tongue_line.visible = true
	tongue_line.default_color = Color8(100, 255, 100)
	tongue_line.width = 6.0
	tongue_retract_timer = 0.3

# ── Process ──────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if is_dead:
		return
	_handle_dash_timers(delta)
	_handle_movement(delta)
	_handle_stamina(delta)
	_handle_attack_timers(delta)
	_handle_block_broken_timer(delta)
	_handle_combo_timer(delta)
	_handle_tongue(delta)
	
	if is_in_qte:
		_handle_qte_timer(delta)
		_handle_qte_input()
	else:
		_handle_input()
	
	_handle_hit_flash(delta)
	_update_walk_visual(delta)

func _handle_qte_timer(delta: float) -> void:
	qte_timer -= delta
	if qte_timer <= 0:
		# Timer ran out
		qte_damage_multiplier -= QTE_TIMEOUT_PENALTY
		_finish_qte()

func _handle_qte_input() -> void:
	for action in qte_action_names:
		if Input.is_action_just_pressed(action):
			var expected_key = qte_sequence[qte_current_index]
			var pressed_key = QTE_ACTIONS[action]
			
			if pressed_key == expected_key:
				qte_current_index += 1
				qte_progress.emit(qte_current_index, qte_sequence.size())
				if qte_current_index >= qte_sequence.size():
					_finish_qte()
					return
			else:
				qte_damage_multiplier = maxf(qte_damage_multiplier - QTE_PENALTY_PER_MISTAKE, 0.1)
				qte_mistake.emit(qte_damage_multiplier)
			
			# Exit loop after processing first pressed key this frame
			return

func _handle_block_broken_timer(delta: float) -> void:
	if is_block_broken:
		block_broken_timer -= delta
		if block_broken_timer <= 0:
			is_block_broken = false

func _handle_combo_timer(delta: float) -> void:
	if combo_count > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo_count = 0

func _handle_movement(delta: float) -> void:
	if is_blocking or is_block_broken or is_in_qte:
		return
	# During dash, move in dash_direction only
	if is_dashing:
		position += dash_direction * DASH_SPEED * delta
		position.y = clampf(position.y, MIN_Y, MAX_Y)
		var t: float = (position.y - MIN_Y) / (MAX_Y - MIN_Y)
		var dyn_min_x: float = lerpf(TOP_LEFT_X, BOT_LEFT_X, t)
		var dyn_max_x: float = lerpf(TOP_RIGHT_X, BOT_RIGHT_X, t)
		position.x = clampf(position.x, dyn_min_x, dyn_max_x)
		return
	var dir: Vector2 = Vector2.ZERO
	dir.x = Input.get_axis("move_left", "move_right")
	dir.y = Input.get_axis("move_up", "move_down")
	if dir.length() > 0:
		dir = dir.normalized()
		attack_direction = dir  # Track for directional hitbox
		
	var current_speed = SPEED
	if stamina <= 0.1:
		current_speed *= 0.6
		
	position += dir * current_speed * delta
	position.y = clampf(position.y, MIN_Y, MAX_Y)
	var t: float = (position.y - MIN_Y) / (MAX_Y - MIN_Y)
	var dyn_min_x: float = lerpf(TOP_LEFT_X, BOT_LEFT_X, t)
	var dyn_max_x: float = lerpf(TOP_RIGHT_X, BOT_RIGHT_X, t)
	position.x = clampf(position.x, dyn_min_x, dyn_max_x)

func _clamp_to_ring() -> void:
	position.y = clampf(position.y, MIN_Y, MAX_Y)
	var t: float = (position.y - MIN_Y) / (MAX_Y - MIN_Y)
	var dyn_min_x: float = lerpf(TOP_LEFT_X, BOT_LEFT_X, t)
	var dyn_max_x: float = lerpf(TOP_RIGHT_X, BOT_RIGHT_X, t)
	position.x = clampf(position.x, dyn_min_x, dyn_max_x)

func _handle_stamina(delta: float) -> void:
	if not is_blocking and not is_block_broken:
		stamina = clampf(stamina + STAMINA_REGEN * delta, 0.0, 1.0)
		if stamina >= 1.0 and hp > 0 and hp < MAX_HP:
			hp = minf(hp + 10.0 * delta, MAX_HP)

func _handle_attack_timers(delta: float) -> void:
	if is_in_qte:
		return
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	if attack_active_timer > 0:
		attack_active_timer -= delta
		if attack_active_timer <= 0:
			_end_attack()

func _handle_input() -> void:
	if is_block_broken:
		return
	
	is_blocking = Input.is_action_pressed("block")
	if is_blocking:
		return
		
	if attack_cooldown_timer > 0:
		return
	if Input.is_action_just_pressed("special") and power >= 1.0:
		_attempt_special()
		return
	if Input.is_action_just_pressed("soft_attack") and stamina >= SOFT_ATTACK_STAMINA_COST:
		_start_attack("soft", SOFT_ATTACK_STAMINA_COST)
		return
	if Input.is_action_just_pressed("hard_attack") and tongue_cooldown_timer <= 0 and not is_tongue_active:
		_start_tongue()
		return
	# Dash with Shift
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0 and not is_dashing:
		var dash_dir: Vector2 = Vector2.ZERO
		dash_dir.x = Input.get_axis("move_left", "move_right")
		dash_dir.y = Input.get_axis("move_up", "move_down")
		if dash_dir.length() < 0.1:
			dash_dir = Vector2(-1, 0)  # Default: dash left
		else:
			dash_dir = dash_dir.normalized()
		is_dashing = true
		dash_direction = dash_dir
		dash_timer = DASH_DURATION
		dash_cooldown_timer = DASH_COOLDOWN
		return

func set_attack_durations(soft: float, hard: float, super_atk: float) -> void:
	attack_durations["soft"] = soft
	attack_durations["hard"] = hard
	attack_durations["super"] = super_atk

func _start_attack(type: String, cost: float) -> void:
	stamina -= cost
	is_attacking = true
	is_special = false
	current_attack_type = type
	attack_cooldown_timer = attack_durations[type]
	attack_active_timer = attack_durations[type]
	punch_collision.disabled = false
	attack_launched.emit(type)
	if tex_punch != null:
		sprite.texture = tex_punch
		_apply_sprite_scale(tex_punch)

func _attempt_special() -> void:
	power = 0.0 # Consume power
	is_attacking = true
	is_special = true
	current_attack_type = "special_startup"
	attack_cooldown_timer = attack_durations["super"]
	attack_active_timer = attack_durations["super"]
	punch_collision.disabled = false
	attack_launched.emit("super")
	if tex_punch != null:
		sprite.texture = tex_punch
		_apply_sprite_scale(tex_punch)

func start_qte() -> void:
	is_in_qte = true
	qte_damage_multiplier = 1.0
	qte_current_index = 0
	qte_timer = QTE_TIME_LIMIT
	qte_sequence.clear()
	punch_collision.disabled = true
	
	# Generate 4 to 6 random inputs
	var seq_length = randi_range(4, 6)
	for i in range(seq_length):
		qte_sequence.append(qte_keys[randi() % qte_keys.size()])
		
	qte_started.emit(qte_sequence, QTE_TIME_LIMIT)

func _finish_qte() -> void:
	is_in_qte = false
	qte_ended.emit()
	is_attacking = true
	is_special = true
	current_attack_type = "special_execute"
	attack_active_timer = 0.4  # Longer window so super connects
	punch_collision.disabled = false

func _end_attack() -> void:
	if current_attack_type == "special_startup":
		qte_missed.emit()
		
	is_attacking = false
	is_special = false
	current_attack_type = ""
	punch_collision.disabled = true
	if tex_idle != null:
		sprite.texture = tex_idle
		_apply_sprite_scale(tex_idle)

func on_punch_connected() -> void:
	if current_attack_type != "special_execute" and current_attack_type != "special_startup":
		power = clampf(power + POWER_PER_HIT, 0.0, 1.0)
	combo_count += 1
	combo_timer = COMBO_TIMEOUT
	player_attacked.emit(true)

func get_current_damage() -> float:
	var base_damage = 0.0
	var final_multiplier = 1.0
	
	if current_attack_type == "special_execute":
		base_damage = SPECIAL_DAMAGE
		final_multiplier = qte_damage_multiplier
	elif current_attack_type == "special_startup":
		return 0.0 # Does no damage, just triggers QTE

	else:
		base_damage = SOFT_ATTACK_DAMAGE
		final_multiplier = 1.0 + (min(combo_count, 10) * 0.1)
	
	return base_damage * final_multiplier

func take_damage(damage: float) -> void:
	if is_dead:
		return
		
	var final_damage = damage
	if is_block_broken:
		final_damage *= 1.5
	elif is_blocking:
		stamina -= BLOCK_STAMINA_DRAIN
		if stamina <= 0:
			stamina = 0
			is_block_broken = true
			is_blocking = false
			block_broken_timer = 2.0
		final_damage *= 0.5
		
	hp -= final_damage
	hp = maxf(hp, 0.0)
	hit_timer = HIT_FLASH_DURATION
	player_hit.emit(final_damage)
	if hp <= 0:
		player_knocked_down.emit()

func _update_walk_visual(delta: float) -> void:
	if is_attacking or is_in_qte:
		return  # Attack/QTE sprite takes priority
	var dir_x: float = Input.get_axis("move_left", "move_right")
	var dir_y: float = Input.get_axis("move_up", "move_down")
	var moving: bool = abs(dir_x) > 0.1 or abs(dir_y) > 0.1
	
	if moving and tex_walk_frames.size() > 0:
		if not is_moving_visual:
			is_moving_visual = true
			walk_frame_index = 0
			walk_frame_timer = 0.0
		walk_frame_timer += delta
		if walk_frame_timer >= WALK_FRAME_SPEED:
			walk_frame_timer -= WALK_FRAME_SPEED
			walk_frame_index = (walk_frame_index + 1) % tex_walk_frames.size()
		sprite.texture = tex_walk_frames[walk_frame_index]
		_apply_sprite_scale(tex_walk_frames[walk_frame_index])
	else:
		if is_moving_visual:
			is_moving_visual = false
		if tex_idle != null:
			sprite.texture = tex_idle
			_apply_sprite_scale(tex_idle)

func _handle_hit_flash(delta: float) -> void:
	var base_color = Color(1, 1, 1)
	if is_block_broken:
		base_color = Color(1, 0.3, 0.3)
	elif is_blocking:
		base_color = Color(0.6, 0.6, 1.0)
		
	if hit_timer > 0:
		hit_timer -= delta
		if fmod(hit_timer, 0.1) > 0.05:
			sprite.modulate = Color(10, 10, 10)
		else:
			sprite.modulate = base_color
	else:
		sprite.modulate = base_color

# ── Helper ──────────────────────────────────────────────────────
func _fr(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for px: int in range(maxi(x, 0), mini(x + w, img.get_width())):
		for py: int in range(maxi(y, 0), mini(y + h, img.get_height())):
			img.set_pixel(px, py, c)

# ── Dash timers ─────────────────────────────────────────────────
func _handle_dash_timers(delta: float) -> void:
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false

# ── Round reset ─────────────────────────────────────────────────
func reset_for_round() -> void:
	hp = MAX_HP
	stamina = 1.0
	power = 0.0
	is_dead = false
	is_attacking = false
	is_special = false
	current_attack_type = ""
	attack_cooldown_timer = 0.0
	attack_active_timer = 0.0
	hit_timer = 0.0
	is_blocking = false
	is_block_broken = false
	block_broken_timer = 0.0
	combo_count = 0
	combo_timer = 0.0
	is_in_qte = false
	punch_collision.disabled = true
	sprite.rotation = 0
	sprite.modulate = Color(1, 1, 1)
	is_dashing = false
	dash_timer = 0.0
	dash_cooldown_timer = 0.0
	tongue_cooldown_timer = 0.0
	is_tongue_active = false
	tongue_timer = 0.0
	tongue_retract_timer = 0.0
	if tongue_line:
		tongue_line.visible = false
		tongue_line.default_color = Color8(255, 100, 150)
		tongue_line.width = 4.0
	attack_direction = Vector2(0, -1)
	position = Vector2(400, 400)
