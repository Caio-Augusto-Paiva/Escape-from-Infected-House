extends CharacterBody3D

@export var velocidade : float = 2.0
@export var dano_ataque : int = 15
@export var vida : int = 100
@export var distancia_ataque : float = 2
@export var tempo_entre_ataques = 1.5

@export var campo_visao_angulo : float = 120.0 
@export var alcance_visao : float = 20.0
var perseguyendo_ativo = false

var gravidade = 9.8
var empurrao_knockback = Vector3.ZERO

@export var dropar_municao: bool = false
@export_enum("Pistola", "SMG", "Shotgun") var tipo_municao_drop: String = "Pistola"
@export var quantidade_municao_drop: int = 10
@export var cena_caixa_municao: PackedScene = preload("res://cenas/caixa_municao.tscn")
@export var is_horde_zombie: bool = false

@onready var agente_nav = $NavigationAgent3D
@onready var visual = $"Yaku J Ignite"
@onready var anim_tree = $AnimationTree
@onready var state_machine = anim_tree.get("parameters/playback")

@onready var audio_gemido = $AudioGemido
@onready var timer_gemido = $TimerGemido

var sons_gemido = [
	preload("res://Audio/undead-2.ogg"),
]

var player = null
var cooldown_ataque = 0.0
var tempo_animacao_ataque = 0.0
var dano_aplicado = false
var ultimo_local_visto = Vector3.ZERO
var esta_morto = false

func _ready():
	add_to_group("Inimigos")
	if is_horde_zombie:
		add_to_group("HordeZombies")
		process_mode = Node.PROCESS_MODE_DISABLED
		visible = false
		var col_shape = get_node_or_null("CollisionShape3D")
		if col_shape: col_shape.disabled = true
	
	vida = Global.get_zumbi_vida()
	velocidade *= Global.get_zumbi_velocidade_mult()

	player = get_tree().root.find_child("Player", true, false)
	if player:
		print("DEBUG: Zumbi encontrou objeto Player com sucesso.")
	else:
		print("DEBUG ERRO: Zumbi NAO encontrou objeto 'Player'. Verifique o nome do no na cena principal.")
	
	agente_nav.path_desired_distance = 1.0
	agente_nav.target_desired_distance = 1.0
	timer_gemido.timeout.connect(_on_timer_gemido_timeout)
	timer_gemido.start(randf_range(2.0, 5.0))
	
	if anim_tree:
		anim_tree.active = true
		if state_machine:
			state_machine.travel("idle")

