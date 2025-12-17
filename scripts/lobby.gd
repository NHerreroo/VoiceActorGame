extends Control

@onready var ip_input = $VBoxContainer/IPInput
@onready var start_button = $VBoxContainer/StartButton

@onready var mic_selector: OptionButton = $VBoxContainer/MicOptionButton
@onready var test_mic_button: Button = $VBoxContainer/TestMicButton
@onready var audio_player: AudioStreamPlayer = $VBoxContainer/AudioStreamPlayer

@onready var mic_player: AudioStreamPlayer = $VBoxContainer/AudioStreamPlayer_Mic
@onready var playback_player: AudioStreamPlayer = $VBoxContainer/AudioStreamPlayer_Play

var mic_stream: AudioStreamMicrophone
var record_effect: AudioEffectRecord
var recorded_audio: AudioStreamWAV

var mic_bus_index := -1
var monitoring := false


func _ready():
	start_button.visible = false
	_setup_microphones()

	mic_bus_index = AudioServer.get_bus_index("Mic")
	record_effect = AudioServer.get_bus_effect(mic_bus_index, 0)



# ----------------------------------------
# MICRÓFONOS
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
	print("Mic activo:", device)

# ----------------------------------------
# TEST MIC
# ----------------------------------------

func _on_test_mic_pressed():
	print("🎤 TEST MIC INICIADO (habla ahora)")

	mic_stream = AudioStreamMicrophone.new()
	mic_player.stream = mic_stream

	record_effect.set_recording_active(true)
	mic_player.play()

	monitoring = true
	_monitor_mic_level()

	await get_tree().create_timer(3.0).timeout

	monitoring = false
	mic_player.stop()
	mic_player.stream = null
	record_effect.set_recording_active(false)

	print("🛑 TEST MIC FINALIZADO")

func _monitor_mic_level():
	if not monitoring:
		return

	var left_db = AudioServer.get_bus_peak_volume_left_db(mic_bus_index, 0)
	var right_db = AudioServer.get_bus_peak_volume_right_db(mic_bus_index, 0)

	# Convertimos dB a un valor más legible (0–100)
	var level = int(clamp((left_db + 60) * 2, 0, 100))

	# Barra visual por consola
	var bars = int(level / 5)
	var meter = "|".repeat(bars)

	print("MIC LEVEL:", left_db, "dB ", meter)

	await get_tree().create_timer(0.1).timeout
	_monitor_mic_level()


func _play_recording():
	playback_player.stream = recorded_audio
	playback_player.play()


# ----------------------------------------
# TU CÓDIGO ORIGINAL (SIN TOCAR)
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
	print("START PULSADO (HOST)")
	rpc("start_draw_phase")

@rpc("any_peer", "call_local")
func start_draw_phase():
	print("CAMBIO A DRAW EN PEER:", multiplayer.get_unique_id())
	GameManager.current_phase = GameManager.Phase.DRAW
	get_tree().change_scene_to_file("res://scenes/DrawingRound.tscn")
