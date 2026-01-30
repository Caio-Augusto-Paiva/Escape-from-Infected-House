extends Control

@onready var texto = $TextoRolante
var velocidade = 50.0 

func _process(delta):
	texto.position.y -= velocidade * delta

	if texto.position.y < -texto.size.y - 50:
		voltar_menu()

func _on_button_pressed() -> void:
	voltar_menu()

func voltar_menu():
	get_tree().change_scene_to_file("res://cenas/menu_inicial.tscn")
