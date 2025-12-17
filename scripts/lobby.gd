extends Control

# ----------------------------------------
# UI
# ----------------------------------------

@onready var ip_input: LineEdit = $VBoxContainer/IPInput
@onready var start_button: Button = $VBoxContainer/StartButton

@onready var mic_selector: OptionButton = $VBoxContainer/MicOptionButton
@onready var test_button: Button = $VBoxContainer/TestMicButton

@onready var mic_player: AudioStreamPlayer = $VBoxContainer/AudioStreamPlayer_Mic


# ----------------------------------------
# MIC TEST
# ----------------------------------------

var mic_stream: AudioStreamMicrophone
var record_effect: AudioEffectRecord
var testing := false


# ----------------------------------------
# READY
# ----------------------------------------

func _ready():
	start_button.visible = false
	_setup_microphones()

	var mic_bus_index = AudioServer.get_bus_index("Mic")
	record_effect = AudioServer.get_bus_effect(mic_bus_index, 0)


# ----------------------------------------
# MIC SETUP
# ----------------------------------------

func _setup_microphones():
	mic_selector.clear()

	var devices = AudioServer.get_input_device_list()
	for d in devices:
		mic_selector.add_item(d)

	if devices.size() > 0:
		mic_selector.select(0)
		AudioServer.input_device = devices[0]

	mic_selector.item_selected.connect(_on_mic_selected)


func _on_mic_selected(index: int):
	var device = mic_selector.get_item_text(index)
	AudioServer.input_device = device


# ----------------------------------------
# TEST MIC (TOGGLE)
# ----------------------------------------

func _on_test_mic_pressed():
	if testing:
		_stop_mic_test()
	else:
		_start_mic_test()


func _start_mic_test():
	testing = true
	test_button.text = "Stop Test"

	mic_stream = AudioStreamMicrophone.new()
	mic_player.stream = mic_stream

	record_effect.set_recording_active(true)
	mic_player.play()


func _stop_mic_test():
	testing = false
	test_button.text = "Test Mic"

	mic_player.stop()
	mic_player.stream = null
	record_effect.set_recording_active(false)


# ----------------------------------------
# MULTIPLAYER (TU CÓDIGO ORIGINAL)
# ----------------------------------------

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
	rpc("start_draw_phase")


@rpc("any_peer", "call_local")
func start_draw_phase():
	GameManager.current_phase = GameManager.Phase.DRAW
	get_tree().change_scene_to_file("res://scenes/DrawingRound.tscn")
