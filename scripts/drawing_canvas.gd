extends Control

var drawing := false
var last_pos := Vector2.ZERO
var brush_color := Color.BLACK
var brush_size := 4
var lines := []  # Array de líneas [[from, to]]

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			drawing = event.pressed
			last_pos = event.position
	elif event is InputEventMouseMotion and drawing:
		lines.append([last_pos, event.position])
		last_pos = event.position
		update()  # fuerza redraw

func _draw():
	for line in lines:
		draw_line(line[0], line[1], brush_color, brush_size)

func clear():
	lines.clear()
	update()

# Para exportar la imagen a PNG
func get_image() -> Image:
	var img = Image.new()
	img = get_viewport().get_texture().get_image()
	img.flip_y()  # opcional
	return img
