extends CanvasLayer

# ── HUD — Punch-Out NES style retro bars ────────────────────────

const BAR_WIDTH: float = 160.0
const BAR_HEIGHT: float = 16.0
const BAR_SPACING: float = 6.0
const BORDER: float = 2.0

var enemy_hp_bar: ColorRect
var enemy_hp_fill: ColorRect
var enemy_power_bar: ColorRect
var enemy_power_fill: ColorRect

var player_hp_bar: ColorRect
var player_hp_fill: ColorRect
var player_stm_bar: ColorRect
var player_stm_fill: ColorRect
var player_pwr_bar: ColorRect
var player_pwr_fill: ColorRect

var hint_label: Label

func _ready() -> void:
	layer = 10
	_build_enemy_hud()
	_build_player_hud()
	_build_hint()

# ── Enemy HUD (top-left) ────────────────────────────────────────
func _build_enemy_hud() -> void:
	var container: Control = Control.new()
	container.name = "EnemyHUD"
	add_child(container)

	var lbl: Label = Label.new()
	lbl.text = "ENEMIGO"
	lbl.position = Vector2(12, 6)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color8(255, 80, 80))
	container.add_child(lbl)

	# HP bar with border
	var hp_y: float = 24
	_add_border(container, 12, hp_y, BAR_WIDTH, BAR_HEIGHT)
	enemy_hp_bar = _make_bar(12, hp_y, BAR_WIDTH, BAR_HEIGHT, Color8(30, 30, 30))
	container.add_child(enemy_hp_bar)
	enemy_hp_fill = _make_bar(12, hp_y, BAR_WIDTH, BAR_HEIGHT, Color8(60, 200, 60))
	container.add_child(enemy_hp_fill)

	var hp_lbl: Label = Label.new()
	hp_lbl.text = "HP"
	hp_lbl.position = Vector2(14, hp_y - 1)
	hp_lbl.add_theme_font_size_override("font_size", 11)
	hp_lbl.add_theme_color_override("font_color", Color.WHITE)
	container.add_child(hp_lbl)

	# Power bar (purple) with border
	var pwr_y: float = hp_y + BAR_HEIGHT + BAR_SPACING
	_add_border(container, 12, pwr_y, BAR_WIDTH, 12)
	enemy_power_bar = _make_bar(12, pwr_y, BAR_WIDTH, 12, Color8(30, 30, 30))
	container.add_child(enemy_power_bar)
	enemy_power_fill = _make_bar(12, pwr_y, BAR_WIDTH, 12, Color8(160, 50, 210))
	container.add_child(enemy_power_fill)

	var pwr_lbl: Label = Label.new()
	pwr_lbl.text = "SUPER"
	pwr_lbl.position = Vector2(14, pwr_y - 2)
	pwr_lbl.add_theme_font_size_override("font_size", 9)
	pwr_lbl.add_theme_color_override("font_color", Color8(200, 150, 255))
	container.add_child(pwr_lbl)

