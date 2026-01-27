extends CharacterBody3D

# --- STATUS DO ZUMBI ---
var velocidade : float = 2.0
var dano_ataque : int = 15
var vida : int = 100
var distancia_ataque : float = 1

var gravidade = 9.8

# --- REFERÊNCIAS ---
@onready var agente_nav = $NavigationAgent3D
@onready var visual = $"Yaku J Ignite" # Ou o nome do nó do seu modelo 3D
@onready var anim_tree = $AnimationTree
# Acesso à máquina de estados para dar "Play" em ataques
@onready var state_machine = anim_tree.get("parameters/playback")

var player = null
var cooldown_ataque = 0.0
var tempo_entre_ataques = 1.5 # Segundos
var tempo_animacao_ataque = 0.0  # Tempo restante da animação de ataque
var dano_aplicado = false  # Flag para aplicar dano uma única vez por ataque

func _ready():
	# Busca o player na cena
	player = get_tree().root.find_child("Player", true, false)
	
	# Configurações de precisão do GPS
	agente_nav.path_desired_distance = 1.0
	agente_nav.target_desired_distance = 1.0
	
	# Garante que a AnimationTree esteja ligada
	if anim_tree:
		anim_tree.active = true
		# Começa no estado idle
		if state_machine:
			state_machine.travel("idle")

func _physics_process(delta):
	# 1. Gravidade
	if not is_on_floor():
		velocity.y -= gravidade * delta
	
	# Variável para controlar a intenção de animação
	var esta_perseguindo = false
	
	# 2. Comportamento (IA)
	if player:
		var distancia = global_position.distance_to(player.global_position)
		
		# LÓGICA DE MOVIMENTO
		if distancia > distancia_ataque:
			esta_perseguindo = true # Marcamos que a intenção é andar
			
			agente_nav.target_position = player.global_position
			var proxima_pos = agente_nav.get_next_path_position()
			var direcao = (proxima_pos - global_position).normalized()
			direcao.y = 0 
			
			# Interpolação (lerp) ajuda a suavizar mudanças bruscas de direção
			velocity.x = lerp(velocity.x, direcao.x * velocidade, 10.0 * delta)
			velocity.z = lerp(velocity.z, direcao.z * velocidade, 10.0 * delta)
			
			look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
		
		# LÓGICA DE PARADA / ATAQUE
		else:
			esta_perseguindo = false # Marcamos que ele deve parar
			
			# Freio suave ao chegar perto
			velocity.x = move_toward(velocity.x, 0, velocidade * delta * 5)
			velocity.z = move_toward(velocity.z, 0, velocidade * delta * 5)
			
			if cooldown_ataque <= 0:
				atacar()

	move_and_slide()
	
	# --- GERENCIAMENTO DE ANIMAÇÃO E COOLDOWNS ---
	
	if cooldown_ataque > 0:
		cooldown_ataque -= delta
	
	# Se estiver atacando (tempo de animação rolando)
	if tempo_animacao_ataque > 0:
		tempo_animacao_ataque -= delta
		
		# Lógica de aplicar dano no meio da animação
		if not dano_aplicado and tempo_animacao_ataque < 0.375: # Ajuste esse valor conforme sua animação
			dano_aplicado = true
			if player and player.has_method("receber_dano"):
				player.receber_dano(dano_ataque)

	# Se NÃO estiver atacando, controlamos Walk/Idle
	elif state_machine:
		var estado_atual = state_machine.get_current_node()
		
		# AQUI ESTÁ A CORREÇÃO:
		# Usamos a variável 'esta_perseguindo' em vez de velocity.length()
		if esta_perseguindo:
			if estado_atual != "Walk":
				state_machine.travel("Walk")
		else:
			if estado_atual != "idle":
				state_machine.travel("idle")
	
	# 3. Atualizar Animações (Baseado na velocidade real)
	# Só muda de estado se a animação de ataque terminou
	elif state_machine:
		var estado_atual = state_machine.get_current_node()
		# Só faz travel se precisar mudar de estado
		if velocity.length() > 0.1 and estado_atual != "Walk":
			state_machine.travel("Walk")
		elif velocity.length() <= 0.1 and estado_atual != "idle":
			state_machine.travel("idle")

func atacar():
	print("Zumbi: GROOOAR! (Tentando morder)")
	cooldown_ataque = tempo_entre_ataques
	tempo_animacao_ataque = 1.5  # Duração da animação de ataque (1.5 segundos)
	dano_aplicado = false  # Reset a flag para aplicar dano neste novo ataque
	
	# Toca animação de ataque
	if state_machine:
		state_machine.travel("Attack")

func receber_dano(quantidade):
	vida -= quantidade
	print("Zumbi sofreu ", quantidade, " de dano. Vida restante: ", vida)
	
	if vida <= 0:
		morrer()

func morrer():
	print("Zumbi Morreu!")
	# Opcional: Tocar animação de morte antes de sumir
	queue_free()
