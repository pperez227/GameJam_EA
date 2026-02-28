extends Node

# ── Enemy AI State Machine ───────────────────────────────────────
# Attached as a child of Enemy, controls movement and attack decisions.

enum State { APPROACH, DASH, CIRCLE, ATTACK, SUPER, BLOCK }

# ── Configuration ────────────────────────────────────────────────
const APPROACH_SPEED: float = 130.0
const DASH_SPEED: float = 260.0
const ATTACK_ADVANCE_SPEED: float = 180.0
const CIRCLE_SPEED: float = 110.0
const BLOCK_RETREAT_SPEED: float = 60.0
const SUPER_SPEED: float = 320.0

const IDEAL_FIGHT_DISTANCE: float = 80.0
const ATTACK_RANGE: float = 110.0
const CLOSE_RANGE: float = 50.0
const FAR_RANGE: float = 170.0

const ATTACK_COOLDOWN_MIN: float = 0.35
const ATTACK_COOLDOWN_MAX: float = 0.65
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

	# Reactive block: if player is attacking nearby, chance to block
	if current_state != State.BLOCK and _should_react_with_block():
		enemy.is_blocking = true
		_enter_state(State.BLOCK, randf_range(0.3, 0.6))

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

# ── Reactive block check ────────────────────────────────────────
func _should_react_with_block() -> bool:
	if enemy.stamina < 0.15 or enemy.is_block_broken:
		return false
	var dist: float = enemy.position.distance_to(player.position)
	if dist > 120.0:
		return false
	if player.is_attacking and randf() < 0.35:
		return true
	return false

# ── States ───────────────────────────────────────────────────────
func _state_approach(delta: float) -> void:
	var dir: Vector2 = (player.position - enemy.position).normalized()
	enemy.position += dir * APPROACH_SPEED * delta
	enemy._clamp_to_ring()
	# Transition to attack if close
	var dist: float = enemy.position.distance_to(player.position)
	if dist < ATTACK_RANGE:
		_enter_state(State.ATTACK, randf_range(0.5, 0.8))

func _state_dash(delta: float) -> void:
	var dir: Vector2 = (player.position - enemy.position).normalized()
	enemy.position += dir * DASH_SPEED * delta
	enemy._clamp_to_ring()
	var dist: float = enemy.position.distance_to(player.position)
	if dist < ATTACK_RANGE:
		_enter_state(State.ATTACK, randf_range(0.5, 0.8))

func _state_circle(delta: float) -> void:
	var dist: float = enemy.position.distance_to(player.position)
	
	# Lateral movement around the player
	var to_player: Vector2 = (player.position - enemy.position)
	var lateral: Vector2 = Vector2(-to_player.y, to_player.x).normalized() * circle_direction
	
	# Also maintain ideal fight distance
	var distance_correction: float = 0.0
	if dist > IDEAL_FIGHT_DISTANCE + 30:
		distance_correction = 1.0  # Move closer
	elif dist < IDEAL_FIGHT_DISTANCE - 20:
		distance_correction = -0.5  # Move away slightly
	
	var approach_dir: Vector2 = to_player.normalized() * distance_correction
	var move_dir: Vector2 = (lateral + approach_dir).normalized()
	enemy.position += move_dir * CIRCLE_SPEED * delta
	enemy._clamp_to_ring()
	
	# If in attack range and cooldown ready, transition to attack
	if dist < ATTACK_RANGE and attack_cooldown <= 0:
		_enter_state(State.ATTACK, randf_range(0.4, 0.7))

func _state_attack(delta: float) -> void:
	var dist: float = enemy.position.distance_to(player.position)
	
	# Advance toward player if not in range
	if dist > CLOSE_RANGE:
		var dir: Vector2 = (player.position - enemy.position).normalized()
		enemy.position += dir * ATTACK_ADVANCE_SPEED * delta
		enemy._clamp_to_ring()

	# Try to attack
	if attack_cooldown <= 0 and enemy.stamina >= enemy.NORMAL_ATTACK_STAMINA_COST:
		if dist < ATTACK_RANGE:
			# 30% chance of a super-powered hit if stamina allows
			var use_heavy: bool = randf() < 0.30 and enemy.stamina >= enemy.SUPER_ATTACK_STAMINA_COST
			enemy.start_attack(use_heavy)
			attack_cooldown = randf_range(ATTACK_COOLDOWN_MIN, ATTACK_COOLDOWN_MAX)
			
			# After attack: decide next move
			var roll: float = randf()
			if roll < 0.45:
				# Chain attack — stay aggressive
				_enter_state(State.ATTACK, randf_range(0.3, 0.5))
			elif roll < 0.65:
				# Quick dash to reposition
				_enter_state(State.DASH, randf_range(0.2, 0.4))
			elif roll < 0.85:
				# Circle to find opening
				circle_direction = 1.0 if randf() < 0.5 else -1.0
				_enter_state(State.CIRCLE, randf_range(0.5, 0.8))
			else:
				# Brief block
				if enemy.stamina > 0.2:
					enemy.is_blocking = true
					_enter_state(State.BLOCK, randf_range(0.2, 0.4))
				else:
					circle_direction = 1.0 if randf() < 0.5 else -1.0
					_enter_state(State.CIRCLE, randf_range(0.4, 0.7))

