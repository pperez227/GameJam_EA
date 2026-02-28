extends CanvasLayer

# ── HUD — Distributed layout ────────────────────────────────────

const BORDER: float = 2.0

# Enemy (top-right, HP only)
const ENEMY_BAR_W: float = 160.0
const ENEMY_BAR_H: float = 16.0
var enemy_hp_bar: ColorRect
var enemy_hp_fill: ColorRect

# Player HP (bottom-left)
const PLAYER_HP_W: float = 180.0
const PLAYER_HP_H: float = 16.0
var player_hp_bar: ColorRect
var player_hp_fill: ColorRect

# Player Stamina (vertical, left edge)
const STM_BAR_W: float = 12.0
const STM_BAR_H: float = 140.0
var player_stm_bar: ColorRect
var player_stm_fill: ColorRect

# Player Power (bottom-center)
const PWR_BAR_W: float = 200.0
const PWR_BAR_H: float = 14.0
var player_pwr_bar: ColorRect
var player_pwr_fill: ColorRect

# Tongue cooldown indicator
var tongue_cd_bg: ColorRect
var tongue_cd_fill: ColorRect
var tongue_cd_label: Label

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

# Round/match UI
var round_label: Label
var timer_label: Label
var score_label: Label
var knockdown_label: Label
var knockdown_progress_border: ColorRect
var knockdown_progress_bg: ColorRect
var knockdown_progress_fill: ColorRect
var combo_label: Label
var transition_label: Label

func _ready() -> void:
	layer = 10
	_build_enemy_hud()
	_build_player_hud()
	_build_hint()
	_build_qte_hud()
	_build_miss_hud()
	_build_round_hud()

# ── Enemy HUD (top-right, HP only) ─────────────────────────────
func _build_enemy_hud() -> void:
	var container: Control = Control.new()
	container.name = "EnemyHUD"
	add_child(container)

	var base_x: float = 800.0 - ENEMY_BAR_W - 12.0

	var lbl: Label = Label.new()
	lbl.text = "ENEMIGO"
	lbl.position = Vector2(base_x, 6)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color8(255, 255, 255))
	container.add_child(lbl)

	var hp_y: float = 24
	_add_border(container, base_x, hp_y, ENEMY_BAR_W, ENEMY_BAR_H)
	enemy_hp_bar = _make_bar(base_x, hp_y, ENEMY_BAR_W, ENEMY_BAR_H, Color8(30, 30, 30))
	container.add_child(enemy_hp_bar)
	enemy_hp_fill = _make_bar(base_x, hp_y, ENEMY_BAR_W, ENEMY_BAR_H, Color8(60, 200, 60))
	container.add_child(enemy_hp_fill)

	var hp_lbl: Label = Label.new()
	hp_lbl.text = "HP"
	hp_lbl.position = Vector2(base_x + 2, hp_y - 1)
	hp_lbl.add_theme_font_size_override("font_size", 11)
	hp_lbl.add_theme_color_override("font_color", Color8(220, 220, 220))
	container.add_child(hp_lbl)

