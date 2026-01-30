extends Node3D

@export var mutante : CharacterBody3D
@export var porta_boss : CSGBox3D
@export var sensor_boss : Area3D

@export var porta_saida : CSGBox3D     
@export var sensor_vitoria : Area3D    
@export var label_win : Label          

var pode_sair = false

func _ready():
	if sensor_boss:
		sensor_boss.body_entered.connect(_on_sensor_boss_entrou)
	
	if mutante:
		if not mutante.mutante_morreu.is_connected(_on_mutante_morreu):
			mutante.mutante_morreu.connect(_on_mutante_morreu)
			print("Sinal do Mutante CONECTADO com sucesso!")
	else:
		print("ERRO CRÍTICO: Variável 'mutante' não foi atribuída em NivelCasa! Arraste o nó do Mutante para o script.")
	
	if sensor_vitoria:
		sensor_vitoria.body_entered.connect(_on_sensor_vitoria_entrou)
func _on_sensor_boss_entrou(body):
	if body.name == "Player":
		if porta_boss: porta_boss.visible = false 
		if mutante and mutante.has_method("acordar"): mutante.acordar()
		if sensor_boss: sensor_boss.queue_free()
func _on_mutante_morreu():
	print("O Boss morreu! Porta de saída destrancada!")
	pode_sair = true
	
	print("Chamando zumbis da horda...")
	get_tree().call_group("HordeZombies", "activate_horde_zombie")
	
	if porta_saida:
		var material = StandardMaterial3D.new()
		material.albedo_color = Color.WHITE
		material.metallic = 1.0
		material.roughness = 0.2
		porta_saida.material_override = material

func _on_sensor_vitoria_entrou(body):
	if body.name == "Player":
		if pode_sair:
			ganhar_jogo()
		else:
			print("A porta está trancada! Derrote o Boss primeiro.")

func ganhar_jogo():
	print("VITÓRIA!")
	if label_win: label_win.visible = true
	
	await get_tree().create_timer(5.0).timeout
	get_tree().change_scene_to_file("res://cenas/tela_creditos.tscn")

func _input(event):
	if event.is_action_pressed("mutar_musica"):
		var musica = $MusicaFundo
		if musica:
			musica.stream_paused = not musica.stream_paused
			print("Musica:", "Despausada" if not musica.stream_paused else "Pausada")
