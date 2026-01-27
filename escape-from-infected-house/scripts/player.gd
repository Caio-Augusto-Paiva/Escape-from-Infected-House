extends CharacterBody3D

# --- CONFIGURAÇÕES DE MOVIMENTO ---
@export var velocidade_movimento : float = 5.0
@export var velocidade_rotacao : float = 4.5
var gravidade = 9.8

# --- SISTEMA DE VIDA ---
var vida_maxima = 100
var vida_atual = 100

# Tentamos achar a interface automaticamente na cena
# (O 'true, false' serve para buscar recursivamente em toda a árvore de nós)
@onready var barra_vida = get_tree().root.find_child("ProgressBar", true, false)
@onready var tela_game_over = get_tree().root.find_child("TelaGameOver", true, false)

# --- SISTEMA DE ARMAS ---
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
	# --- CONFIGURAÇÕES DE INICIALIZAÇÃO ---
	
	# 1. Garante que o Raycast ignore o corpo do próprio player
	raycast.add_exception(self)
	
	# 2. Força o Raycast a ligar (caso esteja desligado no editor)
	raycast.enabled = true
	
	# 3. Ajuste fino da posição do tiro (Levanta para altura dos olhos)
	raycast.position = Vector3(0, 1.5, -0.5)
	
	# 4. Inicializa a barra de vida visualmente
	if barra_vida:
		barra_vida.max_value = vida_maxima
		barra_vida.value = vida_atual
	
	print("Player pronto. Vida: ", vida_atual)

func _physics_process(delta):
	# --- MOVIMENTO (TANK CONTROLS) ---
	if not is_on_floor():
		velocity.y -= gravidade * delta

	# Rotação
	var input_giro = Input.get_axis("girar_dir", "girar_esq")
	if input_giro != 0:
		rotate_y(input_giro * velocidade_rotacao * delta)

	# Movimento Frente/Trás
	var input_movimento = Input.get_axis("frente", "tras")
	var direcao = transform.basis.z * input_movimento
	
	if input_movimento != 0:
		velocity.x = direcao.x * velocidade_movimento
		velocity.z = direcao.z * velocidade_movimento
	else:
		velocity.x = move_toward(velocity.x, 0, velocidade_movimento)
		velocity.z = move_toward(velocity.z, 0, velocidade_movimento)

	move_and_slide()
	
	# --- COMBATE ---
	gerenciar_tiro()
	
	if Input.is_action_just_pressed("trocar_arma"):
		trocar_arma()

# --- FUNÇÕES DE COMBATE ---

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
	# Configura o alcance e força atualização
	raycast.target_position = Vector3(0, 0, -stats["alcance_maximo"])
	raycast.force_raycast_update()
	
	# print("Bang! ", nome) # Debug opcional
	
	if raycast.is_colliding():
		var objeto_atingido = raycast.get_collider()
		
		# Verifica se o objeto tem vida (função receber_dano)
		if objeto_atingido.has_method("receber_dano"):
			var ponto_impacto = raycast.get_collision_point()
			var dano_final = 0
			
			if nome == "Shotgun":
				# Dano baseado na distância
				var distancia = global_position.distance_to(ponto_impacto)
				var fator = 1.0 - (distancia / stats["alcance_maximo"])
				fator = clamp(fator, 0.0, 1.0)
				dano_final = stats["dano_base"] * fator
			else:
				dano_final = stats["dano"]
			
			# Aplica o dano no inimigo
			objeto_atingido.receber_dano(dano_final)

# --- FUNÇÕES DE VIDA E GAME OVER ---

func receber_dano(quantidade):
	vida_atual -= quantidade
	print("Player levou dano! Vida restante: ", vida_atual)
	
	# Atualiza a barra se ela existir na cena
	if barra_vida:
		barra_vida.value = vida_atual
	
	if vida_atual <= 0:
		morrer()

func morrer():
	print("GAME OVER")
	
	# Mostra a tela de game over se ela existir
	if tela_game_over:
		tela_game_over.visible = true
	
	# Pausa o jogo inteiro
	get_tree().paused = true
