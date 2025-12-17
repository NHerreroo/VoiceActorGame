# FILE: scripts/voice_round.gd
extends Control

@onready var info_label: Label = $InfoLabel
@onready var drawing_texture: TextureRect = $DrawingTexture
@onready var timer_label: Label = $TimerLabel
@onready var mic_info: Label = $MicInfo
@onready var record_button: Button = $ButtonContainer/RecordButton
@onready var stop_button: Button = $ButtonContainer/StopButton
@onready var play_button: Button = $ButtonContainer/PlayButton
@onready var confirm_button: Button = $ButtonContainer/FinishButton
@onready var audio_player: AudioStreamPlayer = $AudioPlayer

# Variables de audio
var is_recording := false
var recording_time := 0
var max_recording_time := 10
var voice_finished := false

# Datos de la grabación actual
var current_audio_data: PackedByteArray

func _ready():
	print("=== VOICE ROUND INICIADO ===")
	print("  - Jugador ID: ", multiplayer.get_unique_id())
	print("  - Es host: ", GameManager.is_host)
	
	# Verificar dispositivos de audio
	print("Verificando dispositivos de audio...")
	var input_devices = AudioServer.get_input_device_list()
	print("  - Dispositivos de entrada disponibles: ", input_devices)
	print("  - Dispositivo actual: ", AudioServer.get_input_device())
	print("  - Dispositivo de salida actual: ", AudioServer.get_output_device())
	
	# Verificar buses de audio
	print("Verificando buses de audio...")
	for i in range(AudioServer.get_bus_count()):
		print("  - Bus ", i, ": ", AudioServer.get_bus_name(i))
	
	# Configurar micrófono
	if GameManager.selected_mic != "":
		AudioServer.set_input_device(GameManager.selected_mic)
		print("  - Micrófono configurado: ", GameManager.selected_mic)
		mic_info.text = "Mic: " + GameManager.selected_mic
	else:
		# Si no hay micrófono seleccionado, usar el primero disponible
		var mics = AudioServer.get_input_device_list()
		if mics.size() > 0:
			GameManager.selected_mic = mics[0]
			AudioServer.set_input_device(GameManager.selected_mic)
			mic_info.text = "Mic: " + GameManager.selected_mic
			print("  - Micrófono automático seleccionado: ", GameManager.selected_mic)
	
	# Asegurar que GameManager tiene el sistema de audio configurado
	if not GameManager.audio_effect_record:
		GameManager.setup_audio_system()
	
	# Configurar audio player
	audio_player.bus = "Master"
	audio_player.volume_db = 0.0
	audio_player.finished.connect(_on_playback_finished)
	
	# Configurar UI inicial
	record_button.visible = true
	record_button.disabled = false
	stop_button.visible = false
	play_button.visible = false
	play_button.disabled = true
	confirm_button.disabled = true
	
	# Si es host, limpiar lista de jugadores terminados
	if GameManager.is_host:
		GameManager.voice_finished_players.clear()
		print("  - Host: lista de jugadores de voz limpiada")
	
	# Mostrar el primer dibujo
	show_next_drawing()
	
	print("✓ Voice Round listo")

func show_next_drawing():
	print("Mostrando siguiente dibujo...")
	
	if GameManager.has_more_drawings():
		var image_data: PackedByteArray = GameManager.get_current_drawing()
		var player_id = GameManager.get_current_player_id()
		
		print("  - Dibujo actual: ", GameManager.current_drawing_index + 1, " de ", GameManager.drawings_to_record.size())
		print("  - ID del jugador del dibujo: ", player_id)
		
		# Limpiar grabación anterior
		current_audio_data = PackedByteArray()
		
		# Verificar que tenemos datos válidos
		if image_data != null and image_data.size() > 0:
			# Crear imagen desde los datos
			var image = Image.new()
			var error = image.load_png_from_buffer(image_data)
			
			if error == OK:
				# Crear textura
				var texture = ImageTexture.create_from_image(image)
				drawing_texture.texture = texture
				
				info_label.text = "Dibujo del jugador " + str(player_id) + "\n\n" + \
								"🎤 Graba tu voz para este dibujo\n\n" + \
								"Dibujo " + str(GameManager.current_drawing_index + 1) + " de " + str(GameManager.drawings_to_record.size())
				
				print("✓ Dibujo cargado correctamente")
				
			else:
				info_label.text = "❌ Error cargando dibujo\nCódigo: " + str(error)
				print("✗ ERROR al cargar PNG: ", error)
				
		else:
			info_label.text = "⚠ No hay datos de imagen disponibles"
			print("✗ Sin datos de imagen para jugador ", player_id)
			
	else:
		info_label.text = "✅ ¡Todos los dibujos completados!\n\nEsperando a otros jugadores..."
		confirm_button.text = "🏁 Terminar Ronda"
		drawing_texture.visible = false
		print("✓ Todos los dibujos han sido procesados")

