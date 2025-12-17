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

var current_rating := 0
var waiting_for_host := false

func _ready():
	print("Recap cargado - Esperando nodos...")
	
	# Esperar un frame para asegurar que todos los nodos están listos
	await get_tree().process_frame
	
	# Resetear estado del recap
	GameManager.reset_recap()
	
	# Configurar botones de rating
	setup_rating_buttons()
	
	# Mostrar controles según si es host o no
	if GameManager.is_host:
		next_drawing_button.visible = true
		next_drawing_button.text = "⏭️ Siguiente"
	else:
		next_drawing_button.visible = false
	
	# Sincronizar con el estado actual del host
	if GameManager.is_host:
		# El host inicia el recap
		update_display()
		# Informar a todos los jugadores
		rpc("sync_recap_state", GameManager.current_recap_drawing_index, GameManager.current_recap_voice_index)
	else:
		# Los clientes esperan instrucciones del host
		waiting_for_host = true
		status_label.text = "Esperando al host..."
		disable_all_controls()

func setup_rating_buttons():
	for i in range(1, 11):
		var button = rating_buttons_container.get_node("Rating" + str(i))
		if button:
			button.pressed.connect(_on_rating_button_pressed.bind(i))

func update_display():
	if GameManager.recap_finished:
		show_final_results()
		return
	
	var drawing_id = GameManager.get_current_recap_drawing_id()
	var voice_owner_id = GameManager.get_current_recap_voice_owner_id()
	
	if drawing_id == -1:
		status_label.text = "No hay dibujos disponibles"
		return
	
	if voice_owner_id == -1:
		status_label.text = "No hay voces para este dibujo"
		return
	
	# Mostrar información del dibujo
	current_drawing_info.text = "Dibujo de Jugador " + str(drawing_id)
	
	# Mostrar la imagen
	var image_data = GameManager.drawings.get(drawing_id)
	if image_data and image_data.size() > 0:
		var image = Image.new()
		var error = image.load_png_from_buffer(image_data)
		
		if error == OK:
			var texture = ImageTexture.create_from_image(image)
			drawing_texture.texture = texture
	
	# Mostrar información de la voz
	voice_info_label.text = "Voz de Jugador " + str(voice_owner_id)
	
	# Resetear rating
	current_rating = 0
	selected_rating_label.text = "Seleccionado: -"
	update_rating_buttons()
	
	# Reproducir audio automáticamente
	play_current_voice()
	
	# Actualizar estado
	status_label.text = "Escuchando y puntuando..."
	enable_all_controls()

func play_current_voice():
	var drawing_id = GameManager.get_current_recap_drawing_id()
	
	# Detener cualquier reproducción en curso
	if audio_player.playing:
		audio_player.stop()
	
	# En el sistema actual, las voces se guardan por drawing_id
	# Necesitaríamos modificar para guardar por (drawing_id, voice_owner_id)
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
		
		print("Reproduciendo audio para dibujo ", drawing_id)
	else:
		print("No hay audio disponible para dibujo ", drawing_id)

func _on_replay_button_pressed():
	play_current_voice()

func _on_rating_button_pressed(rating: int):
	current_rating = rating
	selected_rating_label.text = "Seleccionado: " + str(rating)
	update_rating_buttons()
	
	# Enviar rating al host
	var drawing_id = GameManager.get_current_recap_drawing_id()
	var voice_owner_id = GameManager.get_current_recap_voice_owner_id()
	var my_id = multiplayer.get_unique_id()
	
	if drawing_id != -1 and voice_owner_id != -1:
		rpc_id(1, "submit_rating_to_host", my_id, drawing_id, voice_owner_id, rating)
		print("Rating enviado: ", rating)

func update_rating_buttons():
	# Desmarcar todos los botones
	for i in range(1, 11):
		var button = rating_buttons_container.get_node("Rating" + str(i))
		if button:
			button.button_pressed = false
	
	# Marcar el rating actual
	if current_rating > 0 and current_rating <= 10:
		var button = rating_buttons_container.get_node("Rating" + str(current_rating))
		if button:
			button.button_pressed = true

