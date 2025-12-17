# FILE: scripts/voice_round.gd
extends Control

@onready var info_label = $InfoLabel
@onready var drawing_texture = $DrawingTexture
@onready var timer_label = $TimerLabel
@onready var record_button = $ButtonContainer/RecordButton
@onready var stop_button = $ButtonContainer/StopButton
@onready var play_button = $ButtonContainer/PlayButton
@onready var confirm_button = $ButtonContainer/FinishButton
@onready var mic_player = $AudioStreamPlayer_Mic
@onready var play_player = $AudioStreamPlayer_Play

var record_effect: AudioEffectRecord
var mic_stream: AudioStreamMicrophone
var is_recording := false
var recording_time := 0
var max_recording_time := 10
var voice_finished := false
var current_audio_data: PackedByteArray = PackedByteArray()

func _ready():
	# Obtener el efecto de grabación del bus "Mic"
	var mic_bus_index = AudioServer.get_bus_index("Mic")
	record_effect = AudioServer.get_bus_effect(mic_bus_index, 0)
	
	# Resetear estado de voz
	voice_finished = false
	current_audio_data = PackedByteArray()
	
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
	# Resetear audio actual
	current_audio_data = PackedByteArray()
	play_button.disabled = true
	
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
	if is_recording:
		return
	
	is_recording = true
	recording_time = 0
	current_audio_data = PackedByteArray()  # Limpiar audio anterior
	
	# Configurar UI
	record_button.visible = false
	stop_button.visible = true
	play_button.visible = false
	play_button.disabled = true
	confirm_button.disabled = true
	
	info_label.text = "Grabando... Habla ahora!"
	
	# Iniciar grabación
	record_effect.set_recording_active(true)
	
	# Configurar stream de micrófono para monitoreo
	mic_stream = AudioStreamMicrophone.new()
	mic_player.stream = mic_stream
	mic_player.play()
	
	# Iniciar temporizador visual
	_update_timer()

func stop_recording():
	if not is_recording:
		return
	
	is_recording = false
	
	# Detener grabación
	record_effect.set_recording_active(false)
	mic_player.stop()
	mic_player.stream = null
	
	# Obtener datos de audio grabados
	var recording = record_effect.get_recording()
	if recording:
		current_audio_data = recording.get_data()
		print("Audio grabado: ", current_audio_data.size(), " bytes")
		
		if current_audio_data.size() > 0:
			play_button.disabled = false
		else:
			print("ADVERTENCIA: Audio grabado vacío")
	else:
		print("ERROR: No se pudo obtener la grabación")
	
	# Actualizar UI
	record_button.visible = true
	stop_button.visible = false
	play_button.visible = true
	confirm_button.disabled = false
	
	info_label.text = "Grabación completada. Puedes escucharla o confirmar."

func _on_StopButton_pressed():
	stop_recording()

func _on_PlayButton_pressed():
	if current_audio_data.size() == 0:
		info_label.text = "No hay audio para reproducir"
		return
	
	info_label.text = "Reproduciendo grabación..."
	
	# Crear stream de audio desde los datos
	var audio_stream = AudioStreamWAV.new()
	audio_stream.data = current_audio_data
	audio_stream.format = AudioStreamWAV.FORMAT_16_BITS
	audio_stream.mix_rate = 44100
	audio_stream.stereo = true
	
	# Configurar y reproducir
	play_player.stream = audio_stream
	play_player.play()
	
	# Esperar a que termine la reproducción
	await play_player.finished
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
			play_button.disabled = true
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
	if current_audio_data.size() == 0:
		print("ADVERTENCIA: No hay audio para guardar para el dibujo ", drawing_id)
		# Crear audio vacío de prueba
		current_audio_data = create_silent_audio()
	
	# Guardar localmente
	GameManager.voices[drawing_id] = current_audio_data
	print("Voz guardada localmente para dibujo de jugador ", drawing_id, " (", current_audio_data.size(), " bytes)")
	
	# Enviar al host
	var my_id = multiplayer.get_unique_id()
	rpc_id(1, "submit_voice", drawing_id, my_id, current_audio_data)

func create_silent_audio() -> PackedByteArray:
	# Crear 1 segundo de silencio (16-bit stereo, 44100 Hz)
	var silent_data = PackedByteArray()
	var samples = 44100 * 2 * 2  # 44100 samples/sec * 2 bytes/sample * 2 channels
	silent_data.resize(samples)
	
	# Rellenar con ceros (silencio)
	for i in range(samples):
		silent_data[i] = 0
	
	return silent_data

func finish_voice_round():
	var my_id = multiplayer.get_unique_id()
	print("Jugador terminó ronda de voz:", my_id)
	
	# Marcar como terminado
	if GameManager.is_host:
		host_player_finished_voice(my_id)
	else:
		rpc_id(1, "player_finished_voice", my_id)
	
	info_label.text = "Esperando a que otros terminen..."
	confirm_button.disabled = true

@rpc("any_peer")
func submit_voice(drawing_id: int, sender_id: int, audio_data: PackedByteArray):
	if not GameManager.is_host:
		return
	
	print("HOST: Recibida voz para dibujo ", drawing_id, " de jugador ", sender_id)
	GameManager.voices[drawing_id] = audio_data

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
		
		# Configurar el Recap antes de enviar a todos
		GameManager.setup_recap()
		
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
			info_label.text = "¡Tiempo máximo alcanzado!"
		
		await get_tree().create_timer(1).timeout
		_update_timer()

func _on_RecordButton_mouse_entered():
	if not record_button.disabled:
		record_button.modulate = Color(0.8, 0.8, 1.0, 1.0)

func _on_RecordButton_mouse_exited():
	record_button.modulate = Color(1.0, 1.0, 1.0, 1.0)

@rpc("authority", "call_local")
func start_recap():
	GameManager.current_phase = GameManager.Phase.RECAP
	get_tree().change_scene_to_file("res://scenes/Recap.tscn")
