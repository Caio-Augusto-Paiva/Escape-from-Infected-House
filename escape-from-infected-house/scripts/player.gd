extends CharacterBody3D

# --- CONFIGURAÇÕES DE MOVIMENTO ---
@export var velocidade_movimento : float = 10
@export var velocidade_rotacao : float = 4.5
@export var usar_mira_mouse : bool = true
@export var assistencia_mira_zumbi : bool = true
var gravidade = 9.8

# --- SISTEMA DE VIDA ---
@export var vida_maxima = 100
var vida_atual = vida_maxima
var tempo_regeneracao = 0.0

@onready var barra_vida = get_tree().root.find_child("ProgressBar", true, false)
@onready var tela_game_over = get_tree().root.find_child("TelaGameOver", true, false)

# --- SISTEMA DE ARMAS ---
@export var bala_cena : PackedScene
@onready var raycast = $Mao/RayCast3D
var inventario = ["Pistola"] 
var arma_atual_index = 0
var tempo_ultimo_tiro = 0.0
var tempo_animacao_tiro = 0.0 

var capacidade_pente = {
	"Pistola": 10,
	"SMG": 20,
	"Shotgun": 4
}

var municao_no_pente = {
	"Pistola": 10,
	"SMG": 0,
	"Shotgun": 0
}

var municao_reserva = {
	"Pistola": 10,
	"SMG": 0,
	"Shotgun": 0
}

var status_armas = {
	"Pistola": { "dano": 10, "cadencia": 0.5, "automatica": false, "alcance_maximo": 20 },
	"SMG": { "dano": 8, "cadencia": 0.1, "automatica": true, "alcance_maximo": 15 },
	"Shotgun": { "dano_base": 50, "cadencia": 1.2, "automatica": false, "alcance_maximo": 10 }
}

# --- REFERÊNCIAS VISUAIS DAS ARMAS ---
@onready var vis_pistola = $"Ch15_nonPBR/Skeleton3D/BoneAttachment3D/Visual_Pistola"
@onready var vis_smg = $"Ch15_nonPBR/Skeleton3D/BoneAttachment3D/Visual_SMG"
@onready var vis_shotgun = $"Ch15_nonPBR/Skeleton3D/BoneAttachment3D/Visual_Shotgun"

# --- HUD ---
@onready var label_municao = $HUD_Municao/Label_Municao
@onready var label_mensagem = $HUD_Municao/Label_Mensagem

# --- SISTEMA DE ANIMAÇÃO ---
@onready var anim_tree = $AnimationTree
@onready var state_machine = anim_tree.get("parameters/playback")

func _ready():
	# Inicialização do Raycast - não precisa reposicionar, usa a posição da cena
	raycast.add_exception(self)
	raycast.enabled = true
	
	# Inicialização da UI
	vida_atual = vida_maxima # Força vida cheia no inicio
	if barra_vida:
		barra_vida.max_value = vida_maxima
		barra_vida.value = vida_atual
	
	if label_mensagem:
		label_mensagem.visible = false
		
	# Ativa a árvore de animação
	if anim_tree:
		anim_tree.active = true
		# Começa no estado Idle
		if state_machine:
			state_machine.travel("idle")
			
	# Atualiza visual inicial
	atualizar_visual_arma()
	atualizar_hud()

func _physics_process(delta):
	# REGENERAÇÃO DE VIDA (1% a cada 5 segundos)
	if vida_atual < vida_maxima and vida_atual > 0:
		tempo_regeneracao += delta
		if tempo_regeneracao >= 5.0:
			var cura = max(1, int(vida_maxima * 0.01)) 
			vida_atual = min(vida_maxima, vida_atual + cura)
			if barra_vida: barra_vida.value = vida_atual
			tempo_regeneracao = 0.0
	else:
		tempo_regeneracao = 0.0

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
	
	if usar_mira_mouse:
		atualizar_mira()
	else:
		# Se desligar a mira do mouse, alinha a arma com o corpo do player
		raycast.global_rotation = global_rotation
	
	# 4. Combate
	var esta_atirando = gerenciar_tiro()
	
	# Atualiza o tempo da animação de tiro
	if tempo_animacao_tiro > 0:
		tempo_animacao_tiro -= delta
	
	# 5. Atualizar Animações de Movimento
	# Só muda se não estiver atirando E a animação de tiro terminou
	if state_machine and not esta_atirando and tempo_animacao_tiro <= 0:
		var estado_atual = state_machine.get_current_node()
		
		if input_movimento != 0 and estado_atual != "walk":
			state_machine.travel("walk")
		elif input_movimento == 0 and estado_atual != "idle":
			state_machine.travel("idle")
	
	if Input.is_action_just_pressed("trocar_arma"):
		trocar_arma()
		
	if Input.is_action_just_pressed("recarregar"):
		recarregar()

