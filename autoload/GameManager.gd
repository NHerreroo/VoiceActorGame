extends Node

enum Phase { LOBBY, DRAW, VOICE, RECAP }

var current_phase := Phase.LOBBY
var is_host := false
var room_code := ""

var finished_players := []

var players := {}      # peer_id -> name
var drawings := {}     # peer_id -> Image
var voices := {}       # drawing_id -> Array[audio]

func reset_game():
	drawings.clear()
	voices.clear()