func activate_horde_zombie():
	if is_horde_zombie:
		print("ACTIVATING HORDE ZOMBIE!")
		process_mode = Node.PROCESS_MODE_INHERIT
		visible = true
		var col_shape = get_node_or_null("CollisionShape3D")
		if col_shape: col_shape.set_deferred("disabled", false)

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravidade * delta

	if empurrao_knockback.length() > 0.1:
		empurrao_knockback = empurrao_knockback.lerp(Vector3.ZERO, 5 * delta)
		velocity += empurrao_knockback
		
	var esta_perseguindo = false
	
	if player:
		var tem_visao = verificar_visao_simples()
		
		if perseguyendo_ativo:
			if tem_visao:
				ultimo_local_visto = player.global_position
				agente_nav.target_position = ultimo_local_visto
			else:
				agente_nav.target_position = ultimo_local_visto

				if global_position.distance_to(ultimo_local_visto) < 2.0:
					print("Player sumiu! Zumbi desistiu.")
					perseguyendo_ativo = false
					esta_perseguindo = false
		else:
			if tem_visao:
				verificar_visao_player()

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

				var look_target = Vector3(proxima_pos.x, global_position.y, proxima_pos.z)
				if global_position.distance_squared_to(look_target) > 0.001:
					look_at(look_target, Vector3.UP)
				
			else:
				esta_perseguindo = false
				velocity.x = move_toward(velocity.x, 0, velocidade * delta * 5)
				velocity.z = move_toward(velocity.z, 0, velocidade * delta * 5)
				
				if cooldown_ataque <= 0 and tem_visao: 
					atacar()
		else:
			esta_perseguindo = false
			velocity.x = move_toward(velocity.x, 0, velocidade * delta * 5)
			velocity.z = move_toward(velocity.z, 0, velocidade * delta * 5)

	move_and_slide()

	if cooldown_ataque > 0:
		cooldown_ataque -= delta

	if tempo_animacao_ataque > 0:
		tempo_animacao_ataque -= delta

		if not dano_aplicado and tempo_animacao_ataque < 0.375: 
			dano_aplicado = true
			if player and player.has_method("receber_dano"):
				player.receber_dano(dano_ataque)

	elif state_machine:
		var estado_atual = state_machine.get_current_node()
		if esta_perseguindo:
			if estado_atual != "Walk":
				state_machine.travel("Walk")
		else:
			if estado_atual != "idle":
				state_machine.travel("idle")

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

	var debug_check = false
	if Engine.get_frames_drawn() % 60 == 0: debug_check = true

	var direcao_para_player = player.global_position - global_position
	var distancia = direcao_para_player.length()
	
	if distancia > alcance_visao:
		if debug_check: print("DEBUG: Player muito longe: ", distancia)
		return
		
	var forward = -global_transform.basis.z
	var forward_flat = Vector3(forward.x, 0, forward.z).normalized()
	
	var direcao_para_player_flat = Vector3(direcao_para_player.x, 0, direcao_para_player.z).normalized()
	
	var dot = forward_flat.dot(direcao_para_player_flat)
	
	var angulo_metade = deg_to_rad(campo_visao_angulo / 2.0)
	var limiar = cos(angulo_metade)
	
	if dot <= limiar:
		if debug_check: 
			print("DEBUG: Fora de angulo. DOT: ", snapped(dot, 0.01), " / Limiar: ", snapped(limiar, 0.01))
			print("--- TENTE GIRAR O MODELO 3D (Yaku J Ignite) EM 90 ou 180 GRAUS SE VOCE ESTIVER NA FRENTE ---")
		return

	var space_state = get_world_3d().direct_space_state
	var origem = global_position + Vector3(0, 1.5, 0)
	var destino = player.global_position + Vector3(0, 1.5, 0) 
	
	var query = PhysicsRayQueryParameters3D.create(origem, destino)
	query.exclude = [self.get_rid()] 
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var colidiu_com = result.collider

		if debug_check: print("DEBUG Raycast acertou: ", colidiu_com.name)
		
		var bateu_no_player = false
		if colidiu_com == player:
			bateu_no_player = true
		elif colidiu_com.get_parent() == player:
			bateu_no_player = true
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
	tempo_animacao_ataque = 1.5 
	dano_aplicado = false 
	
	if state_machine:
		state_machine.travel("Attack")

func receber_dano(quantidade, posicao_impacto = Vector3.ZERO):
	vida -= quantidade
	print("Zumbi sofreu ", quantidade, " de dano.")

	if posicao_impacto != Vector3.ZERO:
		var direcao_empurrao = (global_position - posicao_impacto).normalized()
		direcao_empurrao.y = 0.1 

		var fator_peso = 0.1 
		empurrao_knockback = direcao_empurrao * quantidade * fator_peso
	
	if vida <= 0 and not esta_morto:
		var pos_morte = global_position
		call_deferred("morrer", pos_morte)

func morrer(pos_morte: Vector3):
	if esta_morto: return
	esta_morto = true
	
	print("Zumbi Morreu!")
	if audio_gemido: audio_gemido.stop()
	if timer_gemido: timer_gemido.stop()
	
	if dropar_municao and cena_caixa_municao:
		var caixa = cena_caixa_municao.instantiate()
	
		if caixa:
			get_tree().current_scene.add_child(caixa)
			caixa.global_position = pos_morte

			caixa.tipo_municao = tipo_municao_drop
			caixa.quantidade = quantidade_municao_drop
			
			if caixa.has_method("atualizar_cor"):
				caixa.atualizar_cor()

	queue_free()
	
func _on_timer_gemido_timeout():
	if vida <= 0: return

	if sons_gemido.size() > 0:
		audio_gemido.stream = sons_gemido.pick_random()

		audio_gemido.pitch_scale = randf_range(0.8, 1.2)
		
		audio_gemido.play()

	timer_gemido.start(randf_range(3.0, 8.0))
	
