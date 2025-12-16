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

# 🔹 BOTÓN "TERMINAR"
func _on_FinishButton_pressed():
	if finished:
		return
	finished = true
	var my_id = multiplayer.get_unique_id()
	print("Jugador terminó:", my_id)

	if GameManager.is_host:
		# 👑 El host se marca a sí mismo
		host_player_finished(my_id)
	else:
		# 👥 Cliente avisa al host
		rpc_id(1, "player_finished")

# 🔹 EL HOST RECIBE QUIÉN TERMINA
@rpc("any_peer")
func player_finished():
	if not GameManager.is_host:
		return

	var sender = multiplayer.get_remote_sender_id()
	host_player_finished(sender)


# 🔹 COMPROBAR SI TODOS TERMINARON
func check_if_all_finished():
	if GameManager.finished_players.size() >= get_total_players():
		print("TODOS TERMINARON")
		change_to_voice_phase()

# 🔹 CAMBIO DE FASE (SOLO HOST)
func change_to_voice_phase():
	rpc("start_voice_phase")

func host_player_finished(player_id: int):
	if player_id in GameManager.finished_players:
		return
	GameManager.finished_players.append(player_id)
	print(
		"HOST: terminados",
		GameManager.finished_players.size(),
		"/",
		get_total_players()
	)
	check_if_all_finished()


func get_total_players() -> int:
	return multiplayer.get_peers().size() + 1 # + host

# 🔹 CAMBIO REAL DE ESCENA
@rpc("any_peer", "call_local")
func start_voice_phase():
	print("CAMBIO A VOICE ROUND - PEER:", multiplayer.get_unique_id())
	GameManager.current_phase = GameManager.Phase.VOICE
	get_tree().change_scene_to_file("res://scenes/VoiceRound.tscn")
