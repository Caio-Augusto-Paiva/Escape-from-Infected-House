extends CharacterBody3D

@export var velocidade_movimento : float = 10
@export var velocidade_rotacao : float = 4.5
@export var usar_mira_mouse : bool = true
@export var assistencia_mira_zumbi : bool = true
var gravidade = 9.8

@export var vida_maxima = 100
var vida_atual = vida_maxima
var tempo_regeneracao = 0.0

@onready var barra_vida = get_tree().root.find_child("ProgressBar", true, false)
@onready var tela_game_over = get_tree().root.find_child("TelaGameOver", true, false)

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

@onready var vis_pistola = $"Ch15_nonPBR/Skeleton3D/BoneAttachment3D/Visual_Pistola"
@onready var vis_smg = $"Ch15_nonPBR/Skeleton3D/BoneAttachment3D/Visual_SMG"
@onready var vis_shotgun = $"Ch15_nonPBR/Skeleton3D/BoneAttachment3D/Visual_Shotgun"

@onready var label_municao = $HUD_Municao/Label_Municao
@onready var label_mensagem = $HUD_Municao/Label_Mensagem

@onready var anim_tree = $AnimationTree
@onready var state_machine = anim_tree.get("parameters/playback")

func _ready():
	raycast.add_exception(self)
	raycast.enabled = true
	
	vida_atual = vida_maxima
	if barra_vida:
		barra_vida.max_value = vida_maxima
		barra_vida.value = vida_atual
	
	if label_mensagem:
		label_mensagem.visible = false
		
	if anim_tree:
		anim_tree.active = true
		if state_machine:
			state_machine.travel("idle")
			
	atualizar_visual_arma()
	atualizar_hud()

func _physics_process(delta):
	if vida_atual < vida_maxima and vida_atual > 0:
		tempo_regeneracao += delta
		if tempo_regeneracao >= 5.0:
			var cura = max(1, int(vida_maxima * 0.01)) 
			vida_atual = min(vida_maxima, vida_atual + cura)
			if barra_vida: barra_vida.value = vida_atual
			tempo_regeneracao = 0.0
	else:
		tempo_regeneracao = 0.0

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
	
	if usar_mira_mouse:
		atualizar_mira()
	else:
		raycast.global_rotation = global_rotation
	
	var esta_atirando = gerenciar_tiro()
	
	if tempo_animacao_tiro > 0:
		tempo_animacao_tiro -= delta
	
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
	var plano = Plane(Vector3.UP, raycast.global_position.y)
	
	var origem = camera.project_ray_origin(mouse_pos)
	var normal = camera.project_ray_normal(mouse_pos)
	
	var ponto_mira = plano.intersects_ray(origem, normal)
	
	if ponto_mira:
		var dir_player = -global_transform.basis.z
		var dir_mira = (ponto_mira - global_position).normalized()
		
		if dir_player.dot(dir_mira) > 0:
			raycast.look_at(ponto_mira, Vector3.UP)
		else:
			raycast.global_rotation = global_rotation

func aplicar_assistencia_mira():
	var inimigos = get_tree().get_nodes_in_group("Inimigos")
	var menor_distancia = 99999.0
	var alvo = null
	
	for inimigo in inimigos:
		
		if not is_instance_valid(inimigo): continue
		
		if not inimigo.visible: continue
		
		var vida_ok = true
		if "vida" in inimigo and inimigo.vida <= 0: vida_ok = false
		if "vida_atual" in inimigo and inimigo.vida_atual <= 0: vida_ok = false
		if not vida_ok: continue
		
		var alvo_pos = inimigo.global_position + Vector3(0, 1.2, 0)
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(raycast.global_position, alvo_pos)
		query.exclude = [self]
		var result = space_state.intersect_ray(query)
		if result and result.has("collider"):
			var col = result["collider"]
			if col != inimigo and col.get_parent() != inimigo:
				continue
		
		var dist = global_position.distance_to(inimigo.global_position)
		if dist < menor_distancia and dist < 30.0: 
			menor_distancia = dist
			alvo = inimigo
			
	if alvo:
		var alvo_pos = alvo.global_position + Vector3(0, 1.2, 0)
		
		var alvo_flat = Vector3(alvo_pos.x, global_position.y, alvo_pos.z)
		look_at(alvo_flat, Vector3.UP)

		raycast.look_at(alvo_pos, Vector3.UP)

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

	var falta = capacidade - qtd_atual
	
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
	if vis_pistola: vis_pistola.visible = false
	if vis_smg: vis_smg.visible = false
	if vis_shotgun: vis_shotgun.visible = false
	
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
	if state_machine:
		state_machine.travel("Shoot")
		tempo_animacao_tiro = 0.4
	
	if not bala_cena:
		print("ERRO: Esqueceu de colocar a cena da bala no Inspector!")
		return

	var nova_bala = bala_cena.instantiate()
	
	nova_bala.tipo_arma = nome
	nova_bala.dano = stats["dano"] if nome != "Shotgun" else stats["dano_base"]

	get_parent().add_child(nova_bala)

	nova_bala.global_position = raycast.global_position
	nova_bala.global_rotation = raycast.global_rotation


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
		
		await get_tree().create_timer(3.0).timeout
		if label_mensagem:
			label_mensagem.visible = false
