# FILE: scripts/drawing_canvas.gd
extends Control

var drawing := false
var last_pos := Vector2.ZERO
var brush_color := Color.BLACK
var brush_size := 4
var lines := []  # Array de líneas [[from, to, color, size]]

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			drawing = event.pressed
			if event.pressed:
				last_pos = event.position
				lines.append([event.position, event.position, brush_color, brush_size])
				queue_redraw()
	elif event is InputEventMouseMotion and drawing:
		lines.append([last_pos, event.position, brush_color, brush_size])
		last_pos = event.position
		queue_redraw()

func _draw():
	# Dibujar un fondo blanco para el canvas
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
	
	# Dibujar todas las líneas almacenadas
	for line in lines:
		draw_line(line[0], line[1], line[2], line[3])

func clear():
	lines.clear()
	queue_redraw()

# Obtener la imagen del canvas - VERSIÓN CORREGIDA PARA GODOT 4.5
func get_image() -> Image:
	# Crear una imagen del tamaño del canvas
	var img = Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	
	# Llenar con blanco
	img.fill(Color.WHITE)
	
	# Obtener los datos de la imagen como un PackedByteArray
	var img_data = img.get_data()
	var img_width = img.get_width()
	
	# Convertir a un Array para poder modificarlo
	var pixel_array = []
	pixel_array.resize(img_data.size())
	
	# Copiar los datos iniciales (fondo blanco)
	for i in range(img_data.size()):
		pixel_array[i] = img_data[i]
	
	# Dibujar todas las líneas almacenadas
	for line in lines:
		var start: Vector2 = line[0]
		var end: Vector2 = line[1]
		var color: Color = line[2]
		var thickness: int = line[3]
		
		# Convertir color a bytes RGBA
		var r_byte = int(color.r * 255)
		var g_byte = int(color.g * 255)
		var b_byte = int(color.b * 255)
		var a_byte = int(color.a * 255)
		
		# Dibujar una línea simple usando algoritmo de Bresenham
		draw_line_on_array(pixel_array, img_width, start, end, 
						  r_byte, g_byte, b_byte, a_byte, thickness)
	
	# Convertir el array de nuevo a PackedByteArray
	var result_data = PackedByteArray()
	result_data.resize(pixel_array.size())
	for i in range(pixel_array.size()):
		result_data[i] = pixel_array[i]
	
	# Actualizar la imagen con los nuevos datos
	img.set_data(img_width, img.get_height(), false, Image.FORMAT_RGBA8, result_data)
	
	print("Canvas: imagen creada de tamaño ", img.get_size())
	return img

# Función auxiliar para dibujar una línea en el array de píxeles
func draw_line_on_array(pixel_array: Array, width: int, 
					   start: Vector2, end: Vector2,
					   r: int, g: int, b: int, a: int, thickness: int):
	var x0 = int(start.x)
	var y0 = int(start.y)
	var x1 = int(end.x)
	var y1 = int(end.y)
	
	# Algoritmo de Bresenham para líneas
	var dx = abs(x1 - x0)
	var dy = abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx - dy
	
	while true:
		# Dibujar el punto en (x0, y0)
		draw_point_on_array(pixel_array, width, x0, y0, r, g, b, a, thickness)
		
		if x0 == x1 and y0 == y1:
			break
		
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy

# Función auxiliar para dibujar un punto (con grosor)
func draw_point_on_array(pixel_array: Array, width: int, 
						x: int, y: int,
						r: int, g: int, b: int, a: int, thickness: int):
	if thickness <= 1:
		# Punto simple
		set_pixel_in_array(pixel_array, width, x, y, r, g, b, a)
	else:
		# Punto con grosor (círculo simple)
		var radius = thickness / 2
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if dx * dx + dy * dy <= radius * radius:
					set_pixel_in_array(pixel_array, width, x + dx, y + dy, r, g, b, a)

# Función auxiliar para establecer un píxel en el array
func set_pixel_in_array(pixel_array: Array, width: int, 
					   x: int, y: int,
					   r: int, g: int, b: int, a: int):
	# Verificar límites
	if x < 0 or x >= width or y < 0 or y >= int(size.y):
		return
	
	# Calcular posición en el array (4 bytes por píxel: RGBA)
	var pos = (y * width + x) * 4
	
	if pos >= 0 and pos + 3 < pixel_array.size():
		pixel_array[pos] = r      # Rojo
		pixel_array[pos + 1] = g  # Verde
		pixel_array[pos + 2] = b  # Azul
		pixel_array[pos + 3] = a  # Alpha

# Versión ALTERNATIVA más simple (si la anterior es compleja)
func get_image_simple() -> Image:
	# Crear una imagen del tamaño del canvas
	var img = Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	
	# Llenar con blanco
	img.fill(Color.WHITE)
	
	# Crear una imagen temporal para cada línea y combinarlas
	for line in lines:
		var start: Vector2 = line[0]
		var end: Vector2 = line[1]
		var color: Color = line[2]
		var thickness: int = line[3]
		
		# Para cada línea, crear una pequeña imagen y usar blend_rect
		# (Esta es una versión simplificada)
		
		# Calcular bounding box de la línea
		var min_x = min(start.x, end.x)
		var max_x = max(start.x, end.x)
		var min_y = min(start.y, end.y)
		var max_y = max(start.y, end.y)
		
		# Crear imagen para esta línea
		var line_width = int(max_x - min_x) + thickness
		var line_height = int(max_y - min_y) + thickness
		
		if line_width > 0 and line_height > 0:
			var line_img = Image.create(line_width, line_height, false, Image.FORMAT_RGBA8)
			line_img.fill(Color(0, 0, 0, 0))  # Transparente
			
			# Dibujar línea en la imagen temporal
			# (En Godot 4.5 necesitarías usar Image.draw_line si está disponible,
			# o implementar tu propio dibujo)
			
			# Para simplificar, solo dibujamos puntos en los extremos
			var offset_x = int(min_x - thickness/2)
			var offset_y = int(min_y - thickness/2)
			
			# Dibujar punto de inicio
			draw_filled_circle_on_image(line_img, 
									   int(start.x - offset_x), 
									   int(start.y - offset_y),
									   thickness, color)
			
			# Dibujar punto final
			draw_filled_circle_on_image(line_img,
									   int(end.x - offset_x),
									   int(end.y - offset_y),
									   thickness, color)
			
			# Combinar con la imagen principal
			img.blend_rect(line_img, 
						  Rect2(0, 0, line_width, line_height),
						  Vector2(offset_x, offset_y))
	
	return img

# Función auxiliar para dibujar un círculo relleno
func draw_filled_circle_on_image(img: Image, center_x: int, center_y: int, 
							   radius: int, color: Color):
	var data = img.get_data()
	var width = img.get_width()
	var height = img.get_height()
	
	for y in range(max(0, center_y - radius), min(height, center_y + radius + 1)):
		for x in range(max(0, center_x - radius), min(width, center_x + radius + 1)):
			var dx = x - center_x
			var dy = y - center_y
			if dx * dx + dy * dy <= radius * radius:
				img.set_pixel(x, y, color)