# ── Player HUD (distributed) ──────────────────────────────────
func _build_player_hud() -> void:
	var container: Control = Control.new()
	container.name = "PlayerHUD"
	add_child(container)

	# ── HP bar (bottom-left) ──
	var hp_x: float = 12.0
	var hp_y: float = 440.0
	var title_lbl: Label = Label.new()
	title_lbl.text = "JUGADOR"
	title_lbl.position = Vector2(hp_x, hp_y - 18)
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", Color8(255, 255, 255))
	container.add_child(title_lbl)

	_add_border(container, hp_x, hp_y, PLAYER_HP_W, PLAYER_HP_H)
	player_hp_bar = _make_bar(hp_x, hp_y, PLAYER_HP_W, PLAYER_HP_H, Color8(30, 30, 30))
	container.add_child(player_hp_bar)
	player_hp_fill = _make_bar(hp_x, hp_y, PLAYER_HP_W, PLAYER_HP_H, Color8(60, 200, 60))
	container.add_child(player_hp_fill)

	var hp_lbl: Label = Label.new()
	hp_lbl.text = "HP"
	hp_lbl.position = Vector2(hp_x + 2, hp_y - 1)
	hp_lbl.add_theme_font_size_override("font_size", 11)
	hp_lbl.add_theme_color_override("font_color", Color8(220, 220, 220))
	container.add_child(hp_lbl)

	# ── Stamina bar (vertical, left edge) ──
	var stm_x: float = 6.0
	var stm_y: float = 200.0
	var stm_lbl: Label = Label.new()
	stm_lbl.text = "STM"
	stm_lbl.position = Vector2(stm_x - 2, stm_y - 16)
	stm_lbl.add_theme_font_size_override("font_size", 9)
	stm_lbl.add_theme_color_override("font_color", Color8(180, 200, 255))
	container.add_child(stm_lbl)

	_add_border(container, stm_x, stm_y, STM_BAR_W, STM_BAR_H)
	player_stm_bar = _make_bar(stm_x, stm_y, STM_BAR_W, STM_BAR_H, Color8(30, 30, 30))
	container.add_child(player_stm_bar)
	# Fill starts at bottom — position adjusted in update
	player_stm_fill = _make_bar(stm_x, stm_y + STM_BAR_H, STM_BAR_W, 0, Color8(50, 130, 230))
	container.add_child(player_stm_fill)

	# ── Tongue cooldown indicator (below stamina) ──
	var tongue_x: float = 4.0
	var tongue_y: float = stm_y + STM_BAR_H + 10.0
	var tongue_size: float = 18.0
	_add_border(container, tongue_x, tongue_y, tongue_size, tongue_size)
	tongue_cd_bg = _make_bar(tongue_x, tongue_y, tongue_size, tongue_size, Color8(40, 40, 40))
	container.add_child(tongue_cd_bg)
	tongue_cd_fill = _make_bar(tongue_x, tongue_y, tongue_size, 0, Color8(255, 100, 150))
	container.add_child(tongue_cd_fill)
	tongue_cd_label = Label.new()
	tongue_cd_label.text = "K"
	tongue_cd_label.position = Vector2(tongue_x + 2, tongue_y - 1)
	tongue_cd_label.add_theme_font_size_override("font_size", 12)
	tongue_cd_label.add_theme_color_override("font_color", Color8(180, 180, 180))
	container.add_child(tongue_cd_label)

	# ── Power bar (bottom-center) ──
	var pwr_x: float = 300.0
	var pwr_y: float = 454.0
	var super_lbl: Label = Label.new()
	super_lbl.text = "SUPER"
	super_lbl.position = Vector2(pwr_x, pwr_y - 16)
	super_lbl.size = Vector2(PWR_BAR_W, 16)
	super_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	super_lbl.add_theme_font_size_override("font_size", 10)
	super_lbl.add_theme_color_override("font_color", Color8(255, 230, 140))
	container.add_child(super_lbl)

	_add_border(container, pwr_x, pwr_y, PWR_BAR_W, PWR_BAR_H)
	player_pwr_bar = _make_bar(pwr_x, pwr_y, PWR_BAR_W, PWR_BAR_H, Color8(30, 30, 30))
	container.add_child(player_pwr_bar)
	player_pwr_fill = _make_bar(pwr_x, pwr_y, PWR_BAR_W, PWR_BAR_H, Color8(240, 190, 40))
	container.add_child(player_pwr_fill)

# ── Hint label (bottom-center) ──────────────────────────────────
func _build_hint() -> void:
	hint_label = Label.new()
	hint_label.text = "WASD: MOVER  |  J: GOLPE  |  K: LENGUA  |  L: SUPER  |  SPACE: BLOQUEO"
	hint_label.position = Vector2(0, 468)
	hint_label.size = Vector2(800, 16)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 10)
	hint_label.add_theme_color_override("font_color", Color8(160, 160, 160))
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
			qte_container.remove_child(child)
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
	player_hp_fill.size.x = PLAYER_HP_W * clampf(value / 100.0, 0.0, 1.0)
	var ratio: float = value / 100.0
	if ratio > 0.5:
		player_hp_fill.color = Color8(60, 200, 60)
	elif ratio > 0.25:
		player_hp_fill.color = Color8(230, 160, 40)
	else:
		player_hp_fill.color = Color8(220, 50, 50)

