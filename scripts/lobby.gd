# FILE: scripts/lobby.gd
extends Control

@onready var ip_input: LineEdit = $VBoxContainer/IPInput
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var mic_dropdown: OptionButton = $VBoxContainer/MicContainer/MicDropdown
@onready var test_status: Label = $VBoxContainer/TestStatus
@onready var test_mic_button: Button = $VBoxContainer/TestMicButton
@onready var audio_player: AudioStreamPlayer = $AudioTestPlayer

var test_recording := false
var audio_effect_record: AudioEffectRecord
var recording: AudioStreamWAV
var test_record_time := 3.0  # Segundos para la prueba

func _ready():
	print("=== LOBBY INICIADO ===")
	
	# Ocultar botón de inicio (solo visible para host)
	start_button.visible = false
	
	# Configurar sistema de audio usando GameManager
	GameManager.setup_audio_system()
	
	# Cargar lista de micrófonos disponibles
	_refresh_microphone_list()
	
	print("Lobby listo. ID del jugador: ", multiplayer.get_unique_id())

# FILE: scripts/lobby.gd - MÉTODO _setup_audio_system CORREGIDO
func _setup_audio_system():
	# Ya no necesitamos configurar el audio aquí, se hace en GameManager
	print("Audio configurado por GameManager")
	
func _debug_audio_status():
	print("=== DEBUG: ESTADO DEL AUDIO ===")
	print("  - Bus count: ", AudioServer.get_bus_count())
	for i in range(AudioServer.get_bus_count()):
		print("  - Bus ", i, ": ", AudioServer.get_bus_name(i))
	print("  - Input device list: ", AudioServer.get_input_device_list())
	print("  - Current input device: ", AudioServer.get_input_device())
	print("  - Current output device: ", AudioServer.get_output_device())
	print("=== FIN DEBUG ===")

func _refresh_microphone_list():
	print("Refrescando lista de micrófonos...")
	
	if not mic_dropdown:
		print("✗ ERROR: MicDropdown no encontrado")
		return
	
	mic_dropdown.clear()
	
	# Obtener micrófonos disponibles a través de GameManager
	var mics = GameManager.get_available_microphones()
	
	if mics.size() == 0:
		mic_dropdown.add_item("No hay micrófonos detectados", 0)
		mic_dropdown.disabled = true
		print("⚠ Advertencia: No se encontraron micrófonos")
		return
	
	mic_dropdown.disabled = false
	
	# Añadir cada micrófono a la lista
	for i in range(mics.size()):
		mic_dropdown.add_item(mics[i], i)
		print("  - Micrófono disponible: ", mics[i])
		
		# Seleccionar el micrófono actual si coincide
		if mics[i] == GameManager.selected_mic:
			mic_dropdown.selected = i
			print("✓ Micrófono seleccionado: ", GameManager.selected_mic)
	
	print("✓ Lista de micrófonos actualizada")

func _on_RefreshMicButton_pressed():
	print("Botón refrescar micrófono presionado")
	_refresh_microphone_list()

func _on_MicDropdown_item_selected(index: int):
	if not mic_dropdown or mic_dropdown.disabled:
		return
	
	var selected_mic = mic_dropdown.get_item_text(index)
	print("Micrófono seleccionado en dropdown: ", selected_mic)
	
	if GameManager.set_microphone(selected_mic):
		print("✓ Micrófono configurado correctamente: ", selected_mic)
	else:
		print("✗ Error configurando micrófono")

func _on_TestMicButton_pressed():
	print("Botón probar micrófono presionado")
	
	if test_recording:
		print("Deteniendo prueba de micrófono...")
		_stop_test_recording()
	else:
		print("Iniciando prueba de micrófono...")
		_start_test_recording()

func _start_test_recording():
	# Verificar que hay un micrófono seleccionado
	if GameManager.selected_mic == "":
		print("✗ No hay micrófono seleccionado")
		test_status.text = "⚠ Selecciona un micrófono primero"
		test_status.visible = true
		await get_tree().create_timer(2.0).timeout
		test_status.visible = false
		return
	
	print("Configurando micrófono: ", GameManager.selected_mic)
	
	# Configurar dispositivo de entrada
	AudioServer.set_input_device(GameManager.selected_mic)
	
	# Actualizar interfaz de usuario
	test_recording = true
	test_mic_button.text = "⏹️ Parar Prueba"
	test_status.visible = true
	test_status.text = "🎤 Habla ahora... (grabando " + str(test_record_time) + " segundos)"
	
	print("Iniciando grabación de prueba...")
	
	# Activar grabación usando GameManager
	if GameManager.start_recording():
		# Temporizador para grabar durante el tiempo especificado
		await get_tree().create_timer(test_record_time).timeout
		
		# Si aún está grabando (no se canceló manualmente), detener
		if test_recording:
			print("Tiempo de grabación completado")
			_stop_test_recording()


