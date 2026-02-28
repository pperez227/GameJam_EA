extends Node

# Menu — connects JUGAR, SALIR, and difficulty selector

var option_difficulty: OptionButton

func _ready() -> void:
	var vbox = get_node("VBoxContainer")
	var btn_jugar: Button = vbox.get_node("Button")
	var btn_salir: Button = vbox.get_node("Button3")
	option_difficulty = vbox.get_node("DifficultyOption")
	btn_jugar.pressed.connect(_on_jugar_pressed)
	btn_salir.pressed.connect(_on_salir_pressed)

func _on_jugar_pressed() -> void:
	GameSettings.difficulty = option_difficulty.selected
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_salir_pressed() -> void:
	get_tree().quit()
