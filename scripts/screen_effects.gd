extends CanvasLayer

# ── Screen Effects — shake, flash, game over overlay ────────────

# ── Node references ─────────────────────────────────────────────
var camera: Camera2D
var red_flash: ColorRect
var yellow_flash: ColorRect
var game_over_overlay: ColorRect
var game_over_label: Label
var restart_label: Label

# ── Shake state ─────────────────────────────────────────────────
var shake_intensity: float = 0.0
var shake_timer: float = 0.0
var game_over_active: bool = false

# ── Yellow pulse state ──────────────────────────────────────────
var yellow_pulse_active: bool = false
var yellow_pulse_time: float = 0.0

func _ready() -> void:
	layer = 20

	# Red flash
	red_flash = ColorRect.new()
	red_flash.name = "RedFlash"
	red_flash.size = Vector2(800, 500)
	red_flash.color = Color(1, 0, 0, 0)
	red_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(red_flash)

	# Yellow flash
	yellow_flash = ColorRect.new()
	yellow_flash.name = "YellowFlash"
	yellow_flash.size = Vector2(800, 500)
	yellow_flash.color = Color(1, 0.9, 0.2, 0)
	yellow_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(yellow_flash)

	# Game over overlay
	game_over_overlay = ColorRect.new()
	game_over_overlay.name = "GameOverOverlay"
	game_over_overlay.size = Vector2(800, 500)
	game_over_overlay.color = Color(0, 0, 0, 0)
	game_over_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_over_overlay.visible = false
	add_child(game_over_overlay)

	# Game over label
	game_over_label = Label.new()
	game_over_label.name = "GameOverLabel"
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.position = Vector2(200, 180)
	game_over_label.size = Vector2(400, 60)
	game_over_label.add_theme_font_size_override("font_size", 40)
	game_over_label.visible = false
	add_child(game_over_label)

	# Restart label
	restart_label = Label.new()
	restart_label.name = "RestartLabel"
	restart_label.text = "ENTER para jugar de nuevo"
	restart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_label.position = Vector2(250, 260)
	restart_label.size = Vector2(300, 30)
	restart_label.add_theme_font_size_override("font_size", 14)
	restart_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	restart_label.visible = false
	add_child(restart_label)

func _process(delta: float) -> void:
	_update_shake(delta)
	_update_red_flash(delta)
	_update_yellow_pulse(delta)

# ── Screen shake ────────────────────────────────────────────────
func shake(intensity: float, duration: float) -> void:
	if game_over_active:
		return
	shake_intensity = intensity
	shake_timer = duration

func _update_shake(delta: float) -> void:
	if shake_timer > 0:
		shake_timer -= delta
		if camera:
			camera.offset = Vector2(
				randf_range(-shake_intensity, shake_intensity),
				randf_range(-shake_intensity, shake_intensity)
			)
	elif camera:
		camera.offset = Vector2.ZERO

# Camera reference is set by GameManager since Camera2D must be in the Node2D tree
func set_camera(cam: Camera2D) -> void:
	camera = cam

# ── Red flash ───────────────────────────────────────────────────
func trigger_red_flash() -> void:
	red_flash.color.a = 0.35

func _update_red_flash(delta: float) -> void:
	if red_flash.color.a > 0:
		red_flash.color.a -= delta / 0.2  # fade in 0.2s
		if red_flash.color.a < 0:
			red_flash.color.a = 0

# ── Yellow pulse ────────────────────────────────────────────────
func set_yellow_pulse(active: bool) -> void:
	yellow_pulse_active = active
	if not active:
		yellow_flash.color.a = 0

func _update_yellow_pulse(delta: float) -> void:
	if yellow_pulse_active:
		yellow_pulse_time += delta * 4.0
		yellow_flash.color.a = (sin(yellow_pulse_time) + 1.0) * 0.1
	else:
		yellow_flash.color.a = 0

# ── Game over ───────────────────────────────────────────────────
func show_game_over(won: bool) -> void:
	game_over_active = true
	# Stop shake
	shake_timer = 0.0
	if camera:
		camera.offset = Vector2.ZERO

	game_over_overlay.visible = true
	game_over_overlay.color = Color(0, 0, 0, 0.6)

	game_over_label.visible = true
	if won:
		game_over_label.text = "¡GANASTE!"
		game_over_label.add_theme_color_override("font_color", Color8(80, 240, 80))
	else:
		game_over_label.text = "PERDISTE"
		game_over_label.add_theme_color_override("font_color", Color8(240, 60, 60))

	restart_label.visible = true