func atualizar_mira():
	var camera = get_viewport().get_camera_3d()
	if not camera: return

	var mouse_pos = get_viewport().get_mouse_position()
	# Cria um plano na altura da arma para calcular onde o mouse está no mundo 3D
	var plano = Plane(Vector3.UP, raycast.global_position.y)
	
	var origem = camera.project_ray_origin(mouse_pos)
	var normal = camera.project_ray_normal(mouse_pos)
	
	var ponto_mira = plano.intersects_ray(origem, normal)
	
	if ponto_mira:
		# Vetor direção ignorando altura para verificação de ângulo (frente vs trás)
		var dir_player = -global_transform.basis.z # Frente do player (Godot usa -Z como forward)
		var dir_mira = (ponto_mira - global_position).normalized()
		
		# Produto escalar: > 0 significa que está no hemisfério da frente (180 graus de visão)
		if dir_player.dot(dir_mira) > 0:
			raycast.look_at(ponto_mira, Vector3.UP)
		else:
			# Se tentar mirar para trás, mantém a arma apontada para frente
			raycast.global_rotation = global_rotation

func aplicar_assistencia_mira():
	var inimigos = get_tree().get_nodes_in_group("Inimigos")
	var menor_distancia = 99999.0
	var alvo = null
	
	for inimigo in inimigos:
		# Verifica se o inimigo é válido e está vivo (caso tenha a propriedade vida > 0)
		if not is_instance_valid(inimigo): continue
		
		# Verifica a propriedade 'vida' se existir, ou 'vida_atual' (mutante)
		var vida_ok = true
		if "vida" in inimigo and inimigo.vida <= 0: vida_ok = false
		if "vida_atual" in inimigo and inimigo.vida_atual <= 0: vida_ok = false
		if not vida_ok: continue
		
		var dist = global_position.distance_to(inimigo.global_position)
		if dist < menor_distancia and dist < 30.0: # Alcance máximo do aim assist
			menor_distancia = dist
			alvo = inimigo
			
	if alvo:
		# Mira no "peito" do inimigo (altura aproximada)
		var alvo_pos = alvo.global_position + Vector3(0, 1.2, 0)
		
		# Vira o player para o inimigo (opcional, como pedido "player vira")
		# Rotaciona apenas no eixo Y para não inclinar o personagem
		var alvo_flat = Vector3(alvo_pos.x, global_position.y, alvo_pos.z)
		look_at(alvo_flat, Vector3.UP)
		
		# Vira a arma exatamente para o ponto
		raycast.look_at(alvo_pos, Vector3.UP)

# --- COMBATE ---

func recarregar():
	var arma_nome = inventario[arma_atual_index]
	var qtd_atual = municao_no_pente.get(arma_nome, 0)
	var capacidade = capacidade_pente.get(arma_nome, 0)
	var reserva = municao_reserva.get(arma_nome, 0)

	if qtd_atual >= capacidade:
		print("Pente já está cheio!")
		return
		
	if reserva <= 0:
		print("Sem munição de reserva!")
		return
	
	# Quanto falta para encher o pente
	var falta = capacidade - qtd_atual
	
	# Recarrega o quanto der (minimo entre o que falta e o que tem na reserva)
	var recarga = min(falta, reserva)
	
	municao_no_pente[arma_nome] += recarga
	municao_reserva[arma_nome] -= recarga
	
	print("Recarregou: ", arma_nome, " (+", recarga, ")")
	atualizar_hud()

