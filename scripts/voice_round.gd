# FILE: scripts/voice_round.gd
extends Control

@onready var info_label = $InfoLabel
@onready var drawing_texture = $DrawingTexture
@onready var timer_label = $TimerLabel
@onready var record_button = $ButtonContainer/RecordButton
@onready var stop_button = $ButtonContainer/StopButton
@onready var play_button = $ButtonContainer/PlayButton
@onready var confirm_button = $ButtonContainer/FinishButton

var current_audio = null
var is_recording := false
var recording_time := 0
var max_recording_time := 10
var voice_finished := false  # NUEVA: para evitar múltiples envíos

func _ready():
	# Resetear estado de voz
	voice_finished = false
	
	# Configurar UI inicial
	record_button.visible = true
	stop_button.visible = false
	play_button.visible = false
	confirm_button.disabled = true
	
	# Si es host, limpiar lista de jugadores terminados
	if GameManager.is_host:
		GameManager.voice_finished_players.clear()
	
	# Mostrar el primer dibujo
	show_next_drawing()

func show_next_drawing():
	if GameManager.has_more_drawings():
		var image_data: PackedByteArray = GameManager.get_current_drawing()
		var player_id = GameManager.get_current_player_id()
		
		# Verificar que tenemos datos válidos
		if image_data != null and image_data.size() > 0:
			# Crear imagen desde los datos
			var image = Image.new()
			var error = image.load_png_from_buffer(image_data)
			
			if error == OK:
				# Crear textura
				var texture = ImageTexture.create_from_image(image)
				drawing_texture.texture = texture
				
				info_label.text = "Dibujo de jugador " + str(player_id) + "\n\nGrabar tu voz para este dibujo"
				info_label.text += "\nDibujo " + str(GameManager.current_drawing_index + 1) + " de " + str(GameManager.drawings_to_record.size())
			else:
				info_label.text = "Error cargando dibujo. Código: " + str(error)
				print("ERROR al cargar PNG: ", error)
		else:
			info_label.text = "No hay datos de imagen disponibles"
			print("Sin datos de imagen para jugador ", player_id)
	else:
		info_label.text = "¡Todos los dibujos completados!"
		confirm_button.text = "Terminar Ronda"
		drawing_texture.visible = false

func _on_RecordButton_pressed():
	start_recording()

func start_recording():
	is_recording = true
	recording_time = 0
	record_button.visible = false
	stop_button.visible = true
	play_button.visible = false
	confirm_button.disabled = true
	
	info_label.text = "Grabando... Habla ahora!"
	
	# Iniciar temporizador visual
	_update_timer()

func stop_recording():
	is_recording = false
	record_button.visible = true
	stop_button.visible = false
	play_button.visible = true
	confirm_button.disabled = false
	
	info_label.text = "Grabación completada. Puedes escucharla o confirmar."

func _on_StopButton_pressed():
	stop_recording()

func _on_PlayButton_pressed():
	# Reproducir audio grabado
	info_label.text = "Reproduciendo grabación..."
	# Aquí iría la lógica para reproducir el audio
	await get_tree().create_timer(1).timeout
	info_label.text = "Grabación completada. Puedes escucharla o confirmar."

func _on_FinishButton_pressed():
	if voice_finished:
		return
	
	if GameManager.has_more_drawings():
		# Guardar la voz para este dibujo
		var drawing_id = GameManager.get_current_player_id()
		save_voice_for_drawing(drawing_id)
		
		# Pasar al siguiente dibujo
		if GameManager.next_drawing():
			show_next_drawing()
			# Resetear botones
			record_button.visible = true
			stop_button.visible = false
			play_button.visible = false
			confirm_button.disabled = true
		else:
			# Todos los dibujos completados
			voice_finished = true
			finish_voice_round()
	else:
		# Terminar ronda
		voice_finished = true
		finish_voice_round()

func save_voice_for_drawing(drawing_id: int):
	# Aquí guardarías el audio grabado
	# Por ahora solo marcamos que está completado
	print("Voz guardada para dibujo de jugador ", drawing_id)

func finish_voice_round():
	var my_id = multiplayer.get_unique_id()
	print("Jugador terminó ronda de voz:", my_id)
	
	# Marcar como terminado
	if GameManager.is_host:
		host_player_finished_voice(my_id)
	else:
		rpc_id(1, "player_finished_voice", my_id)
	
	info_label.text = "Esperando a que otros terminen..."

@rpc("any_peer")
func player_finished_voice(player_id: int):
	if not GameManager.is_host:
		return
	
	host_player_finished_voice(player_id)

func host_player_finished_voice(player_id: int):
	if player_id in GameManager.voice_finished_players:
		return
	
	GameManager.voice_finished_players.append(player_id)
	print(
		"HOST: terminados voz ",
		GameManager.voice_finished_players.size(),
		"/",
		get_total_players()
	)
	check_if_all_finished_voice()

func check_if_all_finished_voice():
	if GameManager.voice_finished_players.size() >= get_total_players():
		print("TODOS TERMINARON LA RONDA DE VOZ")
		# Enviar a todos los jugadores al recap
		rpc("start_recap")

func get_total_players() -> int:
	return multiplayer.get_peers().size() + 1

func _update_timer():
	if is_recording:
		recording_time += 1
		timer_label.text = "Tiempo: " + str(recording_time) + "s / " + str(max_recording_time) + "s"
		
		if recording_time >= max_recording_time:
			stop_recording()
		
		await get_tree().create_timer(1).timeout
		_update_timer()

@rpc("authority", "call_local")
func start_recap():
	GameManager.current_phase = GameManager.Phase.RECAP
	get_tree().change_scene_to_file("res://scenes/Recap.tscn")
