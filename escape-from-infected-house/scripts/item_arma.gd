extends Area3D

# Qual arma esse item entrega?
@export_enum("Pistola", "SMG", "Shotgun") var nome_arma = "Shotgun"

@onready var vis_pistola = $Visual_Pistola
@onready var vis_smg = $Visual_SMG
@onready var vis_shotgun = $Visual_Shotgun

func _ready():
	body_entered.connect(_on_body_entered)
	atualizar_visual()

func atualizar_visual():
	# Esconde todas as armas
	if vis_pistola: vis_pistola.visible = false
	if vis_smg: vis_smg.visible = false
	if vis_shotgun: vis_shotgun.visible = false
	
	# Mostra a arma correta
	match nome_arma:
		"Pistola":
			if vis_pistola: vis_pistola.visible = true
		"SMG":
			if vis_smg: vis_smg.visible = true
		"Shotgun":
			if vis_shotgun: vis_shotgun.visible = true

func _on_body_entered(body):
	if body.name == "Player":
		# CORREÇÃO: Mudamos de '.inventory' para '.inventario'
		if body.inventario.has(nome_arma):
			print("Já tenho essa arma!")
			return 
			
		print("Pegou: " + nome_arma)
		
		# Adiciona na lista 'inventario' do player
		body.inventario.append(nome_arma) 
		
		# Equipa a arma nova automaticamente
		# (O índice da nova arma é o tamanho da lista - 1)
		body.arma_atual_index = body.inventario.size() - 1
		
		# Atualiza o visual da arma
		if body.has_method("atualizar_visual_arma"):
			body.atualizar_visual_arma()
		
		queue_free() # Some com o item do chão