func start_recording():
	if is_recording:
		print("⚠ Ya se está grabando")
		return
	
	print("Iniciando grabación de voz...")
	
	# Configurar dispositivo de micrófono
	if GameManager.selected_mic != "":
		AudioServer.set_input_device(GameManager.selected_mic)
		print("  - Micrófono configurado: ", GameManager.selected_mic)
	
	# Activar grabación usando GameManager
	if GameManager.start_recording():
		is_recording = true
		recording_time = 0
		
		# Actualizar UI
		record_button.visible = false
		record_button.disabled = true
		stop_button.visible = true
		stop_button.disabled = false
		play_button.visible = false
		play_button.disabled = true
		confirm_button.disabled = true
		
		info_label.text = "🎤 GRABANDO... Habla ahora!\n\n" + \
						"Dibujo " + str(GameManager.current_drawing_index + 1) + " de " + str(GameManager.drawings_to_record.size())
		
		timer_label.text = "Tiempo: 0s / " + str(max_recording_time) + "s"
		
		print("✓ Grabación iniciada")
		
		# Iniciar temporizador
		_update_timer()
	else:
		print("✗ Error al iniciar la grabación")
		info_label.text = "❌ Error al iniciar la grabación\n\nVerifica tu micrófono"

func stop_recording():
	if not is_recording:
		print("⚠ No se está grabando")
		return false
	
	print("Deteniendo grabación...")
	
	# Desactivar grabación usando GameManager
	var recording = await GameManager.stop_recording()
	
	if recording and recording.data.size() > 0:
		# Guardar los datos
		current_audio_data = recording.data
		print("✓ Audio grabado: ", current_audio_data.size(), " bytes")
	else:
		print("⚠ No se grabó audio, creando audio de prueba...")
		_create_test_audio()
	
	is_recording = false
	
	# Actualizar UI
	record_button.visible = true
	record_button.disabled = false
	stop_button.visible = false
	play_button.visible = true
	play_button.disabled = false
	confirm_button.disabled = false
	
	info_label.text = "✅ Grabación completada\n\n" + \
					"Puedes escucharla o confirmar para continuar"
	
	print("✓ Grabación detenida y procesada")
	return true

