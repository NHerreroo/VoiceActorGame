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
var audio_effect_record: AudioEffectRecord
var is_recording := false
var recording_time := 0
var max_recording_time := 10
var voice_finished := false

# Datos de la grabación actual
var current_audio_data: PackedByteArray
var current_recording: AudioStreamWAV

func _ready():
	print("=== VOICE ROUND INICIADO ===")
	print("  - Jugador ID: ", multiplayer.get_unique_id())
	print("  - Es host: ", GameManager.is_host)
	
	# Configurar sistema de audio
	_setup_audio_system()
	
	# Configurar micrófono
	AudioServer.set_input_device(GameManager.selected_mic)
	mic_info.text = "Mic: " + GameManager.selected_mic
	print("  - Micrófono seleccionado: ", GameManager.selected_mic)
	
	# Resetear estado de voz
	voice_finished = false
	current_audio_data = PackedByteArray()
	current_recording = null
	
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

func _setup_audio_system():
	print("Configurando sistema de audio para Voice Round...")
	
	# Conectar señal de finalización de reproducción
	if audio_player:
		audio_player.finished.connect(_on_playback_finished)
		print("✓ AudioPlayer conectado")
	else:
		print("✗ ERROR: AudioPlayer no encontrado")
	
	# Crear efecto de grabación
	audio_effect_record = AudioEffectRecord.new()
	
	# Configurar bus de audio para grabación
	var bus_idx = AudioServer.get_bus_index("VoiceRecord")
	if bus_idx == -1:
		print("Creando nuevo bus de grabación para voz...")
		AudioServer.add_bus(1)
		bus_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(bus_idx, "VoiceRecord")
		print("✓ Bus de grabación creado con índice: ", bus_idx)
	
	# Añadir efecto de grabación al bus
	AudioServer.add_bus_effect(bus_idx, audio_effect_record)
	AudioServer.set_bus_mute(bus_idx, false)
	
	# Conectar el bus de entrada (bus 0) al bus de grabación
	AudioServer.set_bus_send(0, "VoiceRecord")
	
	print("✓ Sistema de audio configurado para Voice Round")

func show_next_drawing():
	print("Mostrando siguiente dibujo...")
	
	if GameManager.has_more_drawings():
		var image_data: PackedByteArray = GameManager.get_current_drawing()
		var player_id = GameManager.get_current_player_id()
		
		print("  - Dibujo actual: ", GameManager.current_drawing_index + 1, " de ", GameManager.drawings_to_record.size())
		print("  - ID del jugador del dibujo: ", player_id)
		print("  - Tamaño de datos de imagen: ", image_data.size(), " bytes")
		
		# Limpiar grabación anterior
		current_audio_data = PackedByteArray()
		current_recording = null
		
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
				print("  - Tamaño de imagen: ", image.get_size())
				
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

func _on_RecordButton_pressed():
	print("Botón Grabar presionado")
	start_recording()

func start_recording():
	if is_recording:
		print("⚠ Ya se está grabando")
		return
	
	print("Iniciando grabación de voz...")
	
	# Configurar dispositivo de micrófono
	AudioServer.set_input_device(GameManager.selected_mic)
	print("  - Micrófono configurado: ", GameManager.selected_mic)
	
	# Activar grabación
	audio_effect_record.set_recording_active(true)
	
	is_recording = true
	recording_time = 0
	
	# Actualizar UI
	record_button.visible = false
	stop_button.visible = true
	play_button.visible = false
	play_button.disabled = true
	confirm_button.disabled = true
	
	info_label.text = "🎤 GRABANDO... Habla ahora!\n\n" + \
					"Dibujo " + str(GameManager.current_drawing_index + 1) + " de " + str(GameManager.drawings_to_record.size())
	
	timer_label.text = "Tiempo: 0s / " + str(max_recording_time) + "s"
	
	print("✓ Grabación iniciada")
	
	# Iniciar temporizador
	_update_timer()