func trocar_arma():
	arma_atual_index += 1
	if arma_atual_index >= inventario.size():
		arma_atual_index = 0
	print("Arma equipada: " + inventario[arma_atual_index])
	
	atualizar_visual_arma()
	atualizar_hud()

func atualizar_visual_arma():
	# 1. Esconde TODAS as armas
	if vis_pistola: vis_pistola.visible = false
	if vis_smg: vis_smg.visible = false
	if vis_shotgun: vis_shotgun.visible = false
	
	# 2. Mostra a correta
	var arma_nome = inventario[arma_atual_index]
	print("Atualizando visual para: ", arma_nome)
	match arma_nome:
		"Pistola":
			if vis_pistola: vis_pistola.visible = true
		"SMG":
			if vis_smg: vis_smg.visible = true
		"Shotgun":
			if vis_shotgun: vis_shotgun.visible = true

func gerenciar_tiro():
	var arma_nome = inventario[arma_atual_index]
	var stats = status_armas[arma_nome]
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if current_time - tempo_ultimo_tiro < stats["cadencia"]:
		return false

	if municao_no_pente[arma_nome] <= 0:
		if Input.is_action_just_pressed("atirar"):
			print("Sem munição no pente de ", arma_nome, "! Aperte R para recarregar.")
		return false

	var apertou_gatilho = false
	if stats["automatica"]:
		apertou_gatilho = Input.is_action_pressed("atirar")
	else:
		apertou_gatilho = Input.is_action_just_pressed("atirar")
	
	if apertou_gatilho:
		if assistencia_mira_zumbi:
			aplicar_assistencia_mira()
			
		atirar(arma_nome, stats)
		municao_no_pente[arma_nome] -= 1
		print("Bala gasta! Resta: ", municao_no_pente[arma_nome])
		tempo_ultimo_tiro = current_time
		atualizar_hud()
		return true
	
	return false

func atirar(nome, stats):
	# Toca animação (mantido do seu código original)
	if state_machine:
		state_machine.travel("Shoot")
		tempo_animacao_tiro = 0.4
	
	# Verifica se arrastou a cena da bala no Inspector
	if not bala_cena:
		print("ERRO: Esqueceu de colocar a cena da bala no Inspector!")
		return

	var nova_bala = bala_cena.instantiate()
	
	# Passa informações para a bala
	nova_bala.tipo_arma = nome
	nova_bala.dano = stats["dano"] if nome != "Shotgun" else stats["dano_base"]
	
	# Adiciona na cena principal
	get_parent().add_child(nova_bala)
	
	# Copia só posição e rotação
	nova_bala.global_position = raycast.global_position
	nova_bala.global_rotation = raycast.global_rotation

# --- VIDA E COLETA ---

func receber_dano(quantidade):
	vida_atual -= quantidade
	if barra_vida: barra_vida.value = vida_atual
	if vida_atual <= 0: morrer()

func morrer():
	print("GAME OVER")
	if tela_game_over: tela_game_over.visible = true
	get_tree().paused = true
	
func coletar_municao(tipo_arma, quantidade):
	if tipo_arma in municao_reserva:
		municao_reserva[tipo_arma] += quantidade
		mostrar_mensagem_coleta("Você pegou munição de " + tipo_arma + " x" + str(quantidade))
		atualizar_hud()
	else:
		print("Pegou munição de arma desconhecida")
		
func atualizar_hud():
	if label_municao:
		var arma_nome = inventario[arma_atual_index]
		var atual = municao_no_pente.get(arma_nome, 0)
		var reserva = municao_reserva.get(arma_nome, 0)
		label_municao.text = str(atual) + " / " + str(reserva)

func mostrar_mensagem_coleta(texto):
	print(texto)
	if label_mensagem:
		label_mensagem.text = texto
		label_mensagem.visible = true
		
		# Cria um timer temporário para esconder a mensagem
		await get_tree().create_timer(3.0).timeout
		if label_mensagem:
			label_mensagem.visible = false
