extends Node

# ── Enemy AI State Machine ───────────────────────────────────────
# Attached as a child of Enemy, controls movement and attack decisions.

enum State { APPROACH, DASH, CIRCLE, ATTACK, SUPER, BLOCK }

# ── Configuration ────────────────────────────────────────────────
const APPROACH_SPEED: float = 140.0
const DASH_SPEED: float = 280.0
const ATTACK_ADVANCE_SPEED: float = 200.0
const CIRCLE_SPEED: float = 120.0
const BLOCK_RETREAT_SPEED: float = 50.0
const SUPER_SPEED: float = 320.0

const IDEAL_FIGHT_DISTANCE: float = 90.0
const ATTACK_RANGE: float = 105.0
const CLOSE_RANGE: float = 70.0
const FAR_RANGE: float = 160.0

const COMBO_COOLDOWN: float = 0.18        # Between hits in a combo

# Difficulty-tuned parameters (set in _ready)
var between_combo_cooldown: float = 0.5
var max_combo_hits: int = 3
var diff_block_chance: float = 0.4
var base_aggression: float = 0.55

const SUPER_WARNING_TIME: float = 0.3
const SUPER_DURATION: float = 1.2
const SUPER_HIT_INTERVAL: float = 0.25

# ── State ────────────────────────────────────────────────────────
var current_state: State = State.APPROACH
var phase_timer: float = 0.5
var attack_cooldown: float = 0.0
var circle_direction: float = 1.0

# Combo tracking
var combo_hits_remaining: int = 0
var combo_hit_timer: float = 0.0

# QTE State
var qte_slowdown: bool = false
var slowdown_factor: float = 0.0

# Super state
var super_warning_timer: float = 0.0
var super_active_timer: float = 0.0
var super_hit_timer: float = 0.0
var super_pending: bool = false

# Reactive block tracking (edge detection)
var _player_was_attacking: bool = false

# ── References ───────────────────────────────────────────────────
var enemy: CharacterBody2D
var player: CharacterBody2D

func _ready() -> void:
	enemy = get_parent() as CharacterBody2D
	# Apply difficulty settings
	var diff: int = GameSettings.difficulty
	if diff == 0:  # Normal
		between_combo_cooldown = 0.5
		max_combo_hits = 3
		diff_block_chance = 0.4
		base_aggression = 0.55
	elif diff == 2:  # Extremo
		between_combo_cooldown = 0.25
		max_combo_hits = 4
		diff_block_chance = 0.7
		base_aggression = 0.85
	else:  # Difícil
		between_combo_cooldown = 0.35
		max_combo_hits = 3
		diff_block_chance = 0.55
		base_aggression = 0.70

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

	# ── Proactive super check ──
	# If power is full, activate super immediately
	if enemy.power >= 1.0 and not super_pending and current_state != State.SUPER:
		activate_super()
		return

	# Determine effective delta based on QTE slowdown
	var effective_delta = delta * (slowdown_factor if qte_slowdown else 1.0)
	if enemy.stamina <= 0.1:
		effective_delta *= 0.6

	# Decrease timers
	phase_timer -= effective_delta
	if attack_cooldown > 0:
		attack_cooldown -= effective_delta
	if combo_hit_timer > 0:
		combo_hit_timer -= effective_delta

	# ── Reactive block (edge-triggered, not per-frame random) ──
	# Only react the frame the player STARTS attacking, not every frame
	var player_attacking_now: bool = player.is_attacking
	if player_attacking_now and not _player_was_attacking:
		# Player just started an attack — react?
		if current_state != State.BLOCK and _should_react_with_block():
			enemy.is_blocking = true
			_enter_state(State.BLOCK, randf_range(0.3, 0.6))
	_player_was_attacking = player_attacking_now

	# Execute current state
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

	# Separation force — never overlap the player
	var sep_dist: float = enemy.position.distance_to(player.position)
	if sep_dist < 60.0 and sep_dist > 0:
		var push_dir: Vector2 = (enemy.position - player.position).normalized()
		enemy.position += push_dir * (60.0 - sep_dist)
		enemy._clamp_to_ring()

	# Transition check
	if phase_timer <= 0:
		_choose_next_state()

