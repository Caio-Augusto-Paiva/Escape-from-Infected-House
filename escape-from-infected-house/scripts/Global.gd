extends Node

# Variável que guarda a escolha do jogador
var dificuldade_selecionada = "Normal"

# Configurações de cada nível
# Vida do Zumbi (10 HP = 1 tiro de pistola)
func get_zumbi_vida():
	match dificuldade_selecionada:
		"Casual": return 10
		"Normal": return 20 
		"Sobrevivente": return 30
	return 20

# Vida do Mutante (40 HP = 1 tiro de shotgun medio alcance)
func get_mutante_vida():
	match dificuldade_selecionada:
		"Casual": return 120 # 3 tiros
		"Normal": return 200 # 5 tiros
		"Sobrevivente": return 320 # 8 tiros
	return 200

# Velocidade do Zumbi (mudanca minima)
func get_zumbi_velocidade_mult():
	match dificuldade_selecionada:
		"Casual": return 0.95
		"Normal": return 1.0
		"Sobrevivente": return 1.05
	return 1.0
