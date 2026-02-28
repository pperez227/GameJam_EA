extends Node

# ── Enemy AI State Machine ───────────────────────────────────────
# Attached as a child of Enemy, controls movement and attack decisions.

enum State { APPROACH, DASH, CIRCLE, ATTACK, SUPER, BLOCK }

# ── Configuration ────────────────────────────────────────────────
const APPROACH_SPEED: float = 1560.0   # 130 * 12
const DASH_SPEED: float = 4480.0      # 320 * 14
const ATTACK_ACCEL: float = 2800.0    # 200 * 14
const SUPER_SPEED: float = 5880.0     # 420 * 14

const ATTACK_COOLDOWN_MIN: float = 0.45
const ATTACK_COOLDOWN_MAX: float = 0.75
const SUPER_WARNING_TIME: float = 0.6
const SUPER_DURATION: float = 1.2
const SUPER_HIT_INTERVAL: float = 0.25

# ── State ────────────────────────────────────────────────────────
var current_state: State = State.APPROACH
var phase_timer: float = 0.5
var attack_cooldown: float = 0.0
var circle_direction: float = 1.0

# QTE State
var qte_slowdown: bool = false
var slowdown_factor: float = 0.0

# Super state
var super_warning_timer: float = 0.0
var super_active_timer: float = 0.0
var super_hit_timer: float = 0.0
var super_pending: bool = false

# ── References ───────────────────────────────────────────────────
var enemy: CharacterBody2D
var player: CharacterBody2D

func _ready() -> void:
	enemy = get_parent() as CharacterBody2D

func set_player_reference(p: CharacterBody2D) -> void:
	player = p

# ── Main loop ────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if enemy == null or enemy.is_dead:
		return
	if player == null or player.is_dead:
		return

	# Handle super warning phase
	if super_pending:
		_handle_super_warning(delta)
		return

	# Handle super active phase
	if current_state == State.SUPER:
		_handle_super_active(delta)
		return

	# Determine effective delta based on QTE slowdown
	var effective_delta = delta * (slowdown_factor if qte_slowdown else 1.0)
	if enemy.stamina <= 0.1:
		effective_delta *= 0.6
		
	# Decrease timers
	phase_timer -= effective_delta
	if attack_cooldown > 0:
		attack_cooldown -= effective_delta

	# Execute current state (using effective_delta)
	match current_state:
		State.APPROACH:
			_state_approach(effective_delta)
		State.DASH:
			_state_dash(effective_delta)
		State.CIRCLE:
			_state_circle(effective_delta)
		State.ATTACK:
			_state_attack(effective_delta)
		State.BLOCK:
			_state_block(effective_delta)

	# Transition check
	if phase_timer <= 0:
		_choose_next_state()

# ── States ───────────────────────────────────────────────────────
func _state_approach(delta: float) -> void:
	var dir: Vector2 = (player.position - enemy.position).normalized()
	enemy.position += dir * APPROACH_SPEED * delta * 0.01
	# Transition to attack if close
	var dist: float = enemy.position.distance_to(player.position)
	if dist < 60.0:
		_enter_state(State.ATTACK, 0.35)

func _state_dash(delta: float) -> void:
	var dir: Vector2 = (player.position - enemy.position).normalized()
	enemy.position += dir * DASH_SPEED * delta * 0.01
	var dist: float = enemy.position.distance_to(player.position)
	if dist < 130.0:
		_enter_state(State.ATTACK, 0.35)

func _state_circle(delta: float) -> void:
	# Move laterally around the player
	var lateral: Vector2 = Vector2(circle_direction * 150.0, 0.0)
	# Also try to maintain vertical distance ~160px above player
	var ideal_y: float = player.position.y - 160.0
	var vert: float = (ideal_y - enemy.position.y) * 2.0
	var move_dir: Vector2 = Vector2(lateral.x, vert).normalized()
	enemy.position += move_dir * 120.0 * delta

func _state_attack(delta: float) -> void:
	# Advance toward player
	var dir: Vector2 = (player.position - enemy.position).normalized()
	enemy.position += dir * ATTACK_ACCEL * delta * 0.01

	# Try to attack
	if attack_cooldown <= 0:
		var dist: float = enemy.position.distance_to(player.position)
		if dist < 200.0:
			enemy.start_attack(false)
			attack_cooldown = randf_range(ATTACK_COOLDOWN_MIN, ATTACK_COOLDOWN_MAX)
			# After attack: 60% chain attack/dash, 40% circle
			if randf() < 0.6:
				if randf() < 0.5:
					_enter_state(State.ATTACK, 0.35)
				else:
					_enter_state(State.DASH, 0.3)
			else:
				circle_direction = 1.0 if randf() < 0.5 else -1.0
				_enter_state(State.CIRCLE, randf_range(0.25, 0.5))

func _state_block(delta: float) -> void:
	enemy.is_blocking = true
	var dir: Vector2 = (enemy.position - player.position).normalized()
	enemy.position += dir * 800.0 * delta * 0.01
	
	if enemy.is_block_broken:
		enemy.is_blocking = false
		_enter_state(State.DASH, 0.3)

# ── Super ────────────────────────────────────────────────────────
func activate_super() -> void:
	super_pending = true
	super_warning_timer = SUPER_WARNING_TIME

func _handle_super_warning(delta: float) -> void:
	super_warning_timer -= delta
	if super_warning_timer <= 0:
		super_pending = false
		super_active_timer = SUPER_DURATION
		super_hit_timer = 0.0
		_enter_state(State.SUPER, SUPER_DURATION)

func _handle_super_active(delta: float) -> void:
	super_active_timer -= delta
	super_hit_timer -= delta

	# Rush toward player
	var dir: Vector2 = (player.position - enemy.position).normalized()
	enemy.position += dir * SUPER_SPEED * delta * 0.01

	# Hit every SUPER_HIT_INTERVAL
	if super_hit_timer <= 0:
		enemy.start_attack(true)
		super_hit_timer = SUPER_HIT_INTERVAL

	# End super
	if super_active_timer <= 0:
		circle_direction = 1.0 if randf() < 0.5 else -1.0
		_enter_state(State.CIRCLE, randf_range(0.25, 0.5))

# ── Transition logic ────────────────────────────────────────────
func _choose_next_state() -> void:
	var dist: float = enemy.position.distance_to(player.position)
	var roll: float = randf()

	if dist > 230.0:
		_enter_state(State.APPROACH, 0.5)
	elif attack_cooldown <= 0 and dist < 200.0 and roll < 0.75:
		_enter_state(State.ATTACK, 0.35)
	elif attack_cooldown > 0 and dist < 150.0 and roll < 0.6:
		enemy.is_blocking = true
		_enter_state(State.BLOCK, randf_range(0.4, 0.8))
	elif roll < 0.4:
		_enter_state(State.DASH, 0.3)
	else:
		circle_direction = 1.0 if randf() < 0.5 else -1.0
		_enter_state(State.CIRCLE, randf_range(0.25, 0.5))

func _enter_state(new_state: State, duration: float) -> void:
	current_state = new_state
	phase_timer = duration
	if new_state != State.BLOCK:
		enemy.is_blocking = false

func set_qte_slowdown(active: bool) -> void:
	qte_slowdown = active
	if active:
		enemy.cancel_attack()

# ── Called when enemy takes damage (from GameManager) ────────────
func on_enemy_damaged() -> void:
	# Stagger → switch to DASH (stay aggressive)
	_enter_state(State.DASH, 0.3)
