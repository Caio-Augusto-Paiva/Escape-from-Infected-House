extends Control

var cena_do_jogo = "res://NivelCasa.tscn" 

# Referências aos dois containers (Caudas de Dragão)
@onready var menu_principal = $MenuPrincipal
@onready var menu_dificuldade = $MenuDificuldade

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Garante que o jogo comece com o menu principal visível e o outro escondido
	menu_principal.visible = true
	menu_dificuldade.visible = false

# --- BOTÕES DO MENU PRINCIPAL ---

func _on_jogar_pressed():
	# Esconde o principal e mostra as dificuldades
	menu_principal.visible = false
	menu_dificuldade.visible = true

func _on_sair_pressed():
	get_tree().quit()

# --- BOTÕES DE DIFICULDADE ---

func _on_btn_casual_pressed():
	iniciar_jogo("Casual")

func _on_btn_normal_pressed():
	iniciar_jogo("Normal")

func _on_btn_sobrevivente_pressed():
	iniciar_jogo("Sobrevivente")

func _on_btn_voltar_pressed():
	# Cancela e volta para o menu principal
	menu_dificuldade.visible = false
	menu_principal.visible = true

# --- FUNÇÃO AUXILIAR PARA NÃO REPETIR CÓDIGO ---
func iniciar_jogo(dificuldade_escolhida):
	# Salva no Global e carrega a cena
	Global.dificuldade_selecionada = dificuldade_escolhida
	print("Iniciando modo: ", dificuldade_escolhida)
	get_tree().change_scene_to_file("res://cenas/nivel_casa.tscn")


func _on_creditos_pressed() -> void:
	get_tree().change_scene_to_file("res://cenas/tela_creditos.tscn")
