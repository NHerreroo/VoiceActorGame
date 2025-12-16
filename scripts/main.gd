extends Node

var current_scene

func _ready():
	load_scene("res://scenes/Lobby.tscn")

func load_scene(path):
	if current_scene:
		current_scene.queue_free()
	current_scene = load(path).instantiate()
	add_child(current_scene)