func _create_test_audio():
	print("Creando audio de prueba...")
	
	# Crear un audio simple de prueba
	var sample_rate = 44100
	var duration = min(recording_time, max_recording_time)
	if duration < 1:
		duration = 2  # Mínimo 2 segundos
	
	var num_samples = int(sample_rate * duration)
	
	print("  - Sample rate: ", sample_rate)
	print("  - Duración: ", duration, " segundos")
	print("  - Número de muestras: ", num_samples)
	
	# Crear buffer para los datos
	var buffer = StreamPeerBuffer.new()
	buffer.big_endian = false  # Little endian para WAV
	
	# Cabecera RIFF
	buffer.put_data("RIFF".to_ascii_buffer())
	
	# Tamaño del archivo - 36 + (num_samples * 2 bytes por muestra)
	var file_size = 36 + num_samples * 2
	buffer.put_u32(file_size)
	
	buffer.put_data("WAVE".to_ascii_buffer())
	
	# fmt chunk
	buffer.put_data("fmt ".to_ascii_buffer())
	buffer.put_u32(16)          # Tamaño del chunk fmt
	buffer.put_u16(1)           # Formato PCM
	buffer.put_u16(1)           # Mono
	buffer.put_u32(sample_rate) # Sample rate
	
	# Byte rate = sample_rate * num_channels * bytes_per_sample
	var byte_rate = sample_rate * 1 * 2
	buffer.put_u32(byte_rate)
	
	# Block align = num_channels * bytes_per_sample
	var block_align = 1 * 2
	buffer.put_u16(block_align)
	
	# Bits per sample
	buffer.put_u16(16)
	
	# data chunk
	buffer.put_data("data".to_ascii_buffer())
	
	# Tamaño de los datos = num_samples * num_channels * bytes_per_sample
	var data_size = num_samples * 1 * 2
	buffer.put_u32(data_size)
	
	# Generar tono de prueba (220Hz - más grave)
	var frequency = 220.0
	var amplitude = 0.5
	
	print("  - Generando tono de prueba: ", frequency, " Hz")
	
	for i in range(num_samples):
		var t = float(i) / sample_rate
		
		# Onda sinusoidal con frecuencia que varía un poco
		var current_freq = frequency * (1.0 + 0.1 * sin(2.0 * PI * 0.5 * t))
		var sample = sin(2.0 * PI * current_freq * t) * amplitude
		
		# Convertir a 16-bit
		var sample_16bit = int(sample * 32767)
		
		# Escribir en little endian
		buffer.put_16(sample_16bit)
	
	current_audio_data = buffer.data_array
	print("✓ Audio de prueba creado: ", current_audio_data.size(), " bytes")

func _on_RecordButton_pressed():
	print("Botón Grabar presionado")
	start_recording()

func _on_StopButton_pressed():
	print("Botón Parar presionado")
	# Llamar a stop_recording pero no esperar el resultado aquí
	# porque sería una coroutine
	stop_recording()

func _on_PlayButton_pressed():
	print("Botón Escuchar presionado")
	play_recording()

func play_recording():
	if current_audio_data.size() == 0:
		print("⚠ No hay grabación para reproducir")
		info_label.text = "⚠ No hay grabación para reproducir\n\nPresiona Grabar primero"
		return
	
	print("Reproduciendo grabación...")
	
	# Crear AudioStreamWAV desde los datos
	var playback_stream = AudioStreamWAV.new()
	
	# Crear una copia de los datos
	var audio_data_copy = PackedByteArray()
	audio_data_copy.resize(current_audio_data.size())
	for i in range(current_audio_data.size()):
		audio_data_copy[i] = current_audio_data[i]
	
	playback_stream.data = audio_data_copy
	playback_stream.format = AudioStreamWAV.FORMAT_16_BITS
	playback_stream.mix_rate = 44100
	playback_stream.stereo = false
	
	# Configurar audio player
	audio_player.bus = "Master"
	audio_player.volume_db = 0.0
	
	# Detener reproducción anterior
	if audio_player.playing:
		audio_player.stop()
	
	# Reproducir
	audio_player.stream = playback_stream
	audio_player.play()
	
	info_label.text = "▶️ Reproduciendo grabación...\n\n" + \
					"Dibujo " + str(GameManager.current_drawing_index + 1) + " de " + str(GameManager.drawings_to_record.size())
	
	print("✓ Reproducción iniciada - Duración: ", playback_stream.get_length(), " segundos")
	
	# Verificar el volumen
	print("  - Volumen del AudioPlayer: ", audio_player.volume_db)
	print("  - Bus del AudioPlayer: ", audio_player.bus)

func _on_playback_finished():
	if is_recording:
		return
	
	print("Reproducción completada")
	info_label.text = "✅ Reproducción completada\n\n" + \
					"Puedes regrabar o confirmar para continuar"

func _update_timer():
	if is_recording:
		recording_time += 1
		timer_label.text = "Tiempo: " + str(recording_time) + "s / " + str(max_recording_time) + "s"
		
		if recording_time >= max_recording_time:
			print("⏰ Tiempo de grabación máximo alcanzado")
			stop_recording()
			return
		
		await get_tree().create_timer(1).timeout
		_update_timer()

