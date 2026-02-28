extends CanvasLayer

# ── HUD — Punch-Out NES style retro bars ────────────────────────

const BAR_WIDTH: float = 160.0
const BAR_HEIGHT: float = 16.0
const BAR_SPACING: float = 6.0
const BORDER: float = 2.0

var enemy_hp_bar: ColorRect
var enemy_hp_fill: ColorRect
var enemy_stm_bar: ColorRect
var enemy_stm_fill: ColorRect
var enemy_power_bar: ColorRect
var enemy_power_fill: ColorRect

var player_hp_bar: ColorRect
var player_hp_fill: ColorRect
var player_stm_bar: ColorRect
var player_stm_fill: ColorRect
var player_pwr_bar: ColorRect
var player_pwr_fill: ColorRect

var hint_label: Label

# QTE UI Elements
var qte_container: Control
var qte_timer_bar: ColorRect
var qte_timer_fill: ColorRect
var qte_key_labels: Array[Label] = []
var qte_active: bool = false
var qte_max_time: float = 0.0
var qte_current_time: float = 0.0
var qte_mistake_flash: float = 0.0

var miss_label: Label
var miss_timer: float = 0.0

func _ready() -> void:
	layer = 10
	_build_enemy_hud()
	_build_player_hud()
	_build_hint()
	_build_qte_hud()
	_build_miss_hud()

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

	# Stamina bar (blue) with border
	var stm_y: float = hp_y + BAR_HEIGHT + BAR_SPACING
	_add_border(container, 12, stm_y, BAR_WIDTH, BAR_HEIGHT)
	enemy_stm_bar = _make_bar(12, stm_y, BAR_WIDTH, BAR_HEIGHT, Color8(30, 30, 30))
	container.add_child(enemy_stm_bar)
	enemy_stm_fill = _make_bar(12, stm_y, BAR_WIDTH, BAR_HEIGHT, Color8(50, 130, 230))
	container.add_child(enemy_stm_fill)

	var stm_lbl: Label = Label.new()
	stm_lbl.text = "STM"
	stm_lbl.position = Vector2(14, stm_y - 1)
	stm_lbl.add_theme_font_size_override("font_size", 11)
	stm_lbl.add_theme_color_override("font_color", Color.WHITE)
	container.add_child(stm_lbl)

	# Power bar (purple) with border
	var pwr_y: float = stm_y + BAR_HEIGHT + BAR_SPACING
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
	title_lbl.add_theme_color_override("font_color", Color8(26, 92, 26))
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
	hint_label.text = "WASD: MOVER  |  J: GOLPE S.  |  K: GOLPE F.  |  L: SUPER  |  SPACE: BLOQUEO"
	hint_label.position = Vector2(0, 460)
	hint_label.size = Vector2(800, 20)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 11)
	hint_label.add_theme_color_override("font_color", Color(0, 0, 0, 0.6))
	add_child(hint_label)

func _build_miss_hud() -> void:
	miss_label = Label.new()
	miss_label.text = "¡FALLASTE!"
	miss_label.position = Vector2(0, 180)
	miss_label.size = Vector2(800, 50)
	miss_label.horizontal_alignment = 1 # Center
	miss_label.add_theme_font_size_override("font_size", 28)
	miss_label.add_theme_color_override("font_color", Color8(255, 60, 60))
	miss_label.hide()
	add_child(miss_label)

# ── QTE HUD (Center screen) ───────────────────────────────────────
func _build_qte_hud() -> void:
	qte_container = Control.new()
	qte_container.name = "QTEContainer"
	qte_container.hide()
	add_child(qte_container)
	
	var title = Label.new()
	title.text = "ULTIMATE SEQUENCE!"
	title.position = Vector2(320, 160)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color8(255, 230, 60))
	qte_container.add_child(title)
	
	# Timer Bar
	_add_border(qte_container, 300, 190, 200, 10)
	qte_timer_bar = _make_bar(300, 190, 200, 10, Color8(30,30,30))
	qte_container.add_child(qte_timer_bar)
	qte_timer_fill = _make_bar(300, 190, 200, 10, Color8(255,230,60))
	qte_container.add_child(qte_timer_fill)

