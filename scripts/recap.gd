# FILE: scripts/recap.gd
extends Control

@onready var title_label: Label = $TitleLabel
@onready var drawing_texture: TextureRect = $DrawingContainer/DrawingTexture
@onready var current_drawing_info: Label = $DrawingContainer/CurrentDrawingInfo
@onready var voice_info_label: Label = $DrawingContainer/VoiceInfoLabel
@onready var replay_button: Button = $DrawingContainer/ControlsContainer/ReplayButton
@onready var next_voice_button: Button = $DrawingContainer/ControlsContainer/NextVoiceButton
@onready var rating_buttons_container: HBoxContainer = $RatingContainer/RatingButtons
@onready var selected_rating_label: Label = $RatingContainer/SelectedRating
@onready var next_drawing_button: Button = $HostControls/NextDrawingButton
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var status_label: Label = $StatusLabel

var current_voice_index := 0
var voice_ratings := {}  # drawing_id -> {voice_owner_id -> rating}
var player_ratings := {} # voice_owner_id -> total_score
var current_rating := 0
var voice_players_for_current_drawing := []
var waiting_for_host := false

func _ready():
	print("Recap cargado - Esperando nodos...")
	
	# Esperar un frame para asegurar que todos los nodos están listos
	await get_tree().process_frame
	
	# Inicializar estructuras
	voice_ratings.clear()
	player_ratings.clear()
	
	print("Esperando configuración del host...")
	
	# Mostrar controles de host si es necesario
	next_drawing_button.visible = GameManager.is_host
	
	# Configurar botones de rating
	setup_rating_buttons()
	
	# Si es el host, inicializar el Recap
	if GameManager.is_host:
		GameManager.setup_recap()
		# Mostrar el primer dibujo a todos los jugadores
		show_current_drawing_to_all()
	
	# Esperar instrucciones del host
	status_label.text = "Esperando al host..."
	waiting_for_host = true

func setup_rating_buttons():
	for i in range(1, 11):
		var button = rating_buttons_container.get_node("Rating" + str(i))
		if button:
			button.pressed.connect(_on_rating_button_pressed.bind(i))

# NUEVO: Función para mostrar el dibujo actual (llamada por RPC)
func show_current_drawing():
	var drawing_id = GameManager.get_current_recap_drawing_id()
	
	if drawing_id == -1:
		status_label.text = "No hay dibujos para mostrar"
		current_drawing_info.text = "No hay datos"
		return
	
	current_voice_index = 0
	current_rating = 0
	
	print("Mostrando dibujo de jugador ", drawing_id)
	
	# Mostrar información del dibujo
	current_drawing_info.text = "Dibujo de Jugador " + str(drawing_id)
	
	# Mostrar la imagen
	var image_data = GameManager.drawings.get(drawing_id)
	if image_data and image_data.size() > 0:
		print("Cargando imagen de ", image_data.size(), " bytes")
		var image = Image.new()
		var error = image.load_png_from_buffer(image_data)
		
		if error == OK:
			var texture = ImageTexture.create_from_image(image)
			
			if drawing_texture:
				drawing_texture.texture = texture
				drawing_texture.visible = true
				print("Textura asignada correctamente")
			else:
				print("ERROR: drawing_texture es null")
		else:
			print("ERROR al cargar PNG: ", error)
			status_label.text = "Error cargando imagen"
	else:
		print("No hay datos de imagen para el dibujo ", drawing_id)
		status_label.text = "No hay imagen disponible"
	
	# Actualizar lista de jugadores que grabaron voz
	update_voice_players_for_current_drawing()
	
	# Mostrar la primera voz para este dibujo
	show_current_voice()
	
	# Habilitar botones
	replay_button.disabled = false
	waiting_for_host = false
	status_label.text = "Mostrando dibujo actual"

# NUEVO: Función para que el host muestre el dibujo a todos
func show_current_drawing_to_all():
	if not GameManager.is_host:
		return
	
	var drawing_id = GameManager.get_current_recap_drawing_id()
	if drawing_id != -1:
		# Enviar a todos los jugadores
		rpc("show_drawing_rpc", drawing_id)
		# Mostrar localmente también
		show_current_drawing()

