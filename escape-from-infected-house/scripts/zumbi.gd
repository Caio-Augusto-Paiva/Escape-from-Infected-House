extends CharacterBody3D

# --- STATUS DO ZUMBI ---
@export var velocidade : float = 2.0
@export var dano_ataque : int = 15
@export var vida : int = 100
@export var distancia_ataque : float = 2
@export var tempo_entre_ataques = 1.5 # Segundos

# --- VISÃO E IA ---
@export var campo_visao_angulo : float = 120.0 # Aumentei para facilitar
@export var alcance_visao : float = 20.0
var perseguyendo_ativo = false

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
var ultimo_local_visto = Vector3.ZERO # Para perseguição realista

func _ready():
	add_to_group("Inimigos")
	# Configura status baseado na dificuldade
	vida = Global.get_zumbi_vida()
	velocidade *= Global.get_zumbi_velocidade_mult()
	
	# Busca o player na cena
	player = get_tree().root.find_child("Player", true, false)
	if player:
		print("DEBUG: Zumbi encontrou objeto Player com sucesso.")
	else:
		print("DEBUG ERRO: Zumbi NAO encontrou objeto 'Player'. Verifique o nome do no na cena principal.")
	
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
		var tem_visao = verificar_visao_simples()
		
		# SISTEMA DE IA DE PERSEGUIÇÃO REALISTA
		if perseguyendo_ativo:
			if tem_visao:
				# Vê o player: Atualiza o alvo para a posição atual
				ultimo_local_visto = player.global_position
				agente_nav.target_position = ultimo_local_visto
			else:
				# Não vê o player: Vai até o último local visto
				agente_nav.target_position = ultimo_local_visto
				
				# Se chegou perto do último local visto e o player sumiu... perde o interesse
				if global_position.distance_to(ultimo_local_visto) < 2.0:
					print("Player sumiu! Zumbi desistiu.")
					perseguyendo_ativo = false
					esta_perseguindo = false
		else:
			# Não estava perseguindo: Tenta detectar (Cone de visão completo)
			if tem_visao:
				# Verifica ângulo e distância mais detalhados na funcao completa se quiser,
				# Ou usa a mesma lógica. Vamos usar a completa que já fizemos para o "Start"
				verificar_visao_player()
		
		# Movimento
		if perseguyendo_ativo:
			var distancia = global_position.distance_to(player.global_position)
			
			if distancia > distancia_ataque:
				esta_perseguindo = true
				
				var proxima_pos = agente_nav.get_next_path_position()
				var direcao = (proxima_pos - global_position).normalized()
				direcao.y = 0 
				
				var velocidade_alvo = direcao * velocidade
				velocity.x = lerp(velocity.x, velocidade_alvo.x, 10.0 * delta)
				velocity.z = lerp(velocity.z, velocidade_alvo.z, 10.0 * delta)
				
				# Vira para onde está andando
				var look_target = Vector3(proxima_pos.x, global_position.y, proxima_pos.z)
				if global_position.distance_squared_to(look_target) > 0.001:
					look_at(look_target, Vector3.UP)
				
			else:
				# Perto do player (e vendo ou perseguindo) -> Ataca
				esta_perseguindo = false
				velocity.x = move_toward(velocity.x, 0, velocidade * delta * 5)
				velocity.z = move_toward(velocity.z, 0, velocidade * delta * 5)
				
				if cooldown_ataque <= 0 and tem_visao: # Só ataca se ver (opcional)
					atacar()
		else:
			# Idle/Wander
			esta_perseguindo = false
			velocity.x = move_toward(velocity.x, 0, velocidade * delta * 5)
			velocity.z = move_toward(velocity.z, 0, velocidade * delta * 5)

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
		
		# Usamos a variável 'esta_perseguindo' em vez de velocity.length()
		if esta_perseguindo:
			if estado_atual != "Walk":
				state_machine.travel("Walk")
		else:
			if estado_atual != "idle":
				state_machine.travel("idle")

# Função leve para checar se TEM PAREDE na frente (sem cone de visão)
func verificar_visao_simples() -> bool:
	if not player: return false
	
	var space_state = get_world_3d().direct_space_state
	var origem = global_position + Vector3(0, 1.5, 0)
	var destino = player.global_position + Vector3(0, 1.5, 0)
	
	var query = PhysicsRayQueryParameters3D.create(origem, destino)
	query.exclude = [self.get_rid()] 
	var result = space_state.intersect_ray(query)
	
	if result:
		if result.collider == player: return true
		if result.collider.get_parent() == player: return true
		if "Player" in result.collider.name: return true
	return false

func verificar_visao_player():
	if not player: return
	
	# Limita checks para nao floodar o console
	var debug_check = false
	if Engine.get_frames_drawn() % 60 == 0: debug_check = true

	var direcao_para_player = player.global_position - global_position
	var distancia = direcao_para_player.length()
	
	# 1. Checa Distância
	if distancia > alcance_visao:
		if debug_check: print("DEBUG: Player muito longe: ", distancia)
		return
		
	# 2. Checa Ângulo (Campo de Visão) - AGORA EM 2D (PLANO XZ)
	var forward = -global_transform.basis.z
	# Remove componente Y para considerar apenas a direção em 360 graus no chão
	var forward_flat = Vector3(forward.x, 0, forward.z).normalized()
	
	var direcao_para_player_flat = Vector3(direcao_para_player.x, 0, direcao_para_player.z).normalized()
	
	# Produto escalar
	var dot = forward_flat.dot(direcao_para_player_flat)
	
	var angulo_metade = deg_to_rad(campo_visao_angulo / 2.0)
	var limiar = cos(angulo_metade)
	
	if dot <= limiar:
		if debug_check: 
			print("DEBUG: Fora de angulo. DOT: ", snapped(dot, 0.01), " / Limiar: ", snapped(limiar, 0.01))
			print("--- TENTE GIRAR O MODELO 3D (Yaku J Ignite) EM 90 ou 180 GRAUS SE VOCE ESTIVER NA FRENTE ---")
		return

	# 3. Raycast
	var space_state = get_world_3d().direct_space_state
	var origem = global_position + Vector3(0, 1.5, 0)
	var destino = player.global_position + Vector3(0, 1.5, 0) # Mira na cabeca
	
	var query = PhysicsRayQueryParameters3D.create(origem, destino)
	query.exclude = [self.get_rid()] 
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var colidiu_com = result.collider
		
		# Debug do que o raio acertou
		if debug_check: print("DEBUG Raycast acertou: ", colidiu_com.name)
		
		var bateu_no_player = false
		if colidiu_com == player:
			bateu_no_player = true
		elif colidiu_com.get_parent() == player:
			bateu_no_player = true
		# Caso especial: Raycast pode bater em filhos internos
		elif "Player" in colidiu_com.name:
			bateu_no_player = true
			
		if bateu_no_player:
			print("ZUMBI VIU VC! AGORA É PERSEGUIÇÃO!")
			perseguyendo_ativo = true
			if audio_gemido and not audio_gemido.playing:
				audio_gemido.play()
	else:
		if debug_check: print("DEBUG: Raycast não acertou nada (nem obstáculos, nem player).")

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
			
			get_tree().current_scene.add_child(caixa)
			
			# Atualiza o visual da caixa DEPOIS de adicionar à árvore (para garantir que @onready carregou)
			if caixa.has_method("atualizar_cor"):
				caixa.atualizar_cor()
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
	
