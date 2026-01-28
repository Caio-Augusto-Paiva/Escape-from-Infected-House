extends Area3D

@export_enum("Pistola", "SMG", "Shotgun") var tipo_municao : String = "Pistola"
@export var quantidade : int = 20

# --- CARREGANDO OS MATERIAIS NA MEMÓRIA ---
# Se os nomes dos seus arquivos forem diferentes, corrija dentro das aspas!
var material_pistola = preload("res://Materiais/Mat_Municao_Pistola.tres")
var material_smg = preload("res://Materiais/Mat_Municao_SMG.tres")
var material_shotgun = preload("res://Materiais/Mat_Municao_Shotgun.tres")

@onready var visual = $MeshInstance3D

func _ready():
	# Configura a cor automaticamente ao iniciar o jogo
	atualizar_cor()
	
	body_entered.connect(_on_body_entered)

func atualizar_cor():
	# Verifica qual opção foi escolhida no Inspector e troca o material
	match tipo_municao:
		"Pistola":
			visual.material_override = material_pistola
		"SMG":
			visual.material_override = material_smg
		"Shotgun":
			visual.material_override = material_shotgun

func _on_body_entered(body):
	if body.name == "Player":
		body.coletar_municao(tipo_municao, quantidade)
		queue_free()
