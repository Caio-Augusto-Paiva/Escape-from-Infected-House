extends CharacterBody3D

# --- STATUS DE BOSS ---
@export var velocidade_normal : float = 3.5
@export var velocidade_furia : float = 6.0 # Corre muito quando está bravo
@export var dano_ataque : int = 40 # Dano massivo
@export var vida_maxima : int = 500 # Tanque de guerra

var vida_atual = 0
var gravidade = 9.8
var esta_em_furia = false

# --- REFERÊNCIAS ---
@onready var agente_nav = $NavigationAgent3D
@onready var anim_tree = $AnimationTree
@onready var state_machine = anim_tree.get("parameters/playback")

var player = null
var cooldown_ataque = 0.0
var tempo_entre_ataques = 2.0 # Boss é lento mas bate forte
var distancia_ataque = 2.5 # Alcance maior por ser gigante
var tempo_animacao_ataque = 0.0  # Tempo restante da animação de ataque
var dano_aplicado = false  # Flag para aplicar dano uma única vez por ataque

func _ready():
	vida_atual = vida_maxima
	player = get_tree().root.find_child("Player", true, false)
	
	agente_nav.path_desired_distance = 1.5
	agente_nav.target_desired_distance = 1.5
	
	if anim_tree: anim_tree.active = true
	if state_machine:
		state_machine.travel("idle")
	print("BOSS SPAWNED: Mutante entrou na arena!")

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravidade * delta
	
	if player:
		var distancia = global_position.distance_to(player.global_position)
		
		if distancia > distancia_ataque:
			agente_nav.target_position = player.global_position
			var proxima = agente_nav.get_next_path_position()
			var direcao = (proxima - global_position).normalized()
			direcao.y = 0
			
			# LÓGICA DE FÚRIA: Define a velocidade baseada na raiva
			var vel_atual = velocidade_furia if esta_em_furia else velocidade_normal
			
			velocity.x = direcao.x * vel_atual
			velocity.z = direcao.z * vel_atual
			
			look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
		else:
			velocity.x = 0
			velocity.z = 0
			if cooldown_ataque <= 0:
				atacar()

	move_and_slide()
	
	# Atualiza o timer de ataque e animação
	if cooldown_ataque > 0:
		cooldown_ataque -= delta
	
	if tempo_animacao_ataque > 0:
		tempo_animacao_ataque -= delta
		
		# Aplica o dano mais atrasado na animação (quando já passou 75% da animação)
		if not dano_aplicado and tempo_animacao_ataque < 0.375:
			dano_aplicado = true
			if player and player.has_method("receber_dano"):
				player.receber_dano(dano_ataque)
		
		# Quando a animação termina, força volta para Walk ou idle
		if tempo_animacao_ataque <= 0 and state_machine and player:
			var distancia = global_position.distance_to(player.global_position)
			if distancia > distancia_ataque:
				state_machine.travel("walk")
			else:
				state_machine.travel("idle")
	# Sempre atualiza as animações de movimento
	elif state_machine:
		var estado_atual = state_machine.get_current_node()
		# Só faz travel se precisar mudar de estado
		if velocity.length() > 0.1 and estado_atual != "walk":
			state_machine.travel("walk")
		elif velocity.length() <= 0.1 and estado_atual != "idle":
			state_machine.travel("idle")

func atacar():
	print("BOSS SMASH!")
	cooldown_ataque = tempo_entre_ataques
	tempo_animacao_ataque = 1.5  # Duração da animação de ataque (1.5 segundos)
	dano_aplicado = false  # Reset a flag para aplicar dano neste novo ataque
	
	# Toca animação de ataque
	if state_machine:
		state_machine.travel("attack")

func receber_dano(quantidade):
	vida_atual -= quantidade
	print(">>> MUTANTE RECEBEU DANO! <<<")
	print("Boss atingido! Vida: ", vida_atual, "/", vida_maxima)
	
	# MECÂNICA DE FÚRIA: Se a vida cair abaixo de 50% (250 HP)
	if vida_atual < (vida_maxima / 2) and not esta_em_furia:
		entrar_em_furia()
	
	if vida_atual <= 0:
		morrer()

func entrar_em_furia():
	esta_em_furia = true
	print("O BOSS FICOU VERMELHO DE RAIVA! (Velocidade Dobrada)")
	# Aqui você poderia mudar a cor dele para vermelho
	# $MeshInstance3D.material_override.albedo_color = Color(1, 0, 0)

func morrer():
	print("BOSS DERROTADO! PARABÉNS!")
	queue_free()
	# Aqui você chama a tela de Vitória!
