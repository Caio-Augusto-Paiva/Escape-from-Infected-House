extends CharacterBody3D

# --- CONFIGURAÇÕES DE MOVIMENTO ---
@export var velocidade_movimento : float = 10
@export var velocidade_rotacao : float = 4.5
var gravidade = 9.8

# --- SISTEMA DE VIDA ---
var vida_maxima = 100
var vida_atual = 100

@onready var barra_vida = get_tree().root.find_child("ProgressBar", true, false)
@onready var tela_game_over = get_tree().root.find_child("TelaGameOver", true, false)

# --- SISTEMA DE ARMAS ---
@onready var raycast = $Mao/RayCast3D
var inventario = ["Pistola"] 
var arma_atual_index = 0
var tempo_ultimo_tiro = 0.0
var tempo_animacao_tiro = 0.0  # Controla duração da animação

var status_armas = {
	"Pistola": { "dano": 10, "cadencia": 0.5, "automatica": false, "alcance_maximo": 20 },
	"SMG": { "dano": 5, "cadencia": 0.1, "automatica": true, "alcance_maximo": 15 },
	"Shotgun": { "dano_base": 50, "cadencia": 1.2, "automatica": false, "alcance_maximo": 10 }
}

# --- SISTEMA DE ANIMAÇÃO ---
# Se o AnimationTree não existir ou tiver outro nome, ajuste aqui
@onready var anim_tree = $AnimationTree
# Pega o controlador da máquina de estados para viajar entre animações (ex: Tiro)
@onready var state_machine = anim_tree.get("parameters/playback")

func _ready():
	# Inicialização do Raycast
	raycast.add_exception(self)
	raycast.enabled = true
	raycast.position = Vector3(0, 1.5, -0.5)
	
	# Inicialização da UI
	if barra_vida:
		barra_vida.max_value = vida_maxima
		barra_vida.value = vida_atual
		
	# Ativa a árvore de animação
	if anim_tree:
		anim_tree.active = true
		# Começa no estado idle
		if state_machine:
			state_machine.travel("idle")

func _physics_process(delta):
	# 1. Gravidade
	if not is_on_floor():
		velocity.y -= gravidade * delta

	# 2. Rotação (Tank Controls)
	var input_giro = Input.get_axis("girar_dir", "girar_esq")
	if input_giro != 0:
		rotate_y(input_giro * velocidade_rotacao * delta)

	# 3. Movimento
	var input_movimento = Input.get_axis("frente", "tras")
	var direcao = transform.basis.z * input_movimento
	
	if input_movimento != 0:
		velocity.x = direcao.x * velocidade_movimento
		velocity.z = direcao.z * velocidade_movimento
	else:
		velocity.x = move_toward(velocity.x, 0, velocidade_movimento)
		velocity.z = move_toward(velocity.z, 0, velocidade_movimento)

	move_and_slide()
	
	# 4. Combate
	var esta_atirando = gerenciar_tiro()
	
	# Atualiza o tempo da animação de tiro
	if tempo_animacao_tiro > 0:
		tempo_animacao_tiro -= delta
	
	# 5. Atualizar Animações de Movimento
	# Só muda se não estiver atirando E a animação de tiro terminou
	if state_machine and not esta_atirando and tempo_animacao_tiro <= 0:
		var estado_atual = state_machine.get_current_node()
		# Só faz travel se precisar mudar de estado
		if input_movimento != 0 and estado_atual != "walk":
			state_machine.travel("walk")
		elif input_movimento == 0 and estado_atual != "idle":
			state_machine.travel("idle")
	
	if Input.is_action_just_pressed("trocar_arma"):
		trocar_arma()

# --- COMBATE ---

func trocar_arma():
	arma_atual_index += 1
	if arma_atual_index >= inventario.size():
		arma_atual_index = 0
	print("Arma equipada: " + inventario[arma_atual_index])

func gerenciar_tiro():
	var arma_nome = inventario[arma_atual_index]
	var stats = status_armas[arma_nome]
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Verifica se está no cooldown
	if current_time - tempo_ultimo_tiro < stats["cadencia"]:
		return false

	var apertou_gatilho = false
	if stats["automatica"]:
		apertou_gatilho = Input.is_action_pressed("atirar")
	else:
		apertou_gatilho = Input.is_action_just_pressed("atirar")

	if apertou_gatilho:
		atirar(arma_nome, stats)
		tempo_ultimo_tiro = current_time
		return true
	
	return false

func atirar(nome, stats):
	raycast.target_position = Vector3(0, 0, -stats["alcance_maximo"])
	raycast.force_raycast_update()
	
	# Toca a animação de tiro e define duração mínima
	if state_machine:
		state_machine.travel("Shoot")
		tempo_animacao_tiro = 0.4  # A animação dura pelo menos 0.4 segundos
	
	if raycast.is_colliding():
		var objeto = raycast.get_collider()
		if objeto.has_method("receber_dano"):
			var ponto = raycast.get_collision_point()
			var dano_final = stats["dano"]
			
			if nome == "Shotgun":
				var dist = global_position.distance_to(ponto)
				var fator = clamp(1.0 - (dist / stats["alcance_maximo"]), 0.0, 1.0)
				dano_final = stats["dano_base"] * fator
			
			objeto.receber_dano(dano_final)

# --- VIDA ---

func receber_dano(quantidade):
	vida_atual -= quantidade
	if barra_vida: barra_vida.value = vida_atual
	if vida_atual <= 0: morrer()

func morrer():
	print("GAME OVER")
	if tela_game_over: tela_game_over.visible = true
	get_tree().paused = true