func stop_recording():
	if not is_recording:
		print("⚠ No se está grabando")
		return
	
	print("Deteniendo grabación...")
	
	# Desactivar grabación
	audio_effect_record.set_recording_active(false)
	
	# Obtener la grabación
	current_recording = audio_effect_record.get_recording()
	
	if current_recording and current_recording.data.size() > 0:
		# Configurar parámetros del audio
		current_recording.mix_rate = 44100  # 44.1 kHz
		current_recording.stereo = false    # Mono
		current_recording.format = AudioStreamWAV.FORMAT_16_BITS
		
		# Guardar los datos
		current_audio_data = current_recording.data
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

func _create_test_audio():
	print("Creando audio de prueba WAV...")
	
	# Crear un StreamPeerBuffer para escribir bytes
	var buffer = StreamPeerBuffer.new()
	buffer.big_endian = false  # Little endian para WAV
	
	# Parámetros del audio
	var sample_rate = 44100
	var duration = min(recording_time, max_recording_time)
	var num_samples = int(sample_rate * duration)
	
	print("  - Sample rate: ", sample_rate, " Hz")
	print("  - Duración: ", duration, " segundos")
	print("  - Número de muestras: ", num_samples)
	
	# Cabecera WAV
	# RIFF header
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
	
	# Generar onda sinusoidal más grave y suave
	var frequency = 220.0  # Hz (más grave que 440Hz)
	var amplitude = 0.2    # Más bajo para no molestar
	
	print("  - Generando onda sinusoidal: ", frequency, " Hz, amplitud: ", amplitude)
	
	for i in range(num_samples):
		var t = float(i) / sample_rate
		
		# Frecuencia que baja gradualmente para evitar tono fijo
		var current_freq = frequency * (1.0 - float(i) / num_samples * 0.3)
		
		# Onda sinusoidal
		var sample = sin(2.0 * PI * current_freq * t) * amplitude
		
		# Convertir a 16-bit (rango: -32768 a 32767)
		var sample_16bit = int(sample * 32767)
		
		# Escribir en little endian (2 bytes)
		buffer.put_16(sample_16bit)
	
	# Obtener los datos finales
	current_audio_data = buffer.data_array
	
	print("✓ Audio de prueba creado: ", current_audio_data.size(), " bytes")

func _on_StopButton_pressed():
	print("Botón Parar presionado")
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
	playback_stream.data = current_audio_data
	playback_stream.format = AudioStreamWAV.FORMAT_16_BITS
	playback_stream.mix_rate = 44100
	playback_stream.stereo = false
	
	# Reproducir
	audio_player.stream = playback_stream
	audio_player.play()
	
	info_label.text = "▶️ Reproduciendo grabación...\n\n" + \
					"Dibujo " + str(GameManager.current_drawing_index + 1) + " de " + str(GameManager.drawings_to_record.size())
	
	print("✓ Reproducción iniciada")

func _on_playback_finished():
	if is_recording:
		return
	
	print("Reproducción completada")
	info_label.text = "✅ Reproducción completada\n\n" + \
					"Puedes regrabar o confirmar para continuar"

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
		else:
			print("⚠ Sin datos de audio, creando audio de prueba")
			_create_test_audio()
			if current_audio_data.size() > 0:
				GameManager.save_local_voice(drawing_id, current_audio_data)
		
		# Pasar al siguiente dibujo
		if GameManager.next_drawing():
			print("✓ Pasando al siguiente dibujo")
			show_next_drawing()
			
			# Resetear botones
			record_button.visible = true
			record_button.disabled = false
			stop_button.visible = false
			play_button.visible = false
			play_button.disabled = true
			confirm_button.disabled = true
			
			current_audio_data = PackedByteArray()
			current_recording = null
			
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
		audio_effect_record.set_recording_active(false)
		print("✓ Grabación detenida al salir de la escena")
