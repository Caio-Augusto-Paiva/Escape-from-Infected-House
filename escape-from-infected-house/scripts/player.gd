extends CharacterBody3D

@export var velocidade_movimento : float = 3.0
@export var velocidade_rotacao : float = 4.5
var gravidade = 9.8

@onready var raycast = $Mao/RayCast3D

var inventario = ["Pistola"] 
var arma_atual_index = 0
var tempo_ultimo_tiro = 0.0

var status_armas = {
	"Pistola": {
		"dano": 10,
		"cadencia": 0.5,
		"automatica": false,
		"alcance_maximo": 20
	},
	"SMG": {
		"dano": 5,
		"cadencia": 0.1,
		"automatica": true,
		"alcance_maximo": 15
	},
	"Shotgun": {
		"dano_base": 50,
		"cadencia": 1.2,
		"automatica": false,
		"alcance_maximo": 10
	}
}

func _ready():
	raycast.add_exception(self)

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravidade * delta

	var input_giro = Input.get_axis("girar_dir", "girar_esq")
	if input_giro != 0:
		rotate_y(input_giro * velocidade_rotacao * delta)

	var input_movimento = Input.get_axis("frente", "tras")
	var direcao = transform.basis.z * input_movimento
	
	if input_movimento != 0:
		velocity.x = direcao.x * velocidade_movimento
		velocity.z = direcao.z * velocidade_movimento
	else:
		velocity.x = move_toward(velocity.x, 0, velocidade_movimento)
		velocity.z = move_toward(velocity.z, 0, velocidade_movimento)

	move_and_slide()
	
	gerenciar_tiro()
	
	if Input.is_action_just_pressed("trocar_arma"):
		trocar_arma()

func trocar_arma():
	arma_atual_index += 1
	if arma_atual_index >= inventario.size():
		arma_atual_index = 0
	print("Arma equipada: " + inventario[arma_atual_index])

func gerenciar_tiro():
	var arma_nome = inventario[arma_atual_index]
	var stats = status_armas[arma_nome]
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if current_time - tempo_ultimo_tiro < stats["cadencia"]:
		return

	var apertou_gatilho = false
	if stats["automatica"]:
		apertou_gatilho = Input.is_action_pressed("atirar")
	else:
		apertou_gatilho = Input.is_action_just_pressed("atirar")

	if apertou_gatilho:
		atirar(arma_nome, stats)
		tempo_ultimo_tiro = current_time

func atirar(nome, stats):
	print("--- TENTANDO ATIRAR ---") # Se isso não aparecer, o botão não funciona.
	
	raycast.target_position.z = -stats["alcance_maximo"]
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var colisor = raycast.get_collider()
		print("Acertei algo: ", colisor.name) # Diz o que acertou
		
		if colisor.has_method("receber_dano"):
			print("E esse algo pode morrer!")
			# ... (cálculo de dano continua aqui) ...
			colisor.receber_dano(stats["dano"])
		else:
			print("Acertei, mas ele não tem script de vida.")
	else:
		print("O tiro saiu, mas não bateu em nada (Errou o alvo).")
