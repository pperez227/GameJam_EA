extends CharacterBody2D

# ── Signals ──────────────────────────────────────────────────────
signal player_hit(damage: float)
signal player_attacked(hit: bool)
signal player_dead()
signal attack_launched(attack_type: String)

# QTE Signals
signal qte_started(sequence: Array[String], time_limit: float)
signal qte_progress(current_index: int, sequence_size: int)
signal qte_mistake(multiplier: float)
signal qte_ended()
signal qte_missed()

# ── Constants ────────────────────────────────────────────────────
const SPEED: float = 200.0
const MIN_X: float = 70.0
const MAX_X: float = 730.0
const MIN_Y: float = 290.0
const MAX_Y: float = 430.0

const MAX_HP: float = 100.0
const STAMINA_REGEN: float = 0.12
const SOFT_ATTACK_STAMINA_COST: float = 0.15
const HARD_ATTACK_STAMINA_COST: float = 0.30
const BLOCK_STAMINA_DRAIN: float = 0.25
const ATTACK_COOLDOWN: float = 0.18
const ATTACK_DURATION: float = 0.15
const SOFT_ATTACK_DAMAGE: float = 8.0
const HARD_ATTACK_DAMAGE: float = 18.0
const SPECIAL_DAMAGE: float = 35.0
const SPECIAL_COOLDOWN: float = 0.3
const POWER_PER_HIT: float = 0.25
const HIT_FLASH_DURATION: float = 0.2
const COMBO_TIMEOUT: float = 1.5

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
var qte_keys = ["A", "S", "D", "F", "G", "H", "J", "K", "L"]
var qte_action_names = ["move_left", "move_down", "move_right", "qte_f", "qte_g", "qte_h", "soft_attack", "hard_attack", "special"]

# ── Node references ─────────────────────────────────────────────
@onready var sprite: Sprite2D = $Sprite
@onready var punch_area: Area2D = $PunchArea
@onready var punch_collision: CollisionShape2D = $PunchArea/PunchCollision

var tex_idle: Texture2D
var tex_punch: Texture2D

# ── Ready ────────────────────────────────────────────────────────
func _ready() -> void:
	var img_idle = Image.new()
	if img_idle.load("res://sprites/Player.png") == OK:
		tex_idle = ImageTexture.create_from_image(img_idle)
		
	var img_punch = Image.new()
	if img_punch.load("res://sprites/Player-punch.png") == OK:
		tex_punch = ImageTexture.create_from_image(img_punch)

	if tex_idle != null:
		sprite.texture = tex_idle
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_apply_sprite_scale(tex_idle)
	else:
		_build_placeholder_sprite()

	_build_shadow()
	punch_collision.disabled = true
	position = Vector2(400, 400)

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

# ── Process ──────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if is_dead:
		return
	_handle_movement(delta)
	_handle_stamina(delta)
	_handle_attack_timers(delta)
	_handle_block_broken_timer(delta)
	_handle_combo_timer(delta)
	
	if is_in_qte:
		_handle_qte_timer(delta)
		_handle_qte_input()
	else:
		_handle_input()
	
	_handle_hit_flash(delta)

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
	var dir: Vector2 = Vector2.ZERO
	dir.x = Input.get_axis("move_left", "move_right")
	dir.y = Input.get_axis("move_up", "move_down")
	if dir.length() > 0:
		dir = dir.normalized()
		
	var current_speed = SPEED
	if stamina <= 0.1:
		current_speed *= 0.6
		
	position += dir * current_speed * delta
	position.x = clampf(position.x, MIN_X, MAX_X)
	position.y = clampf(position.y, MIN_Y, MAX_Y)

func _handle_stamina(delta: float) -> void:
	if not is_blocking and not is_block_broken:
		stamina = clampf(stamina + STAMINA_REGEN * delta, 0.0, 1.0)
		if stamina >= 1.0 and hp > 0 and hp < MAX_HP:
			hp = minf(hp + 5.0 * delta, MAX_HP)

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
	if Input.is_action_just_pressed("hard_attack") and stamina >= HARD_ATTACK_STAMINA_COST:
		_start_attack("hard", HARD_ATTACK_STAMINA_COST)
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
	
	# Generate 5 to 8 random inputs
	var seq_length = randi_range(5, 8)
	for i in range(seq_length):
		qte_sequence.append(qte_keys[randi() % qte_keys.size()])
		
	qte_started.emit(qte_sequence, QTE_TIME_LIMIT)

func _finish_qte() -> void:
	is_in_qte = false
	qte_ended.emit()
	is_attacking = true
	is_special = true
	current_attack_type = "special_execute"
	attack_active_timer = ATTACK_DURATION
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
	elif current_attack_type == "hard":
		base_damage = HARD_ATTACK_DAMAGE
		final_multiplier = 1.0 + (min(combo_count, 10) * 0.1)
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
		is_dead = true
		player_dead.emit()

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
