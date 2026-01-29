extends Node

# Variável que guarda a escolha do jogador
var dificuldade_selecionada = "Normal"

# Configurações de cada nível
# Vida do Player | Multiplicador de Dano recebido | Munição Inicial Extra
var configuracoes = {
	"Casual": { 
		"vida": 200, 
		"dano_inimigo": 0.5, # Inimigo dá metade do dano
		"municao_extra": 30 
	},
	"Normal": { 
		"vida": 100, 
		"dano_inimigo": 1.0, # Dano normal
		"municao_extra": 0 
	},
	"Sobrevivente": { 
		"vida": 50, 
		"dano_inimigo": 2.0, # Inimigo dá o dobro de dano
		"municao_extra": -10 # Começa com menos bala
	}
}
