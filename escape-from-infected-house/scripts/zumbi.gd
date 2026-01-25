extends CharacterBody3D
#zumbi vai na direcao do player e navega pelo mapa de navegação 
@export var velocidade : float = 0.5
var gravidade = 9.8

@onready var agente_nav = $NavigationAgent3D

var player = null

func _ready():

	player = get_tree().root.find_child("Player", true, false)

	agente_nav.path_desired_distance = 1.0
	agente_nav.target_desired_distance = 1.0

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravidade * delta

	if player:
		agente_nav.target_position = player.global_position

		var proxima_posicao = agente_nav.get_next_path_position()
		var posicao_atual = global_position

		var direcao = (proxima_posicao - posicao_atual).normalized()

		direcao.y = 0 

		velocity.x = direcao.x * velocidade
		velocity.z = direcao.z * velocidade

		look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
		
	move_and_slide()