# ── Reactive block check ────────────────────────────────────────
func _should_react_with_block() -> bool:
	if enemy.stamina < 0.15 or enemy.is_block_broken:
		return false
	var dist: float = enemy.position.distance_to(player.position)
	if dist > 120.0:
		return false
	# Higher chance when HP is high (cautious), lower when desperate
	var block_chance: float = diff_block_chance if (enemy.hp / enemy.MAX_HP) > 0.4 else diff_block_chance * 0.4
	return randf() < block_chance

# ── States ───────────────────────────────────────────────────────
func _state_approach(delta: float) -> void:
	var dir: Vector2 = (player.position - enemy.position).normalized()
	enemy.position += dir * APPROACH_SPEED * delta
	enemy._clamp_to_ring()
	var dist: float = enemy.position.distance_to(player.position)
	if dist < ATTACK_RANGE:
		_start_combo()

func _state_dash(delta: float) -> void:
	var dir: Vector2 = (player.position - enemy.position).normalized()
	enemy.position += dir * DASH_SPEED * delta
	enemy._clamp_to_ring()
	var dist: float = enemy.position.distance_to(player.position)
	if dist < ATTACK_RANGE:
		_start_combo()

func _state_circle(delta: float) -> void:
	var dist: float = enemy.position.distance_to(player.position)
	var to_player: Vector2 = player.position - enemy.position

	# Lateral movement perpendicular to player direction
	var lateral: Vector2 = Vector2(-to_player.y, to_player.x).normalized() * circle_direction

	# Maintain ideal fight distance while circling
	var distance_correction: float = 0.0
	if dist > IDEAL_FIGHT_DISTANCE + 25.0:
		distance_correction = 0.8
	elif dist < IDEAL_FIGHT_DISTANCE - 15.0:
		distance_correction = -0.4

	var approach_dir: Vector2 = to_player.normalized() * distance_correction
	var move_dir: Vector2 = (lateral + approach_dir).normalized()
	enemy.position += move_dir * CIRCLE_SPEED * delta
	enemy._clamp_to_ring()

	# If close and cooldown ready, start a combo
	if dist < ATTACK_RANGE and attack_cooldown <= 0:
		_start_combo()

func _state_attack(delta: float) -> void:
	var dist: float = enemy.position.distance_to(player.position)

	# Advance toward player if not in close range
	if dist > CLOSE_RANGE:
		var dir: Vector2 = (player.position - enemy.position).normalized()
		enemy.position += dir * ATTACK_ADVANCE_SPEED * delta
		enemy._clamp_to_ring()

	# Execute combo hits
	if combo_hits_remaining > 0 and combo_hit_timer <= 0:
		if dist < ATTACK_RANGE and enemy.stamina >= enemy.NORMAL_ATTACK_STAMINA_COST:
			# Mix light and heavy hits: last hit of combo is heavy 40% of time
			var use_heavy: bool = false
			if combo_hits_remaining == 1 and randf() < 0.40:
				use_heavy = enemy.stamina >= enemy.SUPER_ATTACK_STAMINA_COST
			enemy.start_attack(use_heavy)
			combo_hits_remaining -= 1
			combo_hit_timer = COMBO_COOLDOWN
		elif dist >= ATTACK_RANGE:
			# Too far — abort combo, dash closer
			combo_hits_remaining = 0
			_enter_state(State.DASH, randf_range(0.2, 0.3))
			return

	# Combo finished — decide next move
	if combo_hits_remaining <= 0 and combo_hit_timer <= 0:
		attack_cooldown = between_combo_cooldown
		_after_combo()

func _state_block(delta: float) -> void:
	enemy.is_blocking = true
	var dir: Vector2 = (enemy.position - player.position).normalized()
	enemy.position += dir * BLOCK_RETREAT_SPEED * delta
	enemy._clamp_to_ring()

	if enemy.is_block_broken:
		enemy.is_blocking = false
		circle_direction = 1.0 if randf() < 0.5 else -1.0
		_enter_state(State.CIRCLE, randf_range(0.3, 0.5))

# ── Combo system ────────────────────────────────────────────────
func _start_combo() -> void:
	combo_hits_remaining = randi_range(1, max_combo_hits)
	combo_hit_timer = 0.0  # First hit is immediate
	_enter_state(State.ATTACK, 2.0)  # Long timer — combo controls exit

