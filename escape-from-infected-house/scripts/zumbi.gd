extends CharacterBody3D

# --- STATUS DO ZUMBI ---
@export var velocidade : float = 2.0
@export var dano_ataque : int = 15
@export var vida : int = 100
@export var distancia_ataque : float = 2
@export var tempo_entre_ataques = 1.5 # Segundos

var gravidade = 9.8
var empurrao_knockback = Vector3.ZERO # <--- NOVO: Vetor para guardar a força do impacto

# --- DROP DE MUNIÇÃO (CONFIGURÁVEL NO INSPECTOR) ---
@export var dropar_municao: bool = false
@export_enum("Pistola", "SMG", "Shotgun") var tipo_municao_drop: String = "Pistola"
@export var quantidade_municao_drop: int = 10
@export var cena_caixa_municao: PackedScene = preload("res://cenas/caixa_municao.tscn")

# --- REFERÊNCIAS ---
@onready var agente_nav = $NavigationAgent3D
@onready var visual = $"Yaku J Ignite" # Ou o nome do nó do seu modelo 3D
@onready var anim_tree = $AnimationTree
# Acesso à máquina de estados para dar "Play" em ataques
@onready var state_machine = anim_tree.get("parameters/playback")

@onready var audio_gemido = $AudioGemido
@onready var timer_gemido = $TimerGemido

var sons_gemido = [
	preload("res://Audio/undead-2.ogg"),
]

var player = null
var cooldown_ataque = 0.0
var tempo_animacao_ataque = 0.0  # Tempo restante da animação de ataque
var dano_aplicado = false  # Flag para aplicar dano uma única vez por ataque

func _ready():
	# Busca o player na cena
	player = get_tree().root.find_child("Player", true, false)
	
	# Configurações de precisão do GPS
	agente_nav.path_desired_distance = 1.0
	agente_nav.target_desired_distance = 1.0
	timer_gemido.timeout.connect(_on_timer_gemido_timeout)
	timer_gemido.start(randf_range(2.0, 5.0))
	
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
	
	# Se houver força de empurrão, ela diminui com o tempo (atrito simulado)
	if empurrao_knockback.length() > 0.1:
		empurrao_knockback = empurrao_knockback.lerp(Vector3.ZERO, 5 * delta)
		# Adiciona o empurrão à velocidade atual
		velocity += empurrao_knockback
	
	var esta_perseguindo = false
	
	if player:
		var distancia = global_position.distance_to(player.global_position)
		
		if distancia > distancia_ataque:
			esta_perseguindo = true
			
			# Lógica de Navegação original
			agente_nav.target_position = player.global_position
			var proxima_pos = agente_nav.get_next_path_position()
			var direcao = (proxima_pos - global_position).normalized()
			direcao.y = 0 
			
			# A interpolação original já funciona bem
			# Nota: Usamos move_toward no eixo Y para manter a gravidade estável
			var velocidade_alvo = direcao * velocidade
			velocity.x = lerp(velocity.x, velocidade_alvo.x, 10.0 * delta)
			velocity.z = lerp(velocity.z, velocidade_alvo.z, 10.0 * delta)
			
			look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
		else:
			esta_perseguindo = false
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

func receber_dano(quantidade, posicao_impacto = Vector3.ZERO):
	vida -= quantidade
	print("Zumbi sofreu ", quantidade, " de dano.")
	
	# --- Lógica de Impulso Dinâmico ---
	if posicao_impacto != Vector3.ZERO:
		var direcao_empurrao = (global_position - posicao_impacto).normalized()
		direcao_empurrao.y = 0.1 # Zumbi é leve, então sobe um pouco mais (pulo)
		
		# Fator 0.5 = Ele é 10x mais leve que o Mutante (que usamos 0.05)
		var fator_peso = 0.1 
		
		# O empurrão agora depende do Dano (quantidade)
		empurrao_knockback = direcao_empurrao * quantidade * fator_peso
	
	if vida <= 0:
		morrer()

func morrer():
	print("Zumbi Morreu!")
	audio_gemido.stop() # Para de gemer se morrer
	timer_gemido.stop()
	if dropar_municao and cena_caixa_municao:
		var caixa = cena_caixa_municao.instantiate()
	
		if caixa:
			caixa.global_position = global_position
			# Configura tipo e quantidade, se o script da caixa tiver essas variáveis
			caixa.tipo_municao = tipo_municao_drop
			caixa.quantidade = quantidade_municao_drop
			# Atualiza o visual da caixa, caso exista o método
			if caixa.has_method("atualizar_cor"):
				caixa.atualizar_cor()
			get_tree().current_scene.add_child(caixa)
	# Opcional: Tocar animação de morte antes de sumir
	queue_free()
	
func _on_timer_gemido_timeout():
	# 1. Verifica se o zumbi ainda está vivo (opcional, mas bom pra evitar bugs)
	if vida <= 0: return
	
	# 2. Escolhe um som aleatório da lista
	if sons_gemido.size() > 0:
		audio_gemido.stream = sons_gemido.pick_random()
		
		# TRUQUE DE MESTRE: Variar o Pitch (Agudez)
		# Isso faz o mesmo som parecer diferente (mais grave ou agudo)
		audio_gemido.pitch_scale = randf_range(0.8, 1.2)
		
		audio_gemido.play()
	
	# 3. Reinicia o timer com um novo tempo aleatório (entre 3 e 8 segundos)
	timer_gemido.start(randf_range(3.0, 8.0))
	
