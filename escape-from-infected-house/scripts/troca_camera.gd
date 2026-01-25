extends Area3D

@export var camera_alvo : Camera3D

func _on_body_entered(body):
	if body.name == "Player":
		camera_alvo.make_current()
