extends Node
var dificuldade_selecionada = "Normal"
func get_zumbi_vida():
	match dificuldade_selecionada:
		"Casual": return 10
		"Normal": return 20 
		"Sobrevivente": return 30
	return 20

func get_mutante_vida():
	match dificuldade_selecionada:
		"Casual": return 120
		"Normal": return 200
		"Sobrevivente": return 280
	return 200

func get_zumbi_velocidade_mult():
	match dificuldade_selecionada:
		"Casual": return 0.95
		"Normal": return 1.0
		"Sobrevivente": return 1.05
	return 1.0
