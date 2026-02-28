extends Node

var music_player: AudioStreamPlayer

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	
	music_player.volume_db = -10.0
	
	# Load the stream and enable loop
	var stream = load("res://assets/music/musica.ogg")
	if stream != null:
		if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
			stream.loop = true
		elif stream.has_method("set_loop"):
			stream.set_loop(true)
			
		music_player.stream = stream
		music_player.play()
	else:
		push_warning("MusicManager: failed to load res://assets/music/musica.ogg")
