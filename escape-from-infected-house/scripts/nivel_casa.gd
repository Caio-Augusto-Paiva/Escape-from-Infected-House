extends Node3D # Ou Node3D, CSGCombiner3D, dependendo do seu nó raiz
@export var mutante : CharacterBody3D
@export var porta_boss : CSGBox3D
@export var sensor : Area3D
@onready var musica_player = $MusicaFundo

func _ready():
	# Conecta o sinal do sensor via código (ou você pode fazer pela aba Node)
	if sensor:
		sensor.body_entered.connect(_on_sensor_entrou)

func _on_sensor_entrou(body):
	# Verifica se foi o Player que entrou
	if body.name == "Player":
		print("Armadilha ativada!")
		
		# 1. Fecha a porta
		# No Godot CSG, se você esconder a caixa de subtração, o buraco "fecha"
		if porta_boss:
			porta_boss.visible = false 
			# Se quiser garantir que a colisão feche também, force a atualização (geralmente automático no CSG)
		
		# 2. Acorda o Boss
		if mutante and mutante.has_method("acordar"):
			mutante.acordar()
		
		# 3. Destroi o sensor para não ativar de novo
		if sensor:
			sensor.queue_free()

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
