extends Area3D

@export var velocidade = 50.0
@export var dano = 10

func _ready():
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
	
	# Se o objeto tiver vida, aplica dano
	if body.has_method("receber_dano"):
		body.receber_dano(dano, global_position)
	
	# Destroi a bala ao bater
	queue_free()