func update_player_stamina(value: float) -> void:
	var fill_h: float = STM_BAR_H * clampf(value, 0.0, 1.0)
	player_stm_fill.size.y = fill_h
	player_stm_fill.position.y = 200.0 + STM_BAR_H - fill_h

func update_player_power(value: float) -> void:
	player_pwr_fill.size.x = PWR_BAR_W * clampf(value, 0.0, 1.0)
	if value >= 1.0:
		player_pwr_fill.color = Color8(255, 230, 60)
	else:
		player_pwr_fill.color = Color8(240, 190, 40)

func update_enemy_hp(value: float) -> void:
	enemy_hp_fill.size.x = ENEMY_BAR_W * clampf(value / 100.0, 0.0, 1.0)
	var ratio: float = value / 100.0
	if ratio > 0.5:
		enemy_hp_fill.color = Color8(60, 200, 60)
	elif ratio > 0.25:
		enemy_hp_fill.color = Color8(230, 160, 40)
	else:
		enemy_hp_fill.color = Color8(220, 50, 50)

func update_enemy_stamina(_value: float) -> void:
	pass  # Enemy stamina hidden

func update_enemy_power(_value: float) -> void:
	pass  # Enemy power hidden

func update_tongue_cooldown(ratio: float) -> void:
	# ratio = remaining cooldown / max (1.0 = full cooldown, 0.0 = ready)
	var ready_ratio: float = 1.0 - clampf(ratio, 0.0, 1.0)
	var fill_h: float = 18.0 * ready_ratio
	tongue_cd_fill.size.y = fill_h
	tongue_cd_fill.position.y = (200.0 + STM_BAR_H + 10.0) + 18.0 - fill_h
	if ratio <= 0:
		tongue_cd_fill.color = Color8(100, 255, 100)
		tongue_cd_label.add_theme_color_override("font_color", Color8(100, 255, 100))
	else:
		tongue_cd_fill.color = Color8(255, 100, 150)
		tongue_cd_label.add_theme_color_override("font_color", Color8(180, 180, 180))

# ── Helpers ─────────────────────────────────────────────────────
func _make_bar(x: float, y: float, w: float, h: float, color: Color) -> ColorRect:
	var bar: ColorRect = ColorRect.new()
	bar.position = Vector2(x, y)
	bar.size = Vector2(w, h)
	bar.color = color
	return bar

func _add_border(parent: Node, x: float, y: float, w: float, h: float) -> void:
	var border: ColorRect = ColorRect.new()
	border.position = Vector2(x - BORDER, y - BORDER)
	border.size = Vector2(w + BORDER * 2, h + BORDER * 2)
	border.color = Color8(0, 0, 0)
	parent.add_child(border)

