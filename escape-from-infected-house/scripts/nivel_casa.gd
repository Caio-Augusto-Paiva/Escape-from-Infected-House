extends Node3D # Ou Node3D, CSGCombiner3D, dependendo do seu nó raiz

@onready var musica_player = $MusicaFundo

func _process(delta):
	# Verifica se apertou o botão definido no Input Map
	if Input.is_action_just_pressed("mutar_musica"):
		# Inverte o estado de "Playing" (Se está tocando, pausa. Se pausado, toca)
		musica_player.stream_paused = not musica_player.stream_paused
		
		# Feedback no console para você saber que funcionou
		if musica_player.stream_paused:
			print("Música Mutada (Pausada)")
		else:
			print("Música Desmutada")
