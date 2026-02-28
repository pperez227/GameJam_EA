extends Node2D

# ── Particle Manager — spawns one-shot hit particles ────────────

func spawn_hit_particles(pos: Vector2, type: String) -> void:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 12
	particles.lifetime = 0.4
	particles.speed_scale = 2.0

	# Direction: spread in all directions
	particles.direction = Vector2(0, -1)
	particles.spread = 180.0
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 180.0
	particles.gravity = Vector2(0, 200)

	# Scale
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0

	# Color by type
	match type:
		"normal":
			particles.color = Color8(255, 160, 40)  # orange
		"special":
			particles.color = Color8(255, 240, 60)  # yellow
		"super":
			particles.color = Color8(180, 60, 220)  # purple
		_:
			particles.color = Color8(255, 160, 40)

	add_child(particles)

	# Auto-remove after particles finish
	var cleanup_timer: Timer = Timer.new()
	cleanup_timer.wait_time = 1.0
	cleanup_timer.one_shot = true
	cleanup_timer.timeout.connect(func() -> void: particles.queue_free(); cleanup_timer.queue_free())
	add_child(cleanup_timer)
	cleanup_timer.start()
