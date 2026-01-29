extends Control

func _on_btn_menu_pressed():
	# Despausa o jogo antes de sair (muito importante!)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://cenas/menu_inicial.tscn")

func _on_btn_sair_pressed():
	get_tree().quit()