@rpc("any_peer", "call_local")
func show_drawing_rpc(drawing_id: int):
	# Verificar que tenemos este dibujo
	if GameManager.drawings.has(drawing_id):
		# Mostrar el dibujo
		var image_data = GameManager.drawings.get(drawing_id)
		if image_data and image_data.size() > 0:
			var image = Image.new()
			var error = image.load_png_from_buffer(image_data)
			
			if error == OK:
				var texture = ImageTexture.create_from_image(image)
				drawing_texture.texture = texture
				drawing_texture.visible = true
				
				current_drawing_info.text = "Dibujo de Jugador " + str(drawing_id)
				
				# Actualizar UI
				update_voice_players_for_current_drawing()
				show_current_voice()
				
				waiting_for_host = false
				status_label.text = "Mostrando dibujo actual"

func update_voice_players_for_current_drawing():
	var drawing_id = GameManager.get_current_recap_drawing_id()
	if drawing_id == -1:
		return
	
	voice_players_for_current_drawing.clear()
	
	# Obtener todos los jugadores
	var all_players = GameManager.players.keys()
	print("Todos los jugadores: ", all_players)
	
	for player_id in all_players:
		if player_id != drawing_id:  # Excluir al autor del dibujo
			# Para simplificar, asumimos que todos los otros jugadores grabaron voz
			voice_players_for_current_drawing.append(player_id)
	
	print("Voces disponibles para dibujo ", drawing_id, ": ", voice_players_for_current_drawing)

func show_current_voice():
	if voice_players_for_current_drawing.size() == 0:
		voice_info_label.text = "No hay voces para este dibujo"
		replay_button.disabled = true
		next_voice_button.disabled = true
		return
	
	if current_voice_index < voice_players_for_current_drawing.size():
		var voice_player_id = voice_players_for_current_drawing[current_voice_index]
		voice_info_label.text = "Voz de Jugador " + str(voice_player_id)
		
		# Actualizar estado de botones
		replay_button.disabled = false
		next_voice_button.disabled = (current_voice_index >= voice_players_for_current_drawing.size() - 1)
		
		# Verificar si ya hay un rating para esta voz
		var drawing_id = GameManager.get_current_recap_drawing_id()
		var existing_rating = voice_ratings.get(drawing_id, {}).get(voice_player_id, 0)
		
		if existing_rating > 0:
			current_rating = existing_rating
			selected_rating_label.text = "Seleccionado: " + str(current_rating)
		else:
			current_rating = 0
			selected_rating_label.text = "Seleccionado: -"
		
		# Actualizar botones de rating
		update_rating_buttons()
	else:
		voice_info_label.text = "Todas las voces revisadas"
		next_voice_button.disabled = true

func play_current_voice():
	if voice_players_for_current_drawing.size() == 0:
		status_label.text = "No hay voces para reproducir"
		return
	
	if current_voice_index >= voice_players_for_current_drawing.size():
		return
	
	# Detener cualquier reproducción en curso
	if audio_player.playing:
		audio_player.stop()
	
	var drawing_id = GameManager.get_current_recap_drawing_id()
	
	# En el sistema actual, las voces se guardan con la clave del drawing_id
	var voice_data = GameManager.voices.get(drawing_id)
	
	if voice_data and voice_data.size() > 0:
		# Crear stream de audio
		var audio_stream = AudioStreamWAV.new()
		audio_stream.data = voice_data
		audio_stream.format = AudioStreamWAV.FORMAT_16_BITS
		audio_stream.mix_rate = 44100
		audio_stream.stereo = true
		
		# Reproducir
		audio_player.stream = audio_stream
		audio_player.play()
		
		status_label.text = "Reproduciendo audio..."
		
		# Esperar a que termine
		await audio_player.finished
		status_label.text = "Audio terminado"
	else:
		status_label.text = "No hay audio para reproducir"

func _on_replay_button_pressed():
	play_current_voice()

func _on_next_voice_button_pressed():
	# Guardar rating actual si existe
	save_current_rating()
	
	# Pasar a la siguiente voz
	current_voice_index += 1
	show_current_voice()
	
	# Reproducir automáticamente
	play_current_voice()