func _state_block(delta: float) -> void:
	enemy.is_blocking = true
	# Slight retreat while blocking
	var dir: Vector2 = (enemy.position - player.position).normalized()
	enemy.position += dir * BLOCK_RETREAT_SPEED * delta
	enemy._clamp_to_ring()
	
	if enemy.is_block_broken:
		enemy.is_blocking = false
		# When block breaks, react with a dash away
		circle_direction = 1.0 if randf() < 0.5 else -1.0
		_enter_state(State.CIRCLE, randf_range(0.3, 0.5))

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
	if super_hit_timer <= 0 and enemy.stamina >= enemy.SUPER_ATTACK_STAMINA_COST:
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
	
	# Adaptiveness: aggression depends on HP balance
	var enemy_hp_ratio: float = enemy.hp / enemy.MAX_HP
	var player_hp_ratio: float = player.hp / player.MAX_HP if player.has_method("get_current_damage") else 1.0
	# Access player HP directly
	if "hp" in player and "MAX_HP" in player:
		player_hp_ratio = player.hp / player.MAX_HP
	
	# Aggression modifier: more aggressive when enemy HP is low or player HP is low
	var aggression: float = 0.5
	if enemy_hp_ratio < 0.3:
		aggression = 0.8  # Desperate — go all in
	elif player_hp_ratio < 0.3:
		aggression = 0.75  # Smell blood — press advantage
	elif enemy_hp_ratio > 0.7:
		aggression = 0.45  # Comfortable — mix it up
	
	# Far away → approach or dash
	if dist > FAR_RANGE:
		if roll < 0.6:
			_enter_state(State.APPROACH, randf_range(0.6, 1.2))
		else:
			_enter_state(State.DASH, randf_range(0.3, 0.5))
	# In fighting range → mostly attack
	elif dist < ATTACK_RANGE:
		if attack_cooldown <= 0 and roll < aggression:
			_enter_state(State.ATTACK, randf_range(0.5, 0.8))
		elif roll < aggression + 0.15:
			circle_direction = 1.0 if randf() < 0.5 else -1.0
			_enter_state(State.CIRCLE, randf_range(0.5, 0.8))
		else:
			if enemy.stamina > 0.2:
				enemy.is_blocking = true
				_enter_state(State.BLOCK, randf_range(0.3, 0.5))
			else:
				circle_direction = 1.0 if randf() < 0.5 else -1.0
				_enter_state(State.CIRCLE, randf_range(0.4, 0.6))
	# Mid range
	else:
		if roll < 0.4:
			_enter_state(State.APPROACH, randf_range(0.4, 0.8))
		elif roll < 0.65:
			_enter_state(State.DASH, randf_range(0.2, 0.4))
		else:
			circle_direction = 1.0 if randf() < 0.5 else -1.0
			_enter_state(State.CIRCLE, randf_range(0.5, 0.9))

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
	# Varied reactions instead of always dashing
	var roll: float = randf()
	var dist: float = enemy.position.distance_to(player.position)
	
	if roll < 0.35:
		# Counter-attack: dash back in aggressively
		_enter_state(State.DASH, randf_range(0.2, 0.4))
	elif roll < 0.60:
		# Block: cover up after taking a hit
		if enemy.stamina > 0.15 and not enemy.is_block_broken:
			enemy.is_blocking = true
			_enter_state(State.BLOCK, randf_range(0.3, 0.5))
		else:
			circle_direction = 1.0 if randf() < 0.5 else -1.0
			_enter_state(State.CIRCLE, randf_range(0.4, 0.6))
	else:
		# Evade: circle away to reset
		circle_direction = 1.0 if randf() < 0.5 else -1.0
		_enter_state(State.CIRCLE, randf_range(0.4, 0.7))
