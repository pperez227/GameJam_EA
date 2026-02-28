extends CharacterBody2D

# ── Signals ──────────────────────────────────────────────────────
signal enemy_hit(damage: float)
signal enemy_dead()
signal enemy_knocked_down()
signal enemy_super_activated()
signal enemy_attack_launched(is_super: bool)

# ── Constants ────────────────────────────────────────────────────
const MAX_HP: float = 100.0
const NORMAL_DAMAGE: float = 12.0
const SUPER_DAMAGE: float = 22.0
const POWER_PER_HIT: float = 0.25
const HIT_FLASH_DURATION: float = 0.2
const STAMINA_REGEN: float = 0.12
const BLOCK_STAMINA_DRAIN: float = 0.25
const NORMAL_ATTACK_STAMINA_COST: float = 0.15
const SUPER_ATTACK_STAMINA_COST: float = 0.30

const MIN_Y: float = 230.0
const MAX_Y: float = 420.0
const TOP_LEFT_X: float = 230.0
const TOP_RIGHT_X: float = 570.0
const BOT_LEFT_X: float = 140.0
const BOT_RIGHT_X: float = 660.0

# ── State ────────────────────────────────────────────────────────
var hp: float = MAX_HP
var stamina: float = 1.0
var power: float = 0.0
var hit_timer: float = 0.0
var is_dead: bool = false
var is_attacking: bool = false
var is_super_attacking: bool = false
var attack_active_timer: float = 0.0

var is_blocking: bool = false
var is_block_broken: bool = false
var block_broken_timer: float = 0.0

# ── Node references ─────────────────────────────────────────────
@onready var sprite: Sprite2D = $Sprite
@onready var punch_area: Area2D = $PunchArea
@onready var punch_collision: CollisionShape2D = $PunchArea/PunchCollision

var tex_idle: Texture2D
var tex_punch: Texture2D

func _ready() -> void:
	var img_idle = Image.new()
	if img_idle.load("res://sprites/Enemy.png") == OK:
		tex_idle = ImageTexture.create_from_image(img_idle)
		
	var img_punch = Image.new()
	if img_punch.load("res://sprites/Enemy-punch.png") == OK:
		tex_punch = ImageTexture.create_from_image(img_punch)

	if tex_idle != null:
		sprite.texture = tex_idle
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_apply_sprite_scale(tex_idle)
	else:
		_build_placeholder_sprite()

	_build_shadow()
	punch_collision.disabled = true
	position = Vector2(400, 200)

func _apply_sprite_scale(tex: Texture2D) -> void:
	var s = tex.get_size()
	if s.y > 0:
		var scale_factor = 90.0 / s.y
		sprite.scale = Vector2(scale_factor, scale_factor)