func _on_rating_button_pressed(rating: int):
	current_rating = rating
	selected_rating_label.text = "Seleccionado: " + str(rating)
	
	# Actualizar visualmente los botones
	update_rating_buttons()

func update_rating_buttons():
	# Desmarcar todos los botones primero
	for i in range(1, 11):
		var button = rating_buttons_container.get_node("Rating" + str(i))
		if button:
			button.button_pressed = false
	
	# Marcar el rating actual si existe
	if current_rating > 0 and current_rating <= 10:
		var button = rating_buttons_container.get_node("Rating" + str(current_rating))
		if button:
			button.button_pressed = true

func save_current_rating():
	if current_rating > 0 and current_voice_index < voice_players_for_current_drawing.size():
		var drawing_id = GameManager.get_current_recap_drawing_id()
		var voice_player_id = voice_players_for_current_drawing[current_voice_index]
		
		# Inicializar estructura si no existe
		if not voice_ratings.has(drawing_id):
			voice_ratings[drawing_id] = {}
		
		# Guardar rating
		voice_ratings[drawing_id][voice_player_id] = current_rating
		
		# Actualizar puntuación total del jugador
		if not player_ratings.has(voice_player_id):
			player_ratings[voice_player_id] = 0
		player_ratings[voice_player_id] += current_rating
		
		print("Rating guardado: ", current_rating, " para voz de jugador ", voice_player_id)

# MODIFICADO: Ahora el host controla el cambio de dibujo
func _on_next_drawing_button_pressed():
	if not GameManager.is_host:
		return
	
	# Guardar rating actual
	save_current_rating()
	
	# Avanzar al siguiente dibujo
	if GameManager.next_recap_drawing():
		# Mostrar el nuevo dibujo a todos los jugadores
		show_current_drawing_to_all()
	else:
		# Todos los dibujos revisados, mostrar resultados
		show_final_results_to_all()

# NUEVO: Mostrar resultados finales a todos
func show_final_results_to_all():
	if not GameManager.is_host:
		return
	
	# Enviar a todos los jugadores
	rpc("show_final_results_rpc")
	# Mostrar localmente también
	show_final_results()

@rpc("any_peer", "call_local")
func show_final_results_rpc():
	status_label.text = "¡Juego completado!"
	current_drawing_info.text = "RESULTADOS FINALES"
	
	# Mostrar puntuaciones
	var results_text = "Puntuaciones finales:\n\n"
	for player_id in player_ratings.keys():
		var player_name = GameManager.players.get(player_id, "Jugador " + str(player_id))
		results_text += player_name + ": " + str(player_ratings[player_id]) + " puntos\n"
	
	voice_info_label.text = results_text
	
	# Ocultar elementos no necesarios
	if drawing_texture:
		drawing_texture.visible = false
	replay_button.visible = false
	next_voice_button.visible = false
	rating_buttons_container.visible = false
	selected_rating_label.visible = false
	
	# Si es host, cambiar el botón
	if GameManager.is_host:
		next_drawing_button.text = "🏁 Finalizar Juego"
		next_drawing_button.pressed.disconnect(_on_next_drawing_button_pressed)
		next_drawing_button.pressed.connect(_on_finalize_game)

func show_final_results():
	status_label.text = "¡Juego completado!"
	current_drawing_info.text = "RESULTADOS FINALES"
	voice_info_label.text = ""
	
	if drawing_texture:
		drawing_texture.visible = false
	
	# Mostrar puntuaciones
	var results_text = "Puntuaciones finales:\n\n"
	for player_id in player_ratings.keys():
		var player_name = GameManager.players.get(player_id, "Jugador " + str(player_id))
		results_text += player_name + ": " + str(player_ratings[player_id]) + " puntos\n"
	
	voice_info_label.text = results_text
	
	# Ocultar botones no necesarios
	replay_button.visible = false
	next_voice_button.visible = false
	rating_buttons_container.visible = false
	selected_rating_label.visible = false
	
	# Cambiar texto del botón de host
	next_drawing_button.text = "🏁 Finalizar Juego"
	
	# Re-conectar la señal
	next_drawing_button.pressed.disconnect(_on_next_drawing_button_pressed)
	next_drawing_button.pressed.connect(_on_finalize_game)

func _on_finalize_game():
	# Volver al lobby o reiniciar
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")