# ── Player HUD (top-right) ──────────────────────────────────────
func _build_player_hud() -> void:
	var container: Control = Control.new()
	container.name = "PlayerHUD"
	add_child(container)

	var base_x: float = 800.0 - BAR_WIDTH - 12.0

	var title_lbl: Label = Label.new()
	title_lbl.text = "JUGADOR"
	title_lbl.position = Vector2(base_x, 6)
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color8(80, 200, 80))
	container.add_child(title_lbl)

	# HP bar
	var hp_y: float = 24
	_add_border(container, base_x, hp_y, BAR_WIDTH, BAR_HEIGHT)
	player_hp_bar = _make_bar(base_x, hp_y, BAR_WIDTH, BAR_HEIGHT, Color8(30, 30, 30))
	container.add_child(player_hp_bar)
	player_hp_fill = _make_bar(base_x, hp_y, BAR_WIDTH, BAR_HEIGHT, Color8(60, 200, 60))
	container.add_child(player_hp_fill)

	var hp_lbl: Label = Label.new()
	hp_lbl.text = "HP"
	hp_lbl.position = Vector2(base_x + 2, hp_y - 1)
	hp_lbl.add_theme_font_size_override("font_size", 11)
	hp_lbl.add_theme_color_override("font_color", Color.WHITE)
	container.add_child(hp_lbl)

	# Stamina bar (blue)
	var stm_y: float = hp_y + BAR_HEIGHT + BAR_SPACING
	_add_border(container, base_x, stm_y, BAR_WIDTH, BAR_HEIGHT)
	player_stm_bar = _make_bar(base_x, stm_y, BAR_WIDTH, BAR_HEIGHT, Color8(30, 30, 30))
	container.add_child(player_stm_bar)
	player_stm_fill = _make_bar(base_x, stm_y, BAR_WIDTH, BAR_HEIGHT, Color8(50, 130, 230))
	container.add_child(player_stm_fill)

	var stm_lbl: Label = Label.new()
	stm_lbl.text = "STM"
	stm_lbl.position = Vector2(base_x + 2, stm_y - 1)
	stm_lbl.add_theme_font_size_override("font_size", 11)
	stm_lbl.add_theme_color_override("font_color", Color.WHITE)
	container.add_child(stm_lbl)

	# Power bar (yellow/orange)
	var pwr_y: float = stm_y + BAR_HEIGHT + BAR_SPACING
	_add_border(container, base_x, pwr_y, BAR_WIDTH, BAR_HEIGHT)
	player_pwr_bar = _make_bar(base_x, pwr_y, BAR_WIDTH, BAR_HEIGHT, Color8(30, 30, 30))
	container.add_child(player_pwr_bar)
	player_pwr_fill = _make_bar(base_x, pwr_y, BAR_WIDTH, BAR_HEIGHT, Color8(240, 190, 40))
	container.add_child(player_pwr_fill)

	var pwr_lbl: Label = Label.new()
	pwr_lbl.text = "PWR"
	pwr_lbl.position = Vector2(base_x + 2, pwr_y - 1)
	pwr_lbl.add_theme_font_size_override("font_size", 11)
	pwr_lbl.add_theme_color_override("font_color", Color.WHITE)
	container.add_child(pwr_lbl)

# ── Hint label (bottom-center) ──────────────────────────────────
func _build_hint() -> void:
	hint_label = Label.new()
	hint_label.text = "WASD: MOVER  |  F: GOLPE  |  SPACE: ESPECIAL"
	hint_label.position = Vector2(180, 478)
	hint_label.add_theme_font_size_override("font_size", 11)
	hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	add_child(hint_label)

# ── Update methods (unchanged logic) ────────────────────────────
func update_player_hp(value: float) -> void:
	player_hp_fill.size.x = BAR_WIDTH * clampf(value / 100.0, 0.0, 1.0)
	var ratio: float = value / 100.0
	if ratio > 0.5:
		player_hp_fill.color = Color8(60, 200, 60)
	elif ratio > 0.25:
		player_hp_fill.color = Color8(230, 160, 40)
	else:
		player_hp_fill.color = Color8(220, 50, 50)

func update_player_stamina(value: float) -> void:
	player_stm_fill.size.x = BAR_WIDTH * clampf(value, 0.0, 1.0)

func update_player_power(value: float) -> void:
	player_pwr_fill.size.x = BAR_WIDTH * clampf(value, 0.0, 1.0)
	if value >= 1.0:
		player_pwr_fill.color = Color8(255, 230, 60)
	else:
		player_pwr_fill.color = Color8(240, 190, 40)

func update_enemy_hp(value: float) -> void:
	enemy_hp_fill.size.x = BAR_WIDTH * clampf(value / 100.0, 0.0, 1.0)
	var ratio: float = value / 100.0
	if ratio > 0.5:
		enemy_hp_fill.color = Color8(60, 200, 60)
	elif ratio > 0.25:
		enemy_hp_fill.color = Color8(230, 160, 40)
	else:
		enemy_hp_fill.color = Color8(220, 50, 50)

func update_enemy_power(value: float) -> void:
	enemy_power_fill.size.x = BAR_WIDTH * clampf(value, 0.0, 1.0)

# ── Helpers ─────────────────────────────────────────────────────
func _make_bar(x: float, y: float, w: float, h: float, color: Color) -> ColorRect:
	var bar: ColorRect = ColorRect.new()
	bar.position = Vector2(x, y)
	bar.size = Vector2(w, h)
	bar.color = color
	return bar

func _add_border(parent: Control, x: float, y: float, w: float, h: float) -> void:
	var border: ColorRect = ColorRect.new()
	border.position = Vector2(x - BORDER, y - BORDER)
	border.size = Vector2(w + BORDER * 2, h + BORDER * 2)
	border.color = Color8(0, 0, 0)
	parent.add_child(border)
