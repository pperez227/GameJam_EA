extends Node2D

# Ring — Background loaded from exported Aseprite PNG

func _ready() -> void:
	var img = Image.new()
	if img.load("res://Ring.png") == OK:
		var tex = ImageTexture.create_from_image(img)
		var bg_sprite = Sprite2D.new()
		bg_sprite.name = "RingBackground"
		bg_sprite.texture = tex
		bg_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Center the sprite to fill the 800x500 viewport
		bg_sprite.centered = false
		# Scale to fit viewport
		var scale_x = 800.0 / img.get_width()
		var scale_y = 500.0 / img.get_height()
		bg_sprite.scale = Vector2(scale_x, scale_y)
		add_child(bg_sprite)
	else:
		push_error("Failed to load Ring.png")
