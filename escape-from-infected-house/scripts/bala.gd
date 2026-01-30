extends Area3D

@export var velocidade = 50.0
@export var dano = 10

var origem_tiro = Vector3.ZERO
var tipo_arma = ""

func _ready():
	origem_tiro = global_position
	await get_tree().create_timer(3.0).timeout
	queue_free()

func _physics_process(delta):
	position -= transform.basis.z * velocidade * delta

func _on_body_entered(body):
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
	
	if body.has_method("receber_dano"):
		body.receber_dano(dano_final, global_position)
	queue_free()