func _process(delta: float) -> void:
	if qte_active:
		qte_current_time -= delta
		qte_timer_fill.size.x = 200.0 * clampf(qte_current_time / qte_max_time, 0.0, 1.0)
		
		# Flash keys red on mistake
		if qte_mistake_flash > 0:
			qte_mistake_flash -= delta
			var flash_color = Color(1, 0.2, 0.2) if fmod(qte_mistake_flash, 0.1) > 0.05 else Color.WHITE
			for lbl in qte_key_labels:
				if lbl.get_theme_color("font_color") == Color.WHITE or lbl.get_theme_color("font_color") == Color(1, 0.2, 0.2):
					lbl.add_theme_color_override("font_color", flash_color)
		else:
			for lbl in qte_key_labels:
				if lbl.get_theme_color("font_color") == Color(1, 0.2, 0.2) or lbl.get_theme_color("font_color") == Color.WHITE:
					lbl.add_theme_color_override("font_color", Color.WHITE)
					
	if miss_timer > 0:
		miss_timer -= delta
		miss_label.position.y -= 30.0 * delta # Float up
		miss_label.modulate.a = clampf(miss_timer * 1.5, 0.0, 1.0) # Fade out
		if miss_timer <= 0:
			miss_label.hide()

func start_qte(sequence: Array[String], time_limit: float) -> void:
	qte_active = true
	qte_max_time = time_limit
	qte_current_time = time_limit
	qte_mistake_flash = 0.0
	
	# Clear old labels and boxes
	for child in qte_container.get_children():
		if child is ColorRect and child.name == "QTEBoxParent":
			child.queue_free()
	qte_key_labels.clear()
	
	# Instantiate sequence labels with boxes
	var box_size: float = 38.0
	var spacing: float = 46.0
	var total_width = (sequence.size() - 1) * spacing
	var start_x = 400.0 - (total_width / 2.0)
	
	for i in range(sequence.size()):
		var bg_box = ColorRect.new()
		bg_box.name = "QTEBoxParent"
		bg_box.size = Vector2(box_size, box_size)
		bg_box.position = Vector2(start_x + (i * spacing) - (box_size/2.0), 210)
		bg_box.color = Color8(50, 50, 50)
		
		var inner_box = ColorRect.new()
		inner_box.size = Vector2(box_size - 4, box_size - 4)
		inner_box.position = Vector2(2, 2)
		inner_box.color = Color8(20, 20, 20)
		bg_box.add_child(inner_box)
		
		var lbl = Label.new()
		lbl.text = sequence[i]
		lbl.horizontal_alignment = 1 # Center
		lbl.position = Vector2(0, 4)
		lbl.size = Vector2(box_size, box_size)
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		bg_box.add_child(lbl)
		
		qte_container.add_child(bg_box)
		qte_key_labels.append(lbl)
		
	# Highlight first one
	_highlight_qte_key(0)
	qte_container.show()

func update_qte_progress(current_index: int) -> void:
	if current_index > 0 and current_index <= qte_key_labels.size():
		var prev = qte_key_labels[current_index - 1]
		prev.add_theme_color_override("font_color", Color8(80, 255, 80)) # Green (done)
	if current_index < qte_key_labels.size():
		_highlight_qte_key(current_index)

func _highlight_qte_key(index: int) -> void:
	for i in range(qte_key_labels.size()):
		if i == index:
			# Just visual scale trick or leave it text. We'll make it yellow
			qte_key_labels[i].add_theme_color_override("font_color", Color8(255, 230, 60))

func show_miss_text() -> void:
	miss_label.modulate.a = 1.0
	miss_label.position.y = 180
	miss_label.show()
	miss_timer = 1.5

func show_qte_mistake() -> void:
	qte_mistake_flash = 0.3

func end_qte() -> void:
	qte_active = false
	qte_container.hide()

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

func update_enemy_stamina(value: float) -> void:
	enemy_stm_fill.size.x = BAR_WIDTH * clampf(value, 0.0, 1.0)

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
