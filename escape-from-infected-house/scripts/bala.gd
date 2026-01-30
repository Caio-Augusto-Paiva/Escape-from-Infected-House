extends Area3D

@export var velocidade = 50.0
@export var dano = 10

var origem_tiro = Vector3.ZERO
var tipo_arma = ""

func _ready():
	origem_tiro = global_position
	# Destroi a bala após 3 segundos para não pesar o jogo
	await get_tree().create_timer(3.0).timeout
	queue_free()

func _physics_process(delta):
	# Move a bala para FRENTE (Z negativo local)
	position -= transform.basis.z * velocidade * delta

func _on_body_entered(body):
	# Se acertou o player ou o próprio dono do tiro, ignora (opcional)
	if body.name == "Player": 
		return
		
	print("Bala acertou: ", body.name)
	
	var dano_final = dano
	
	if tipo_arma == "Shotgun":
		var distancia = global_position.distance_to(origem_tiro)
		if distancia < 7.0:
			dano_final = 50
		elif distancia < 15.0:
			dano_final = 40
		else:
			dano_final = 20
	
	# Se o objeto tiver vida, aplica dano
	if body.has_method("receber_dano"):
		body.receber_dano(dano_final, global_position)
	
	# Destroi a bala ao bater
	queue_free()
