extends Control

@onready var texto = $TextoRolante
var velocidade = 50.0 # Pixels por segundo

func _process(delta):
	# Faz o texto subir
	texto.position.y -= velocidade * delta
	
	# Se o texto sumir lá no topo, volta pro menu
	# O "-texto.size.y" é a altura total do texto
	if texto.position.y < -texto.size.y - 50:
		voltar_menu()

func _on_button_pressed() -> void:
	voltar_menu()

func voltar_menu():
	get_tree().change_scene_to_file("res://cenas/menu_inicial.tscn")