# En lobby.gd, modifica _stop_test_recording:
func _stop_test_recording():
	print("Deteniendo grabación de prueba...")
	
	# Desactivar grabación usando GameManager
	var recording = await GameManager.stop_recording()
	test_recording = false
	
	# Actualizar interfaz
	test_mic_button.text = "🎤 Probar Micrófono"
	test_status.text = "⏳ Procesando grabación..."
	
	if recording and recording.data.size() > 0:
		print("✓ Grabación obtenida: ", recording.data.size(), " bytes")
		
		# Reproducir la grabación
		_play_test_recording(recording)
	else:
		print("✗ No se grabó audio o los datos están vacíos")
		test_status.text = "❌ No se detectó audio. Verifica tu micrófono."
		await get_tree().create_timer(3.0).timeout
		test_status.visible = false

func _play_test_recording(recording: AudioStreamWAV):
	print("Reproduciendo grabación de prueba...")
	
	if not recording or recording.data.size() == 0:
		print("✗ No hay grabación para reproducir")
		return
	
	# Crear un nuevo AudioStreamPlayer para la prueba
	if not audio_player:
		audio_player = AudioStreamPlayer.new()
		add_child(audio_player)
	
	# Configurar y reproducir
	audio_player.stream = recording
	audio_player.volume_db = 0.0
	audio_player.bus = "Master"  # Usar el bus Master directamente
	
	# Detener cualquier reproducción anterior
	if audio_player.playing:
		audio_player.stop()
	
	audio_player.play()
	
	test_status.text = "▶️ Reproduciendo..."
	print("✓ Reproducción iniciada")

func _on_test_playback_finished():
	print("Reproducción de prueba completada")
	
	if test_status:
		test_status.text = "✅ Prueba completada. ¿Se escuchó bien?"
	
	# Esperar y ocultar mensaje
	await get_tree().create_timer(3.0).timeout
	
	if test_status:
		test_status.visible = false
	
	print("✓ Prueba de micrófono finalizada")

func _on_host_button_pressed() -> void:
	print("=== INTENTANDO CREAR SALA ===")
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(12345, 8)  # Puerto 12345, máximo 8 jugadores
	
	if error != OK:
		print("✗ Error creando servidor: ", error)
		return
	
	multiplayer.multiplayer_peer = peer
	GameManager.is_host = true
	GameManager.room_code = "1234"  # Código de sala simple
	
	# Mostrar botón de inicio para el host
	start_button.visible = true
	
	print("✓ Sala creada exitosamente")
	print("  - Host ID: ", multiplayer.get_unique_id())
	print("  - Código de sala: ", GameManager.room_code)
	print("  - Puerto: 12345")

func _on_JoinButton_pressed():
	var ip = ip_input.text.strip_edges()
	
	# Usar localhost si no se especifica IP
	if ip == "":
		ip = "127.0.0.1"
		print("Usando IP por defecto (localhost)")
	
	print("=== INTENTANDO CONECTAR A SALA ===")
	print("  - IP: ", ip)
	print("  - Puerto: 12345")
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, 12345)
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("✓ Conectado exitosamente a: ", ip)
		print("  - Jugador ID: ", multiplayer.get_unique_id())
	else:
		print("✗ Error conectando: ", error)
		print("  - Código de error: ", error)

func _on_StartButton_pressed():
	print("=== INICIANDO JUEGO (HOST) ===")
	print("Enviando señal a todos los jugadores para comenzar...")
	
	# Llamar a la función en todos los jugadores (incluyendo host)
	rpc("start_draw_phase")

@rpc("any_peer", "call_local")
func start_draw_phase():
	print("=== CAMBIANDO A FASE DE DIBUJO ===")
	print("  - Jugador: ", multiplayer.get_unique_id())
	print("  - Es host: ", GameManager.is_host)
	
	GameManager.current_phase = GameManager.Phase.DRAW
	
	# Cambiar a la escena de dibujo
	get_tree().change_scene_to_file("res://scenes/DrawingRound.tscn")
	
	print("✓ Escena cambiada a DrawingRound")
	
func _ensure_playback_bus():
	var playback_bus_idx = AudioServer.get_bus_index("VoicePlayback")
	if playback_bus_idx == -1:
		print("Creando bus VoicePlayback...")
		AudioServer.add_bus(1)
		playback_bus_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(playback_bus_idx, "VoicePlayback")
		AudioServer.set_bus_mute(playback_bus_idx, false)
		AudioServer.set_bus_volume_db(playback_bus_idx, 0.0)
	return playback_bus_idx
	