# ── Pixel art enemy sprite (fallback) ───────────
func _build_placeholder_sprite() -> void:
	var w: int = 50
	var h: int = 70
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var skin: Color = Color8(200, 130, 65)
	var skin_d: Color = Color8(170, 105, 50)
	var hair: Color = Color8(24, 24, 24)
	var red: Color = Color8(220, 48, 48)
	var red_h: Color = Color8(255, 90, 90)
	var black: Color = Color8(32, 32, 32)
	var gold: Color = Color8(220, 180, 40)
	var shoe: Color = Color8(200, 200, 200)
	var eye: Color = Color8(240, 240, 240)

	# Hair/bald top
	_fr(img, 17, 1, 16, 5, hair)
	# Head
	_fr(img, 15, 6, 20, 10, skin)
	# Ears
	_fr(img, 13, 8, 2, 5, skin)
	_fr(img, 35, 8, 2, 5, skin)
	# Eyes
	_fr(img, 19, 9, 3, 2, eye)
	_fr(img, 28, 9, 3, 2, eye)
	_fr(img, 20, 9, 1, 2, hair)
	_fr(img, 29, 9, 1, 2, hair)
	# Brow ridge
	_fr(img, 18, 8, 5, 1, skin_d)
	_fr(img, 27, 8, 5, 1, skin_d)
	# Nose
	_fr(img, 23, 10, 4, 3, skin_d)
	# Mouth
	_fr(img, 21, 14, 8, 1, Color8(160, 80, 40))
	# Neck
	_fr(img, 20, 16, 10, 3, skin)
	# Torso (muscular, wider)
	_fr(img, 12, 19, 26, 14, skin)
	# Chest shadows for muscles
	_fr(img, 14, 21, 3, 5, skin_d)
	_fr(img, 33, 21, 3, 5, skin_d)
	_fr(img, 22, 28, 6, 1, skin_d)
	# Arms
	_fr(img, 6, 19, 6, 12, skin)
	_fr(img, 38, 19, 6, 12, skin)
	# Gloves
	_fr(img, 3, 31, 9, 8, red)
	_fr(img, 38, 31, 9, 8, red)
	# Glove highlights
	_fr(img, 4, 31, 3, 2, red_h)
	_fr(img, 39, 31, 3, 2, red_h)
	# Belt/waistband
	_fr(img, 12, 33, 26, 2, gold)
	# Shorts
	_fr(img, 14, 35, 22, 12, black)
	# Shorts stripe
	_fr(img, 14, 35, 22, 1, Color8(60, 60, 60))
	# Legs
	_fr(img, 16, 47, 8, 13, skin)
	_fr(img, 26, 47, 8, 13, skin)
	# Knee shadow
	_fr(img, 17, 55, 6, 1, skin_d)
	_fr(img, 27, 55, 6, 1, skin_d)
	# Shoes
	_fr(img, 15, 60, 10, 7, shoe)
	_fr(img, 25, 60, 10, 7, shoe)
	# Shoe soles
	_fr(img, 15, 66, 10, 1, Color8(60, 60, 60))
	_fr(img, 25, 66, 10, 1, Color8(60, 60, 60))

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _build_shadow() -> void:
	var sw: int = 50
	var sh: int = 14
	var img: Image = Image.create(sw, sh, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = sw / 2.0
	var cy: float = sh / 2.0
	for px: int in range(sw):
		for py: int in range(sh):
			var dx: float = (float(px) - cx) / cx
			var dy: float = (float(py) - cy) / cy
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(px, py, Color(0, 0, 0, 0.2))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var shadow: Sprite2D = Sprite2D.new()
	shadow.name = "ShadowSprite"
	shadow.texture = tex
	shadow.position = Vector2(0, 38)
	shadow.z_index = -1
	add_child(shadow)

# ── Process ──────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if is_dead:
		return
	_handle_attack_timer(delta)
	_handle_stamina(delta)
	_handle_block_broken_timer(delta)
	_handle_hit_flash(delta)
	_clamp_to_ring()

func _handle_stamina(delta: float) -> void:
	if not is_blocking and not is_block_broken:
		stamina = clampf(stamina + STAMINA_REGEN * delta, 0.0, 1.0)
		if stamina >= 1.0 and hp > 0 and hp < MAX_HP:
			hp = minf(hp + 5.0 * delta, MAX_HP)

func _handle_block_broken_timer(delta: float) -> void:
	if is_block_broken:
		block_broken_timer -= delta
		if block_broken_timer <= 0:
			is_block_broken = false

func _handle_attack_timer(delta: float) -> void:
	if attack_active_timer > 0:
		attack_active_timer -= delta
		if attack_active_timer <= 0:
			_end_attack()

func start_attack(is_super: bool = false) -> void:
	if not is_super:
		stamina -= NORMAL_ATTACK_STAMINA_COST
	stamina = maxf(stamina, 0.0)
	is_attacking = true
	is_super_attacking = is_super
	attack_active_timer = 0.15
	punch_collision.disabled = false
	enemy_attack_launched.emit(is_super)
	if tex_punch != null:
		sprite.texture = tex_punch
		_apply_sprite_scale(tex_punch)

func cancel_attack() -> void:
	is_attacking = false
	is_super_attacking = false
	attack_active_timer = 0.0
	punch_collision.set_deferred("disabled", true)
	if tex_idle != null:
		sprite.texture = tex_idle
		_apply_sprite_scale(tex_idle)

func _end_attack() -> void:
	is_attacking = false
	is_super_attacking = false
	punch_collision.disabled = true
	if tex_idle != null:
		sprite.texture = tex_idle
		_apply_sprite_scale(tex_idle)

func get_current_damage() -> float:
	if is_super_attacking:
		return SUPER_DAMAGE
	return NORMAL_DAMAGE

func on_punch_connected() -> void:
	if not is_super_attacking:
		power = clampf(power + POWER_PER_HIT, 0.0, 1.0)
		if power >= 1.0:
			enemy_super_activated.emit()

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
	enemy_hit.emit(final_damage)
	if hp <= 0:
		enemy_knocked_down.emit()

func apply_stagger(direction: Vector2, strength: float = 30.0) -> void:
	position += direction.normalized() * strength
	_clamp_to_ring()

func _clamp_to_ring() -> void:
	position.y = clampf(position.y, MIN_Y, MAX_Y)
	var t: float = (position.y - MIN_Y) / (MAX_Y - MIN_Y)
	var dyn_min_x: float = lerpf(TOP_LEFT_X, BOT_LEFT_X, t)
	var dyn_max_x: float = lerpf(TOP_RIGHT_X, BOT_RIGHT_X, t)
	position.x = clampf(position.x, dyn_min_x, dyn_max_x)

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

func _fr(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for px: int in range(maxi(x, 0), mini(x + w, img.get_width())):
		for py: int in range(maxi(y, 0), mini(y + h, img.get_height())):
			img.set_pixel(px, py, c)

# ── Round reset ─────────────────────────────────────────────────
func reset_for_round() -> void:
	hp = MAX_HP
	stamina = 1.0
	power = 0.0
	is_dead = false
	is_attacking = false
	is_super_attacking = false
	attack_active_timer = 0.0
	hit_timer = 0.0
	is_blocking = false
	is_block_broken = false
	block_broken_timer = 0.0
	punch_collision.disabled = true
	sprite.rotation = 0
	sprite.modulate = Color(1, 1, 1)
	position = Vector2(400, 200)
