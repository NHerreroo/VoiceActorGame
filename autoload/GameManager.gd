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
var voice_assignments := {}

var current_drawing_index := 0
var drawings_to_record := []  # IDs de los dibujos que este jugador debe grabar

func reset_game():
	drawings.clear()
	voices.clear()
	drawings_submitted.clear()
	voice_finished_players.clear()  # AÑADIDO
	current_drawing_index = 0
	drawings_to_record.clear()

func reset_voice_phase():  # NUEVA FUNCIÓN
	voice_finished_players.clear()
	current_drawing_index = 0

# Guardar dibujo localmente
func save_local_drawing(image_data: PackedByteArray):
	var my_id = multiplayer.get_unique_id()
	drawings[my_id] = image_data

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

# En GameManager.gd, añade estas funciones:

# Guardar audio localmente
func save_local_voice(drawing_id: int, audio_data: PackedByteArray):
	voices[drawing_id] = audio_data
	print("Audio guardado para dibujo ", drawing_id, " (", audio_data.size(), " bytes)")

# Obtener el audio de un dibujo específico
func get_voice_for_drawing(drawing_id: int) -> PackedByteArray:
	return voices.get(drawing_id, PackedByteArray())

func add_voice_assignment(drawing_id: int, voice_owner_id: int):
	if not voice_assignments.has(drawing_id):
		voice_assignments[drawing_id] = []
	
	if not voice_owner_id in voice_assignments[drawing_id]:
		voice_assignments[drawing_id].append(voice_owner_id)

func get_voices_for_drawing(drawing_id: int) -> Array:
	return voice_assignments.get(drawing_id, [])

# En la función submit_voice (en voice_round.gd), añadir:
func submit_voice(drawing_id: int, sender_id: int, audio_data: PackedByteArray):
	if not GameManager.is_host:
		return
	
	print("HOST: Recibida voz para dibujo ", drawing_id, " de jugador ", sender_id)
	GameManager.voices[drawing_id] = audio_data
	GameManager.add_voice_assignment(drawing_id, sender_id)  # AÑADE ESTA LÍNEA