# ── Round HUD ─────────────────────────────────────────────────
func _build_round_hud() -> void:
	# Round label (top center)
	round_label = Label.new()
	round_label.text = "Round 1"
	round_label.position = Vector2(0, 6)
	round_label.size = Vector2(800, 30)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.add_theme_font_size_override("font_size", 16)
	round_label.add_theme_color_override("font_color", Color8(255, 230, 140))
	add_child(round_label)

	# Timer (top center, below round)
	timer_label = Label.new()
	timer_label.text = "1:00"
	timer_label.position = Vector2(0, 26)
	timer_label.size = Vector2(800, 30)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 22)
	timer_label.add_theme_color_override("font_color", Color8(255, 255, 255))
	add_child(timer_label)

	# Score (top center, below timer)
	score_label = Label.new()
	score_label.text = "0 - 0"
	score_label.position = Vector2(0, 50)
	score_label.size = Vector2(800, 30)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 14)
	score_label.add_theme_color_override("font_color", Color8(200, 200, 200))
	add_child(score_label)


	# Knockdown countdown (center screen, hidden)
	knockdown_label = Label.new()
	knockdown_label.text = ""
	knockdown_label.position = Vector2(0, 185)
	knockdown_label.size = Vector2(800, 110)
	knockdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	knockdown_label.add_theme_font_size_override("font_size", 36)
	knockdown_label.add_theme_color_override("font_color", Color("1a3a8a"))
	knockdown_label.visible = false
	add_child(knockdown_label)

	# Knockdown mash progress bar (below knockdown text)
	var kd_bar_width: float = 200.0
	var kd_bar_height: float = 14.0
	var kd_bar_x: float = 300.0
	var kd_bar_y: float = 295.0
	# Create border manually so we can save the reference and hide it
	knockdown_progress_border = ColorRect.new()
	knockdown_progress_border.position = Vector2(kd_bar_x - BORDER, kd_bar_y - BORDER)
	knockdown_progress_border.size = Vector2(kd_bar_width + BORDER * 2, kd_bar_height + BORDER * 2)
	knockdown_progress_border.color = Color8(0, 0, 0)
	knockdown_progress_border.visible = false
	add_child(knockdown_progress_border)
	knockdown_progress_bg = _make_bar(kd_bar_x, kd_bar_y, kd_bar_width, kd_bar_height, Color8(30, 30, 30))
	knockdown_progress_bg.visible = false
	add_child(knockdown_progress_bg)
	knockdown_progress_fill = _make_bar(kd_bar_x, kd_bar_y, 0, kd_bar_height, Color8(60, 200, 60))
	knockdown_progress_fill.visible = false
	add_child(knockdown_progress_fill)

	# Combo counter (right side, hidden)
	combo_label = Label.new()
	combo_label.text = ""
	combo_label.position = Vector2(650, 430)
	combo_label.size = Vector2(180, 50)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.add_theme_font_size_override("font_size", 32)
	combo_label.add_theme_color_override("font_color", Color8(255, 230, 60))
	combo_label.visible = false
	add_child(combo_label)

	# Transition label (center screen, hidden)
	transition_label = Label.new()
	transition_label.text = ""
	transition_label.position = Vector2(0, 160)
	transition_label.size = Vector2(800, 100)
	transition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transition_label.add_theme_font_size_override("font_size", 40)
	transition_label.add_theme_color_override("font_color", Color8(255, 230, 140))
	transition_label.visible = false
	add_child(transition_label)

# ── Round HUD updates ─────────────────────────────────────────
func update_round(round_num: int) -> void:
	round_label.text = "Round " + str(round_num)

func update_timer(seconds: float) -> void:
	var mins: int = int(seconds) / 60
	var secs: int = int(seconds) % 60
	timer_label.text = str(mins) + ":" + ("%02d" % secs)
	if seconds <= 10.0:
		timer_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		timer_label.add_theme_color_override("font_color", Color8(255, 255, 255))

func update_score(p_wins: int, e_wins: int) -> void:
	score_label.text = str(p_wins) + " - " + str(e_wins)

func show_knockdown(count: int, is_player: bool) -> void:
	knockdown_label.visible = true
	knockdown_label.add_theme_color_override("font_color", Color("1a3a8a"))
	if is_player:
		knockdown_label.text = str(count) + "\n\u00a1Presiona A y D para levantarte!"
		knockdown_progress_border.visible = true
		knockdown_progress_bg.visible = true
		knockdown_progress_fill.visible = true
	else:
		knockdown_label.text = "KNOCKDOWN\n" + str(count)
		knockdown_progress_border.visible = false
		knockdown_progress_bg.visible = false
		knockdown_progress_fill.visible = false

func hide_knockdown() -> void:
	knockdown_label.visible = false
	knockdown_progress_border.visible = false
	knockdown_progress_bg.visible = false
	knockdown_progress_fill.visible = false

func update_knockdown_progress(ratio: float) -> void:
	knockdown_progress_fill.size.x = 200.0 * clampf(ratio, 0.0, 1.0)

func update_combo(count: int) -> void:
	if count >= 2:
		combo_label.visible = true
		combo_label.text = str(count) + "x"
	else:
		combo_label.visible = false

func show_transition(text: String) -> void:
	transition_label.text = text
	transition_label.visible = true

func hide_transition() -> void:
	transition_label.visible = false