func _on_FinishButton_pressed():
	if voice_finished:
		print("⚠ Ya se completó la voz para este dibujo")
		return
	
	print("Botón Confirmar presionado")
	
	if GameManager.has_more_drawings():
		# Guardar la voz para este dibujo
		var drawing_id = GameManager.get_current_player_id()
		print("  - Guardando voz para dibujo del jugador: ", drawing_id)
		
		if current_audio_data.size() > 0:
			GameManager.save_local_voice(drawing_id, current_audio_data)
			print("✓ Voz guardada: ", current_audio_data.size(), " bytes")
		else:
			print("⚠ Sin datos de audio, creando audio de prueba")
			_create_test_audio()
			if current_audio_data.size() > 0:
				GameManager.save_local_voice(drawing_id, current_audio_data)
				print("✓ Voz de prueba guardada: ", current_audio_data.size(), " bytes")
		
		# Pasar al siguiente dibujo
		if GameManager.next_drawing():
			print("✓ Pasando al siguiente dibujo")
			recording_time = 0
			current_audio_data = PackedByteArray()
			show_next_drawing()
			
			# Resetear botones
			record_button.visible = true
			record_button.disabled = false
			stop_button.visible = false
			play_button.visible = false
			play_button.disabled = true
			confirm_button.disabled = true
			
		else:
			# Todos los dibujos completados
			print("✓ Todos los dibujos han sido procesados")
			voice_finished = true
			finish_voice_round()
			
	else:
		# Terminar ronda
		print("✓ No hay más dibujos, terminando ronda")
		voice_finished = true
		finish_voice_round()

func finish_voice_round():
	var my_id = multiplayer.get_unique_id()
	print("=== JUGADOR TERMINÓ RONDA DE VOZ ===")
	print("  - Jugador ID: ", my_id)
	print("  - Es host: ", GameManager.is_host)
	
	# Marcar como terminado
	if GameManager.is_host:
		host_player_finished_voice(my_id)
	else:
		rpc_id(1, "player_finished_voice", my_id)
		print("  - Notificando al host...")
	
	info_label.text = "⏳ Esperando a que otros jugadores terminen..."
	record_button.disabled = true
	play_button.disabled = true
	confirm_button.disabled = true

@rpc("any_peer")
func player_finished_voice(player_id: int):
	if not GameManager.is_host:
		print("⚠ Llamada a player_finished_voice recibida pero no soy host")
		return
	
	print("Host recibió notificación de jugador terminado: ", player_id)
	host_player_finished_voice(player_id)

func host_player_finished_voice(player_id: int):
	if player_id in GameManager.voice_finished_players:
		print("⚠ Jugador ", player_id, " ya estaba en la lista de terminados")
		return
	
	GameManager.voice_finished_players.append(player_id)
	print("✓ Jugador añadido a lista de terminados: ", player_id)
	print("  - Terminados: ", GameManager.voice_finished_players.size(), "/", get_total_players())
	
	check_if_all_finished_voice()

func check_if_all_finished_voice():
	if GameManager.voice_finished_players.size() >= get_total_players():
		print("=== TODOS LOS JUGADORES TERMINARON LA RONDA DE VOZ ===")
		print("  - Total jugadores: ", get_total_players())
		print("  - Enviando a todos al Recap...")
		
		# Enviar a todos los jugadores al recap
		rpc("start_recap")

func get_total_players() -> int:
	return multiplayer.get_peers().size() + 1

@rpc("authority", "call_local")
func start_recap():
	print("=== CAMBIANDO A RECAP ===")
	print("  - Jugador: ", multiplayer.get_unique_id())
	
	GameManager.current_phase = GameManager.Phase.RECAP
	
	# Cambiar a la escena de recap
	get_tree().change_scene_to_file("res://scenes/Recap.tscn")
	
	print("✓ Escena cambiada a Recap")

func _exit_tree():
	print("VoiceRound limpiando recursos...")
	
	# Limpiar recursos de audio
	if audio_player.playing:
		audio_player.stop()
	
	# Detener grabación si está activa
	if is_recording:
		# No podemos usar await aquí, así que llamamos directamente
		GameManager.audio_effect_record.set_recording_active(false)
		print("✓ Grabación detenida al salir de la escena")
	
	# Limpiar datos
	current_audio_data = PackedByteArray()
