extends CharacterBody2D

# ── Signals ──────────────────────────────────────────────────────
signal player_hit(damage: float)
signal player_attacked(hit: bool)
signal player_dead()

# ── Constants ────────────────────────────────────────────────────
const SPEED: float = 200.0
const MIN_X: float = 70.0
const MAX_X: float = 730.0
const MIN_Y: float = 290.0
const MAX_Y: float = 430.0

const MAX_HP: float = 100.0
const STAMINA_REGEN: float = 0.12
const PUNCH_STAMINA_COST: float = 0.22
const PUNCH_COOLDOWN: float = 0.18
const PUNCH_DURATION: float = 0.15
const PUNCH_DAMAGE: float = 10.0
const SPECIAL_DAMAGE: float = 40.0
const SPECIAL_COOLDOWN: float = 0.3
const POWER_PER_HIT: float = 0.25
const HIT_FLASH_DURATION: float = 0.2

# ── State ────────────────────────────────────────────────────────
var hp: float = MAX_HP
var stamina: float = 1.0
var power: float = 0.0
var attack_cooldown_timer: float = 0.0
var attack_active_timer: float = 0.0
var is_attacking: bool = false
var is_special: bool = false
var hit_timer: float = 0.0
var is_dead: bool = false

# ── Node references ─────────────────────────────────────────────
@onready var sprite: Sprite2D = $Sprite
@onready var punch_area: Area2D = $PunchArea
@onready var punch_collision: CollisionShape2D = $PunchArea/PunchCollision

# ── Ready ────────────────────────────────────────────────────────
func _ready() -> void:
	_build_placeholder_sprite()
	_build_shadow()
	punch_collision.disabled = true
	position = Vector2(400, 400)

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
	_handle_input()
	_handle_hit_flash(delta)

func _handle_movement(delta: float) -> void:
	var dir: Vector2 = Vector2.ZERO
	dir.x = Input.get_axis("move_left", "move_right")
	dir.y = Input.get_axis("move_up", "move_down")
	if dir.length() > 0:
		dir = dir.normalized()
	position += dir * SPEED * delta
	position.x = clampf(position.x, MIN_X, MAX_X)
	position.y = clampf(position.y, MIN_Y, MAX_Y)

func _handle_stamina(delta: float) -> void:
	stamina = clampf(stamina + STAMINA_REGEN * delta, 0.0, 1.0)

func _handle_attack_timers(delta: float) -> void:
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	if attack_active_timer > 0:
		attack_active_timer -= delta
		if attack_active_timer <= 0:
			_end_attack()

func _handle_input() -> void:
	if attack_cooldown_timer > 0:
		return
	if Input.is_action_just_pressed("special") and power >= 1.0:
		_start_special()
		return
	if Input.is_action_just_pressed("punch") and stamina >= PUNCH_STAMINA_COST:
		_start_punch()

func _start_punch() -> void:
	stamina -= PUNCH_STAMINA_COST
	is_attacking = true
	is_special = false
	attack_cooldown_timer = PUNCH_COOLDOWN
	attack_active_timer = PUNCH_DURATION
	punch_collision.disabled = false

func _start_special() -> void:
	is_attacking = true
	is_special = true
	power = 0.0
	attack_cooldown_timer = SPECIAL_COOLDOWN
	attack_active_timer = PUNCH_DURATION
	punch_collision.disabled = false

func _end_attack() -> void:
	is_attacking = false
	is_special = false
	punch_collision.disabled = true

func on_punch_connected() -> void:
	if not is_special:
		power = clampf(power + POWER_PER_HIT, 0.0, 1.0)
	player_attacked.emit(true)

func get_current_damage() -> float:
	if is_special:
		return SPECIAL_DAMAGE
	return PUNCH_DAMAGE

func take_damage(damage: float) -> void:
	if is_dead:
		return
	hp -= damage
	hp = maxf(hp, 0.0)
	hit_timer = HIT_FLASH_DURATION
	player_hit.emit(damage)
	if hp <= 0:
		is_dead = true
		player_dead.emit()

func _handle_hit_flash(delta: float) -> void:
	if hit_timer > 0:
		hit_timer -= delta
		if fmod(hit_timer, 0.1) > 0.05:
			sprite.modulate = Color(10, 10, 10)
		else:
			sprite.modulate = Color(1, 1, 1)
	else:
		sprite.modulate = Color(1, 1, 1)

# ── Helper ──────────────────────────────────────────────────────
func _fr(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for px: int in range(maxi(x, 0), mini(x + w, img.get_width())):
		for py: int in range(maxi(y, 0), mini(y + h, img.get_height())):
			img.set_pixel(px, py, c)
