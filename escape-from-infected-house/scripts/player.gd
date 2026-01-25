extends CharacterBody3D
# logica do player ( colisao virar andar e velocidade)
const VELOCIDADE_MOVIMENTO = 3.0
const VELOCIDADE_ROTACAO = 4.5
var gravidade = 9.8

func _physics_process(delta):

	if not is_on_floor():
		velocity.y -= gravidade * delta

	var input_giro = Input.get_axis("girar_dir", "girar_esq")

	if input_giro != 0:
		rotate_y(input_giro * VELOCIDADE_ROTACAO * delta)

	var input_movimento = Input.get_axis("frente", "tras")
	
	var direcao = transform.basis.z * input_movimento
	
	if input_movimento != 0:
		velocity.x = direcao.x * VELOCIDADE_MOVIMENTO
		velocity.z = direcao.z * VELOCIDADE_MOVIMENTO
	else:
		velocity.x = move_toward(velocity.x, 0, VELOCIDADE_MOVIMENTO)
		velocity.z = move_toward(velocity.z, 0, VELOCIDADE_MOVIMENTO)

	move_and_slide()