func _on_next_drawing_button_pressed():
	if not GameManager.is_host:
		return
	
	# Enviar rating si hay uno seleccionado
	if current_rating > 0:
		var drawing_id = GameManager.get_current_recap_drawing_id()
		var voice_owner_id = GameManager.get_current_recap_voice_owner_id()
		var my_id = multiplayer.get_unique_id()
		
		if drawing_id != -1 and voice_owner_id != -1:
			GameManager.submit_rating(my_id, drawing_id, voice_owner_id, current_rating)
	
	# Avanzar al siguiente item
	var has_next = GameManager.next_recap_item()
	
	if has_next:
		# Actualizar pantalla
		update_display()
		# Sincronizar con todos los jugadores
		rpc("sync_recap_state", GameManager.current_recap_drawing_index, GameManager.current_recap_voice_index)
	else:
		# Mostrar resultados finales
		show_final_results()
		# Informar a todos
		rpc("show_final_results_all")

func disable_all_controls():
	replay_button.disabled = true
	next_voice_button.visible = false
	rating_buttons_container.visible = false
	selected_rating_label.visible = false

func enable_all_controls():
	replay_button.disabled = false
	next_voice_button.visible = true
	rating_buttons_container.visible = true
	selected_rating_label.visible = true

@rpc("any_peer")
func submit_rating_to_host(rater_id: int, drawing_id: int, voice_owner_id: int, rating: int):
	if not GameManager.is_host:
		return
	
	GameManager.submit_rating(rater_id, drawing_id, voice_owner_id, rating)
	print("Host recibió rating de ", rater_id, " para voz de ", voice_owner_id)

@rpc("authority", "call_local", "reliable")
func sync_recap_state(drawing_index: int, voice_index: int):
	GameManager.current_recap_drawing_index = drawing_index
	GameManager.current_recap_voice_index = voice_index
	GameManager.recap_finished = false
	
	waiting_for_host = false
	update_display()

func show_final_results():
	status_label.text = "¡Juego completado!"
	current_drawing_info.text = "RESULTADOS FINALES"
	voice_info_label.text = ""
	
	if drawing_texture:
		drawing_texture.visible = false
	
	# Calcular y mostrar puntuaciones
	var final_scores = calculate_final_scores()
	var results_text = "🏆 PUNTUACIONES FINALES 🏆\n\n"
	
	for player_id in final_scores.keys():
		var player_name = GameManager.players.get(player_id, "Jugador " + str(player_id))
		var score = final_scores[player_id]
		results_text += player_name + ": " + str(score) + " puntos\n"
	
	voice_info_label.text = results_text
	
	# Ocultar controles
	replay_button.visible = false
	next_voice_button.visible = false
	rating_buttons_container.visible = false
	selected_rating_label.visible = false
	
	# Cambiar botón del host
	if GameManager.is_host:
		next_drawing_button.text = "🏁 Volver al Lobby"
		next_drawing_button.pressed.disconnect(_on_next_drawing_button_pressed)
		next_drawing_button.pressed.connect(_on_return_to_lobby)

func calculate_final_scores() -> Dictionary:
	var scores = {}
	
	# Sumar todos los ratings para cada jugador
	for drawing_id in GameManager.recap_ratings:
		for voice_owner_id in GameManager.recap_ratings[drawing_id]:
			for rater_id in GameManager.recap_ratings[drawing_id][voice_owner_id]:
				var rating = GameManager.recap_ratings[drawing_id][voice_owner_id][rater_id]
				
				if not scores.has(voice_owner_id):
					scores[voice_owner_id] = 0
				
				scores[voice_owner_id] += rating
	
	return scores

func _on_return_to_lobby():
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

@rpc("authority", "call_local", "reliable")
func show_final_results_all():
	show_final_results()
