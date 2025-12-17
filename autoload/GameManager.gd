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

# Variables para audio
var audio_effect_record: AudioEffectRecord
var audio_record_bus_idx := -1

func _ready():
	# Inicializar sistema de audio
	setup_audio_system()

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
		
		# Configurar el dispositivo de entrada
		AudioServer.set_input_device(selected_mic)
	
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

# Métodos para audio
func setup_audio_system():
	print("Configurando sistema de audio global...")
	
	# Bus para grabación
	audio_record_bus_idx = AudioServer.get_bus_index("AudioRecord")
	if audio_record_bus_idx == -1:
		print("Creando bus de grabación global...")
		AudioServer.add_bus(1)
		audio_record_bus_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(audio_record_bus_idx, "AudioRecord")
		AudioServer.set_bus_mute(audio_record_bus_idx, false)
		AudioServer.set_bus_volume_db(audio_record_bus_idx, 0.0)
		print("✓ Bus de grabación creado: AudioRecord")
	else:
		print("✓ Bus de grabación ya existe: AudioRecord")
	
	# Crear efecto de grabación si no existe
	if not audio_effect_record:
		audio_effect_record = AudioEffectRecord.new()
		print("✓ Efecto de grabación creado")
	
	# Limpiar efectos existentes del bus
	var effect_count = AudioServer.get_bus_effect_count(audio_record_bus_idx)
	for i in range(effect_count):
		AudioServer.remove_bus_effect(audio_record_bus_idx, 0)
	
	# Añadir efecto de grabación al bus
	AudioServer.add_bus_effect(audio_record_bus_idx, audio_effect_record, 0)
	
	# Configurar el bus de grabación para capturar del master bus
	AudioServer.set_bus_send(0, "AudioRecord")
	
	print("✓ Sistema de audio global configurado")

func start_recording() -> bool:
	if audio_effect_record:
		print("Iniciando grabación...")
		# Asegurarse de que no haya grabación activa
		if audio_effect_record.is_recording_active():
			audio_effect_record.set_recording_active(false)
			# No podemos usar await aquí porque esta función no es async
			# En su lugar, simplemente detenemos y continuamos
		
		audio_effect_record.set_recording_active(true)
		return true
	return false

func stop_recording() -> AudioStreamWAV:
	if audio_effect_record and audio_effect_record.is_recording_active():
		print("Deteniendo grabación...")
		audio_effect_record.set_recording_active(false)
		
		# Esperar un frame para que Godot procese la grabación
		await get_tree().process_frame
		
		var recording = audio_effect_record.get_recording()
		if recording and recording.data.size() > 0:
			recording.mix_rate = 44100
			recording.stereo = false
			recording.format = AudioStreamWAV.FORMAT_16_BITS
			print("✓ Grabación obtenida: ", recording.data.size(), " bytes")
			return recording
	
	print("⚠ No se pudo obtener la grabación")
	return null

# Método para crear un audio de prueba (útil para debugging)
func create_test_audio(duration: float = 3.0) -> PackedByteArray:
	print("Creando audio de prueba...")
	
	var sample_rate = 44100
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
	
	# Generar tono de prueba (440Hz - A4)
	var frequency = 440.0
	var amplitude = 0.3  # Volumen moderado
	
	print("  - Generando tono de prueba: ", frequency, " Hz")
	
	for i in range(num_samples):
		var t = float(i) / sample_rate
		
		# Onda sinusoidal simple
		var sample = sin(2.0 * PI * frequency * t) * amplitude
		
		# Convertir a 16-bit
		var sample_16bit = int(sample * 32767)
		
		# Escribir en little endian
		buffer.put_16(sample_16bit)
	
	var audio_data = buffer.data_array
	print("✓ Audio de prueba creado: ", audio_data.size(), " bytes")
	return audio_data

# Método para verificar el estado del audio
func debug_audio_status():
	print("=== DEBUG: ESTADO DEL AUDIO ===")
	print("  - Bus count: ", AudioServer.get_bus_count())
	for i in range(AudioServer.get_bus_count()):
		print("  - Bus ", i, ": ", AudioServer.get_bus_name(i), 
			  " (muted: ", AudioServer.is_bus_mute(i), 
			  ", volume: ", AudioServer.get_bus_volume_db(i), "dB)")
	
	print("  - Input device list: ", AudioServer.get_input_device_list())
	print("  - Current input device: ", AudioServer.get_input_device())
	print("  - Current output device: ", AudioServer.get_output_device())
	print("  - Audio effect record disponible: ", audio_effect_record != null)
	
	if audio_effect_record:
		print("  - Grabación activa: ", audio_effect_record.is_recording_active())
	
	print("=== FIN DEBUG ===")
