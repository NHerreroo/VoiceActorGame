extends Control

@onready var ip_input = $VBoxContainer/IPInput
@onready var start_button = $VBoxContainer/StartButton

func _ready():
	start_button.visible = false

func _on_host_button_pressed() -> void:
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(12345, 8)
	multiplayer.multiplayer_peer = peer

	GameManager.is_host = true
	GameManager.room_code = "1234"
	start_button.visible = true

func _on_JoinButton_pressed():
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(ip_input.text, 12345)
	multiplayer.multiplayer_peer = peer

func _on_StartButton_pressed():
	print("START PULSADO (HOST)")
	rpc("start_draw_phase")


@rpc("any_peer", "call_local")
func start_draw_phase():
	print("CAMBIO A DRAW EN PEER:", multiplayer.get_unique_id())
	GameManager.current_phase = GameManager.Phase.DRAW
	get_tree().change_scene_to_file("res://scenes/DrawingRound.tscn")
