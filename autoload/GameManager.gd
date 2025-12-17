# FILE: autoload/GameManager.gd
extends Node

enum Phase { LOBBY, DRAW, VOICE, RECAP }

var current_phase := Phase.LOBBY
var is_host := false
var room_code := ""

var finished_players := []
var drawings_submitted := []  # IDs de jugadores que ya enviaron dibujos

# Nueva variable para la ronda de voz
var voice_finished_players := []  # IDs de jugadores que terminaron la ronda de voz

var players := {}      # peer_id -> name
var drawings := {}     # peer_id -> PackedByteArray (datos PNG)
var voices := {}       # drawing_id -> PackedByteArray (datos de audio)

var current_drawing_index := 0
var drawings_to_record := []  # IDs de los dibujos que este jugador debe grabar

# Variables para micrófono
var available_mics := []  # Nombres de micrófonos disponibles
var selected_mic := ""    # Micrófono seleccionado

func reset_game():
	drawings.clear()
	voices.clear()
	drawings_submitted.clear()
	voice_finished_players.clear()
	current_drawing_index = 0
	drawings_to_record.clear()

func reset_voice_phase():
	voice_finished_players.clear()
	current_drawing_index = 0

# Guardar dibujo localmente
func save_local_drawing(image_data: PackedByteArray):
	var my_id = multiplayer.get_unique_id()
	drawings[my_id] = image_data
	print("Dibujo guardado para jugador ", my_id, " (", image_data.size(), " bytes)")

# Guardar voz localmente
func save_local_voice(drawing_id: int, audio_data: PackedByteArray):
	voices[drawing_id] = audio_data
	print("Voz guardada para dibujo ", drawing_id, " (", audio_data.size(), " bytes)")

# Obtener la lista de dibujos a grabar (excluyendo el propio)
func setup_voice_round():
	var my_id = multiplayer.get_unique_id()
	drawings_to_record.clear()
	
	for player_id in drawings.keys():
		if player_id != my_id:
			drawings_to_record.append(player_id)
	
	print("Dibujos a grabar: ", drawings_to_record)
	current_drawing_index = 0

# Obtener el dibujo actual para grabar
func get_current_drawing() -> PackedByteArray:
	if drawings_to_record.size() == 0:
		return PackedByteArray()
	
	if current_drawing_index >= drawings_to_record.size():
		return PackedByteArray()
	
	var player_id = drawings_to_record[current_drawing_index]
	return drawings.get(player_id, PackedByteArray())

func get_current_player_id() -> int:
	if current_drawing_index >= drawings_to_record.size():
		return -1
	return drawings_to_record[current_drawing_index]

func next_drawing() -> bool:
	current_drawing_index += 1
	return current_drawing_index < drawings_to_record.size()

func has_more_drawings() -> bool:
	return current_drawing_index < drawings_to_record.size()

# Funciones para micrófono
func get_available_microphones() -> Array:
	available_mics.clear()
	
	# Obtener todos los dispositivos de captura
	var capture_devices = AudioServer.get_input_device_list()
	
	for device in capture_devices:
		available_mics.append(device)
	
	print("Micrófonos disponibles: ", available_mics)
	
	# Si hay micrófonos, seleccionar el primero por defecto
	if available_mics.size() > 0 and selected_mic == "":
		selected_mic = available_mics[0]
		print("Micrófono seleccionado por defecto: ", selected_mic)
	
	return available_mics

func set_microphone(mic_name: String) -> bool:
	if mic_name in available_mics:
		AudioServer.set_input_device(mic_name)
		selected_mic = mic_name
		print("Micrófono configurado: ", mic_name)
		return true
	else:
		print("Error: Micrófono no disponible: ", mic_name)
		return false

func get_current_microphone() -> String:
	return AudioServer.get_input_device()
