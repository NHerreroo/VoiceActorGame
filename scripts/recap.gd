extends Control

func _ready():
	$RecapLabel.text = "RECAP FINAL"
	show_results()

func show_results():
	for id in GameManager.drawings.keys():
		print("Mostrando dibujo de:", id)
		await get_tree().create_timer(2).timeout
