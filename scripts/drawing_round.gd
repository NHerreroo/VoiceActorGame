# FILE: scripts/drawing_round.gd
extends Control

var time_left := 30
var finished := false
@onready var canvas = $DrawingCanvas

func _on_ClearButton_pressed():
	canvas.clear()

func _ready():
	print("DRAWING ROUND - PEER:", multiplayer.get_unique_id())

	if GameManager.is_host:
		GameManager.finished_players.clear()
		start_timer()

func start_timer():
	while time_left > 0:
		await get_tree().create_timer(1).timeout
		time_left -= 1
		print("Tiempo:", time_left)

	if GameManager.is_host:
		print("TIEMPO ACABADO")
		change_to_voice_phase()

# 🔹 BOTÓN "TERMINAR" - AHORA ASÍNCRONO
func _on_FinishButton_pressed():
	if finished:
		return
	finished = true
	
	# Deshabilitar botones para evitar múltiples clics
	$VBoxContainer/FinishButton.disabled = true
	
	var my_id = multiplayer.get_unique_id()
	print("Jugador terminó:", my_id)
	
	# Convertir dibujo a PNG y guardar localmente - CON AWAIT
	var image = await canvas.get_image()  # AÑADIDO AWAIT
	
	# Verificar que la imagen es válida
	if image and image.get_size().x > 0 and image.get_size().y > 0:
		var image_data = image.save_png_to_buffer()
		print("Tamaño de datos PNG: ", image_data.size(), " bytes")
		
		if image_data.size() > 0:
			GameManager.save_local_drawing(image_data)
			
			# Enviar el dibujo al host
			rpc_id(1, "submit_drawing", my_id, image_data)
		else:
			print("ERROR: Los datos de la imagen están vacíos")
			# Crear datos de prueba
			create_test_drawing(my_id)
	else:
		print("ERROR: La imagen es inválida")
		create_test_drawing(my_id)
	
	# Marcar como terminado
	if GameManager.is_host:
		host_player_finished(my_id)
	else:
		rpc_id(1, "player_finished")

# Función para crear un dibujo de prueba si hay error
func create_test_drawing(player_id: int):
	var test_image = Image.create(100, 100, false, Image.FORMAT_RGBA8)
	test_image.fill(Color(0.8, 0.2, 0.2, 1.0))  # Rojo oscuro
	var test_data = test_image.save_png_to_buffer()
	GameManager.save_local_drawing(test_data)
	rpc_id(1, "submit_drawing", player_id, test_data)
	print("Enviado dibujo de prueba para jugador ", player_id)

@rpc("any_peer")
func submit_drawing(player_id: int, image_data: PackedByteArray):
	if not GameManager.is_host:
		return
	
	GameManager.drawings[player_id] = image_data
	print("HOST: recibido dibujo de ", player_id)

@rpc("any_peer")
func player_finished():
	if not GameManager.is_host:
		return

	var sender = multiplayer.get_remote_sender_id()
	host_player_finished(sender)

func host_player_finished(player_id: int):
	if player_id in GameManager.finished_players:
		return
	GameManager.finished_players.append(player_id)
	print(
		"HOST: terminados ",
		GameManager.finished_players.size(),
		"/",
		get_total_players()
	)
	check_if_all_finished()

func check_if_all_finished():
	if GameManager.finished_players.size() >= get_total_players():
		print("TODOS TERMINARON")
		change_to_voice_phase()

func change_to_voice_phase():
	# El host envía todos los dibujos a todos los jugadores
	print("Distribuyendo ", GameManager.drawings.size(), " dibujos...")
	for player_id in GameManager.drawings.keys():
		var image_data = GameManager.drawings[player_id]
		rpc("receive_all_drawings", player_id, image_data)
		print("Enviado dibujo de jugador ", player_id)
	
	# Esperar un momento y cambiar de fase
	await get_tree().create_timer(0.5).timeout
	rpc("start_voice_phase")

@rpc("any_peer", "call_local")
func receive_all_drawings(player_id: int, image_data: PackedByteArray):
	GameManager.drawings[player_id] = image_data
	print("Recibido dibujo de ", player_id, " (", image_data.size(), " bytes)")

@rpc("any_peer", "call_local")
func start_voice_phase():
	print("CAMBIO A VOICE ROUND - PEER:", multiplayer.get_unique_id())
	GameManager.current_phase = GameManager.Phase.VOICE
	GameManager.setup_voice_round()
	get_tree().change_scene_to_file("res://scenes/VoiceRound.tscn")

func get_total_players() -> int:
	return multiplayer.get_peers().size() + 1
