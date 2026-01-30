extends Control

var cena_do_jogo = "res://NivelCasa.tscn" 
@onready var menu_principal = $MenuPrincipal
@onready var menu_dificuldade = $MenuDificuldade

func _ready():
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	menu_principal.visible = true
	menu_dificuldade.visible = false

func _on_jogar_pressed():
	menu_principal.visible = false
	menu_dificuldade.visible = true

func _on_sair_pressed():
	get_tree().quit()
func _on_btn_casual_pressed():
	iniciar_jogo("Casual")

func _on_btn_normal_pressed():
	iniciar_jogo("Normal")

func _on_btn_sobrevivente_pressed():
	iniciar_jogo("Sobrevivente")

func _on_btn_voltar_pressed():
	menu_dificuldade.visible = false
	menu_principal.visible = true
func iniciar_jogo(dificuldade_escolhida):
	Global.dificuldade_selecionada = dificuldade_escolhida
	print("Iniciando modo: ", dificuldade_escolhida)
	get_tree().change_scene_to_file("res://cenas/nivel_casa.tscn")


func _on_creditos_pressed() -> void:
	get_tree().change_scene_to_file("res://cenas/tela_creditos.tscn")
