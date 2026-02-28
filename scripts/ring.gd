extends Node2D

# Ring — Punch-Out!! NES style boxing ring with crowd and spotlights

const BG_DARK: Color = Color8(10, 14, 40)
const BG_CROWD: Color = Color8(18, 24, 55)
const RING_APRON: Color = Color8(25, 75, 130)
const RING_FLOOR: Color = Color8(70, 190, 230)
const RING_FLOOR_DARK: Color = Color8(45, 150, 200)
const POST_WHITE: Color = Color8(240, 240, 245)
const POST_RED: Color = Color8(210, 50, 50)
const ROPE_RED: Color = Color8(210, 45, 45)
const ROPE_BLUE: Color = Color8(50, 90, 210)

func _ready() -> void:
	_build_background()
	_build_crowd()
	_build_spotlights()
	_build_ring_apron()
	_build_ring_canvas()
	_build_corner_pads()
	_build_posts()
	_build_ropes()

# ── Dark navy background ────────────────────────────────────────
func _build_background() -> void:
	var bg: Polygon2D = Polygon2D.new()
	bg.name = "Background"
	bg.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(800, 0),
		Vector2(800, 500), Vector2(0, 500)
	])
	bg.color = BG_DARK
	add_child(bg)

	# Slightly lighter strip behind crowd
	var crowd_bg: Polygon2D = Polygon2D.new()
	crowd_bg.name = "CrowdBG"
	crowd_bg.polygon = PackedVector2Array([
		Vector2(0, 80), Vector2(800, 80),
		Vector2(800, 240), Vector2(0, 240)
	])
	crowd_bg.color = BG_CROWD
	add_child(crowd_bg)

# ── Pixel art crowd ─────────────────────────────────────────────
func _build_crowd() -> void:
	var cw: int = 800
	var ch: int = 150
	var img: Image = Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var shirts: Array[Color] = [
		Color8(200, 50, 50), Color8(50, 120, 200), Color8(40, 160, 40),
		Color8(200, 180, 40), Color8(180, 80, 180), Color8(220, 120, 40),
		Color8(60, 60, 120), Color8(150, 40, 40), Color8(40, 100, 150),
		Color8(100, 60, 30), Color8(30, 80, 30), Color8(170, 50, 80)
	]
	var skins: Array[Color] = [
		Color8(240, 200, 160), Color8(210, 170, 130), Color8(180, 140, 100),
		Color8(140, 100, 60), Color8(100, 70, 40)
	]

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42

	# Row 1 (back, small)
	_draw_crowd_row(img, rng, 5, 4, 6, 4, shirts, skins, cw)
	# Row 2 (middle)
	_draw_crowd_row(img, rng, 45, 5, 8, 5, shirts, skins, cw)
	# Row 3 (front, bigger)
	_draw_crowd_row(img, rng, 90, 6, 10, 6, shirts, skins, cw)

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var crowd_sprite: Sprite2D = Sprite2D.new()
	crowd_sprite.name = "CrowdSprite"
	crowd_sprite.texture = tex
	crowd_sprite.position = Vector2(400, 165)
	add_child(crowd_sprite)

func _draw_crowd_row(img: Image, rng: RandomNumberGenerator, y_start: int,
		head_h: int, body_h: int, person_w: int,
		shirts: Array[Color], skins: Array[Color], width: int) -> void:
	var x: int = rng.randi_range(0, 3)
	var gap: int = 1
	while x < width:
		var skin: Color = skins[rng.randi_range(0, skins.size() - 1)]
		var shirt: Color = shirts[rng.randi_range(0, shirts.size() - 1)]
		_fill_rect_img(img, x, y_start, person_w, head_h, skin)
		_fill_rect_img(img, x, y_start + head_h, person_w, body_h, shirt)
		x += person_w + gap

# ── Spotlights ──────────────────────────────────────────────────
func _build_spotlights() -> void:
	# Left spotlight beam
	var left_light: Polygon2D = Polygon2D.new()
	left_light.name = "SpotlightL"
	left_light.polygon = PackedVector2Array([
		Vector2(150, 0), Vector2(220, 0),
		Vector2(450, 300), Vector2(100, 300)
	])
	left_light.color = Color(1.0, 0.97, 0.85, 0.07)
	add_child(left_light)

	# Right spotlight beam
	var right_light: Polygon2D = Polygon2D.new()
	right_light.name = "SpotlightR"
	right_light.polygon = PackedVector2Array([
		Vector2(580, 0), Vector2(650, 0),
		Vector2(700, 300), Vector2(350, 300)
	])
	right_light.color = Color(1.0, 0.97, 0.85, 0.07)
	add_child(right_light)

# ── Ring apron (outer darker area) ──────────────────────────────
func _build_ring_apron() -> void:
	var apron: Polygon2D = Polygon2D.new()
	apron.name = "RingApron"
	apron.polygon = PackedVector2Array([
		Vector2(100, 180), Vector2(700, 180),
		Vector2(800, 500), Vector2(0, 500)
	])
	apron.color = RING_APRON
	add_child(apron)

