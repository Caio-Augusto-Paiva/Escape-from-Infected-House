extends CharacterBody3D

# --- STATUS DE BOSS ---
@export var velocidade_normal : float = 3.5
@export var velocidade_furia : float = 6.0 
@export var dano_ataque : int = 40 
@export var vida_maxima : int = 500 
@export var tempo_entre_ataques : float = 2.0 
@export var distancia_ataque : float = 2.5 

# --- FÍSICA (NOVO) ---
var empurrao_knockback = Vector3.ZERO 
@export var forca_empurrao_objetos : float = 10.0 # Boss é muito forte (Zumbi era 2.0)

var vida_atual = 0
var gravidade = 9.8
var esta_em_furia = false

# --- REFERÊNCIAS ---
@onready var agente_nav = $NavigationAgent3D
@onready var anim_tree = $AnimationTree
@onready var state_machine = anim_tree.get("parameters/playback")
@export var porta_boss : CSGBox3D

var player = null
var cooldown_ataque = 0.0
var tempo_animacao_ataque = 0.0 
var dano_aplicado = false 
var esta_dormindo = true

func _ready():
	vida_atual = vida_maxima
	player = get_tree().root.find_child("Player", true, false)
	
	agente_nav.path_desired_distance = 1.5
	agente_nav.target_desired_distance = 1.5
	
	if anim_tree: anim_tree.active = true
	if state_machine: state_machine.travel("idle")
	print("BOSS SPAWNED: Mutante entrou na arena mas está dormindo!")

func _physics_process(delta):
	# Se estiver dormindo, não faz nada físico
	if esta_dormindo:
		return 
		
	# 1. Gravidade
	if not is_on_floor():
		velocity.y -= gravidade * delta
	
	# 2. IA de Perseguição
	if player:
		var distancia = global_position.distance_to(player.global_position)
		
		if distancia > distancia_ataque:
			agente_nav.target_position = player.global_position
			var proxima = agente_nav.get_next_path_position()
			var direcao = (proxima - global_position).normalized()
			direcao.y = 0
			
			var vel_atual = velocidade_furia if esta_em_furia else velocidade_normal
			
			velocity.x = direcao.x * vel_atual
			velocity.z = direcao.z * vel_atual
			
			look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
		else:
			# Para perto do player
			velocity.x = move_toward(velocity.x, 0, velocidade_normal * delta)
			velocity.z = move_toward(velocity.z, 0, velocidade_normal * delta)
			
			if cooldown_ataque <= 0:
				atacar()

	# 3. Aplica o Knockback (Soma à velocidade de movimento)
	if empurrao_knockback.length() > 0.1:
		empurrao_knockback = empurrao_knockback.lerp(Vector3.ZERO, 5 * delta)
		velocity += empurrao_knockback

	move_and_slide()
	
	# 4. Interação Física com Objetos (Empurrar Caixas)
	for i in get_slide_collision_count():
		var colisao = get_slide_collision(i)
		var objeto = colisao.get_collider()
		
		if objeto is RigidBody3D:
			# O Boss empurra com muita força!
			objeto.apply_central_impulse(-colisao.get_normal() * forca_empurrao_objetos * delta)
	
	# --- ATUALIZAÇÃO DE TIMERS E ANIMAÇÃO ---
	atualizar_timers_e_animacao(delta)

func atualizar_timers_e_animacao(delta):
	if cooldown_ataque > 0:
		cooldown_ataque -= delta
	
	if tempo_animacao_ataque > 0:
		tempo_animacao_ataque -= delta
		if not dano_aplicado and tempo_animacao_ataque < 0.375:
			dano_aplicado = true
			if player and player.has_method("receber_dano"):
				player.receber_dano(dano_ataque)
		
		if tempo_animacao_ataque <= 0 and state_machine:
			state_machine.travel("idle") # Volta para idle após ataque
			
	elif state_machine:
		var estado_atual = state_machine.get_current_node()
		if velocity.length() > 0.1 and estado_atual != "walk":
			state_machine.travel("walk")
		elif velocity.length() <= 0.1 and estado_atual != "idle":
			state_machine.travel("idle")

func acordar():
	esta_dormindo = false
	print("O MUTANTE ACORDOU!")

func atacar():
	print("BOSS SMASH!")
	cooldown_ataque = tempo_entre_ataques
	tempo_animacao_ataque = 1.5 
	dano_aplicado = false 
	if state_machine: state_machine.travel("attack")

# --- FUNÇÃO DE DANO ATUALIZADA COM FÍSICA ---
func receber_dano(quantidade, posicao_impacto = Vector3.ZERO):
	vida_atual -= quantidade
	print("Mutante Vida: ", vida_atual)
	
	# Lógica de Impulso Dinâmico
	if posicao_impacto != Vector3.ZERO:
		var direcao_empurrao = (global_position - posicao_impacto).normalized()
		direcao_empurrao.y = 0.1 
		
		# --- A MÁGICA ACONTECE AQUI ---
		# Definimos um "fator de resistência" (quanto maior, menos ele voa)
		# Mutante é pesado, então usamos um fator pequeno (ex: 0.05)
		# Cálculo: Direção * Dano Recebido * Fator
		
		var fator_peso = 0.05 
		empurrao_knockback = direcao_empurrao * quantidade * fator_peso
	
	if vida_atual < (vida_maxima / 2) and not esta_em_furia:
		entrar_em_furia()
	
	if vida_atual <= 0:
		morrer()

func entrar_em_furia():
	esta_em_furia = true
	print("O BOSS FICOU VERMELHO DE RAIVA!")
	# Dica Visual: Se quiser que ele fique vermelho mesmo
	var mesh = find_child("MeshInstance3D", true, false) # Tenta achar a mesh
	if mesh:
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(1, 0, 0) # Vermelho
		mesh.material_override = material

func morrer():
	print("BOSS DERROTADO!")
	if porta_boss: porta_boss.visible = true
	queue_free()
