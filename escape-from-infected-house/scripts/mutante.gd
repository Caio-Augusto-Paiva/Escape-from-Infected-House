extends CharacterBody3D
#zumbi vai na direcao do player e navega pelo mapa de navegação 
@export var velocidade : float = 1
var gravidade = 9.8

@onready var agente_nav = $NavigationAgent3D

var player = null
var vida = 100

var dano_mordida = 20
var alcance_ataque = 0.3 # Distância mínima para morder
var tempo_entre_ataques = 1.5 # Segundos entre mordidas
var cooldown_ataque = 0.0 # Contador interno
func _ready():

	player = get_tree().root.find_child("Player", true, false)

	agente_nav.path_desired_distance = 1.0
	agente_nav.target_desired_distance = 1.0

func _physics_process(delta):
	# 1. Aplicar Gravidade (Igual antes)
	if not is_on_floor():
		velocity.y -= gravidade * delta
	
	# 2. Navegação (Igual antes, mas guardamos a distancia)
	var distancia_player = 999.0 # Valor alto inicial
	
	if player:
		# Calculamos a distância real
		distancia_player = global_position.distance_to(player.global_position)
		
		# Só persegue se estiver longe do alcance de ataque
		# Isso evita que o zumbi "empurre" o player
		if distancia_player > alcance_ataque:
			agente_nav.target_position = player.global_position
			var proxima = agente_nav.get_next_path_position()
			var direcao = (proxima - global_position).normalized()
			direcao.y = 0
			velocity.x = direcao.x * velocidade
			velocity.z = direcao.z * velocidade
			
			look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
		else:
			# Se chegou perto, para de andar
			velocity.x = 0
			velocity.z = 0
	
	move_and_slide()
	
	# 3. LÓGICA DE ATAQUE (NOVA)
	# Diminui o contador de tempo
	if cooldown_ataque > 0:
		cooldown_ataque -= delta
		
	# Se está perto E o contador zerou
	if distancia_player <= alcance_ataque and cooldown_ataque <= 0:
		atacar()

func atacar():
	# Reinicia o contador
	cooldown_ataque = tempo_entre_ataques
	
	if player.has_method("receber_dano"):
		print("Zumbi: MORDIDA!")
		player.receber_dano(dano_mordida)
func receber_dano(quantidade):
	vida -= quantidade
	print("Zumbi levou tiro! Vida restante: ", vida)
	
	$MeshInstance3D.transparency = 0.5
	await get_tree().create_timer(0.1).timeout 
	$MeshInstance3D.transparency = 0.0
	
	if vida <= 0:
		morrer()

func morrer():
	print("Zumbi Morreu!")
	queue_free() 