func _after_combo() -> void:
	var roll: float = randf()
	var dist: float = enemy.position.distance_to(player.position)

	if roll < 0.35:
		# Stay aggressive — circle briefly then combo again
		circle_direction = 1.0 if randf() < 0.5 else -1.0
		_enter_state(State.CIRCLE, randf_range(0.3, 0.5))
	elif roll < 0.55:
		# Quick dash to cut angle
		_enter_state(State.DASH, randf_range(0.2, 0.3))
	elif roll < 0.75:
		# Block briefly (read the opponent)
		if enemy.stamina > 0.2 and not enemy.is_block_broken:
			enemy.is_blocking = true
			_enter_state(State.BLOCK, randf_range(0.2, 0.4))
		else:
			circle_direction = 1.0 if randf() < 0.5 else -1.0
			_enter_state(State.CIRCLE, randf_range(0.4, 0.6))
	else:
		# Back off slightly
		circle_direction = 1.0 if randf() < 0.5 else -1.0
		_enter_state(State.CIRCLE, randf_range(0.5, 0.8))

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
	enemy.position += dir * SUPER_SPEED * delta
	enemy._clamp_to_ring()

	# Hit every SUPER_HIT_INTERVAL
	if super_hit_timer <= 0:
		enemy.start_attack(true)
		super_hit_timer = SUPER_HIT_INTERVAL

	# End super
	if super_active_timer <= 0:
		circle_direction = 1.0 if randf() < 0.5 else -1.0
		_enter_state(State.CIRCLE, randf_range(0.5, 0.8))

# ── Transition logic (adaptive) ─────────────────────────────────
func _choose_next_state() -> void:
	var dist: float = enemy.position.distance_to(player.position)
	var roll: float = randf()

	# Aggression based on HP balance
	var enemy_hp_ratio: float = enemy.hp / enemy.MAX_HP
	var player_hp_ratio: float = 1.0
	if "hp" in player and "MAX_HP" in player:
		player_hp_ratio = player.hp / player.MAX_HP

	var aggression: float = base_aggression
	if enemy_hp_ratio < 0.3:
		aggression = minf(base_aggression + 0.30, 0.95)  # Desperate — go all in
	elif player_hp_ratio < 0.3:
		aggression = minf(base_aggression + 0.25, 0.90)  # Smell blood
	elif enemy_hp_ratio > 0.7:
		aggression = base_aggression - 0.05  # Comfortable

	# Far away → close the distance
	if dist > FAR_RANGE:
		if roll < 0.55:
			_enter_state(State.APPROACH, randf_range(0.5, 1.0))
		else:
			_enter_state(State.DASH, randf_range(0.3, 0.5))
	# In attack range → mostly attack
	elif dist < ATTACK_RANGE:
		if attack_cooldown <= 0 and roll < aggression:
			_start_combo()
		elif roll < aggression + 0.15:
			circle_direction = 1.0 if randf() < 0.5 else -1.0
			_enter_state(State.CIRCLE, randf_range(0.4, 0.7))
		else:
			if enemy.stamina > 0.2 and not enemy.is_block_broken:
				enemy.is_blocking = true
				_enter_state(State.BLOCK, randf_range(0.3, 0.5))
			else:
				circle_direction = 1.0 if randf() < 0.5 else -1.0
				_enter_state(State.CIRCLE, randf_range(0.3, 0.5))
	# Mid range → close in
	else:
		if roll < 0.45:
			_enter_state(State.APPROACH, randf_range(0.3, 0.6))
		elif roll < 0.70:
			_enter_state(State.DASH, randf_range(0.2, 0.4))
		else:
			circle_direction = 1.0 if randf() < 0.5 else -1.0
			_enter_state(State.CIRCLE, randf_range(0.4, 0.7))

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
	# Interrupt current combo
	combo_hits_remaining = 0

	var roll: float = randf()
	if roll < 0.30:
		# Counter-attack immediately
		_start_combo()
	elif roll < 0.55:
		# Block and recover
		if enemy.stamina > 0.15 and not enemy.is_block_broken:
			enemy.is_blocking = true
			_enter_state(State.BLOCK, randf_range(0.3, 0.5))
		else:
			circle_direction = 1.0 if randf() < 0.5 else -1.0
			_enter_state(State.CIRCLE, randf_range(0.3, 0.5))
	else:
		# Evade laterally
		circle_direction = 1.0 if randf() < 0.5 else -1.0
		_enter_state(State.CIRCLE, randf_range(0.3, 0.6))
