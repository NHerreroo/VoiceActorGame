extends Control

func _ready():
	$InfoLabel.text = "Grabando voces..."

func _on_FinishButton_pressed():
	if GameManager.is_host:
		rpc("start_recap")

@rpc("authority")
func start_recap():
	GameManager.current_phase = GameManager.Phase.RECAP
	get_tree().change_scene_to_file("res://scenes/Recap.tscn")