# ── Ring canvas (inner teal floor) ──────────────────────────────
func _build_ring_canvas() -> void:
	var canvas: Polygon2D = Polygon2D.new()
	canvas.name = "Canvas"
	canvas.polygon = PackedVector2Array([
		Vector2(140, 190), Vector2(660, 190),
		Vector2(760, 475), Vector2(40, 475)
	])
	canvas.color = RING_FLOOR
	add_child(canvas)

	# Center highlight
	var highlight: Polygon2D = Polygon2D.new()
	highlight.name = "CanvasHighlight"
	highlight.polygon = PackedVector2Array([
		Vector2(250, 220), Vector2(550, 220),
		Vector2(620, 420), Vector2(180, 420)
	])
	highlight.color = Color8(85, 210, 245)
	add_child(highlight)

# ── Corner pads (turnbuckle padding) ────────────────────────────
func _build_corner_pads() -> void:
	# Back-left (red)
	var pad_bl: Polygon2D = Polygon2D.new()
	pad_bl.name = "PadBL"
	pad_bl.polygon = _rect_poly(127, 178, 20, 18)
	pad_bl.color = Color8(200, 50, 50)
	add_child(pad_bl)
	# Back-right (blue)
	var pad_br: Polygon2D = Polygon2D.new()
	pad_br.name = "PadBR"
	pad_br.polygon = _rect_poly(653, 178, 20, 18)
	pad_br.color = Color8(50, 80, 200)
	add_child(pad_br)
	# Front-left (red)
	var pad_fl: Polygon2D = Polygon2D.new()
	pad_fl.name = "PadFL"
	pad_fl.polygon = _rect_poly(18, 400, 26, 30)
	pad_fl.color = Color8(200, 50, 50)
	add_child(pad_fl)
	# Front-right (blue)
	var pad_fr: Polygon2D = Polygon2D.new()
	pad_fr.name = "PadFR"
	pad_fr.polygon = _rect_poly(756, 400, 26, 30)
	pad_fr.color = Color8(50, 80, 200)
	add_child(pad_fr)

# ── Posts (white with red stripes) ──────────────────────────────
func _build_posts() -> void:
	# Back-left post
	_build_one_post("PostTL", 130, 168, 14, 30)
	# Back-right post
	_build_one_post("PostTR", 656, 168, 14, 30)
	# Front-left post
	_build_one_post("PostBL", 22, 390, 20, 55)
	# Front-right post
	_build_one_post("PostBR", 758, 390, 20, 55)

func _build_one_post(n: String, x: float, y: float, w: float, h: float) -> void:
	# White base
	var base: Polygon2D = Polygon2D.new()
	base.name = n
	base.polygon = _rect_poly(x, y, w, h)
	base.color = POST_WHITE
	add_child(base)
	# Red stripes
	var stripe_h: float = h / 6.0
	for i: int in range(3):
		var stripe: Polygon2D = Polygon2D.new()
		stripe.name = "%sStripe%d" % [n, i]
		var sy: float = y + stripe_h * (i * 2 + 1)
		stripe.polygon = _rect_poly(x, sy, w, stripe_h)
		stripe.color = POST_RED
		add_child(stripe)

# ── Ropes (red-blue-red, 3 levels) ──────────────────────────────
func _build_ropes() -> void:
	var back_l_x: float = 137.0
	var back_r_x: float = 663.0
	var front_l_x: float = 32.0
	var front_r_x: float = 768.0

	var back_ys: Array[float] = [175.0, 183.0, 191.0]
	var front_ys: Array[float] = [400.0, 418.0, 436.0]
	var colors: Array[Color] = [ROPE_RED, ROPE_BLUE, ROPE_RED]
	var widths: Array[float] = [3.0, 2.5, 3.0]

	for i: int in range(3):
		# Left side rope
		var rl: Line2D = Line2D.new()
		rl.name = "RopeL%d" % i
		rl.points = PackedVector2Array([
			Vector2(back_l_x, back_ys[i]), Vector2(front_l_x, front_ys[i])
		])
		rl.default_color = colors[i]
		rl.width = widths[i]
		add_child(rl)

		# Right side rope
		var rr: Line2D = Line2D.new()
		rr.name = "RopeR%d" % i
		rr.points = PackedVector2Array([
			Vector2(back_r_x, back_ys[i]), Vector2(front_r_x, front_ys[i])
		])
		rr.default_color = colors[i]
		rr.width = widths[i]
		add_child(rr)

		# Back connecting rope
		var rb: Line2D = Line2D.new()
		rb.name = "RopeBack%d" % i
		rb.points = PackedVector2Array([
			Vector2(back_l_x, back_ys[i]), Vector2(back_r_x, back_ys[i])
		])
		rb.default_color = colors[i]
		rb.width = widths[i]
		add_child(rb)

# ── Helpers ─────────────────────────────────────────────────────
func _rect_poly(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x, y), Vector2(x + w, y),
		Vector2(x + w, y + h), Vector2(x, y + h)
	])

func _fill_rect_img(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for px: int in range(maxi(x, 0), mini(x + w, img.get_width())):
		for py: int in range(maxi(y, 0), mini(y + h, img.get_height())):
			img.set_pixel(px, py, color)
