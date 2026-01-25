extends Area3D

# Qual arma esse item entrega?
@export_enum("Pistola", "SMG", "Shotgun") var nome_arma = "Shotgun"

func _ready():
	body_entered.connect(_on_body_entered)

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
		
		queue_free() # Some com o item do chão
