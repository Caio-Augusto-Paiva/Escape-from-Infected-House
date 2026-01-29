extends Node3D

# --- REFERÊNCIAS ---
@export var mutante : CharacterBody3D  # Já usávamos para a armadilha, vamos usar para a vitória também
@export var porta_boss : CSGBox3D
@export var sensor_boss : Area3D

# --- REFERÊNCIAS DA VITÓRIA ---
@export var porta_saida : CSGBox3D     
@export var sensor_vitoria : Area3D    
@export var label_win : Label          

var pode_sair = false

func _ready():
	# Configuração da Armadilha do Boss
	if sensor_boss:
		sensor_boss.body_entered.connect(_on_sensor_boss_entrou)
	
	# Configuração da Vitória (AGORA LIGADO AO MUTANTE)
	if mutante:
		# Conecta o sinal que acabamos de criar no Mutante
		mutante.mutante_morreu.connect(_on_mutante_morreu)
	
	if sensor_vitoria:
		sensor_vitoria.body_entered.connect(_on_sensor_vitoria_entrou)

# --- LÓGICA DO BOSS ---
func _on_sensor_boss_entrou(body):
	if body.name == "Player":
		if porta_boss: porta_boss.visible = false 
		if mutante and mutante.has_method("acordar"): mutante.acordar()
		if sensor_boss: sensor_boss.queue_free()

# --- LÓGICA DA VITÓRIA ---

# Chamado automaticamente quando o MUTANTE morre
func _on_mutante_morreu():
	print("O Boss morreu! Porta de saída destrancada!")
	pode_sair = true
	
	# Muda a cor da porta para Branco Metálico
	if porta_saida:
		var material = StandardMaterial3D.new()
		material.albedo_color = Color.WHITE
		material.metallic = 1.0
		material.roughness = 0.2
		porta_saida.material_override = material

# Chamado quando o player encosta na porta
func _on_sensor_vitoria_entrou(body):
	if body.name == "Player":
		if pode_sair:
			ganhar_jogo()
		else:
			print("A porta está trancada! Derrote o Boss primeiro.")

func ganhar_jogo():
	print("VITÓRIA!")
	if label_win: label_win.visible = true
	
	# Espera 3 segundos e troca para os créditos
	await get_tree().create_timer(5.0).timeout
	get_tree().change_scene_to_file("res://cenas/tela_creditos.tscn")
