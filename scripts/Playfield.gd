extends TileMap

enum {wait, move}
var state

@export var empty_spaces: PackedVector2Array

@onready var possible_block_units_kvp = {
	"line_block1": { "scene": preload("res://scenes/block_units/line_block1.tscn"), "atlas": Vector2i(0,0) },
	"line_block2": { "scene": preload("res://scenes/block_units/line_block2.tscn"), "atlas": Vector2i(1,0) },
	"line_block3": { "scene": preload("res://scenes/block_units/line_block3.tscn"), "atlas": Vector2i(2,0) },
	"line_block4": { "scene": preload("res://scenes/block_units/line_block4.tscn"), "atlas": Vector2i(3,0) },
	"route1_straight": { "scene": preload("res://scenes/block_units/route1_straight.tscn"), "atlas": Vector2i(0,1) },
	"route1_90deg": { "scene": preload("res://scenes/block_units/route1_90deg.tscn"), "atlas": Vector2i(3,0) },
	"route2": { "scene": preload("res://scenes/block_units/route2.tscn"), "atlas": Vector2i(3,0) },
	"route3": { "scene": preload("res://scenes/block_units/route3.tscn"), "atlas": Vector2i(3,0) },
	"route_join2T": { "scene": preload("res://scenes/block_units/route_join2T.tscn"), "atlas": Vector2i(0,2) },
	"route_join3": { "scene": preload("res://scenes/block_units/route_join3.tscn"), "atlas": Vector2i(0,3) },
	"void": { "scene": preload("res://scenes/block_units/void.tscn"), "atlas": Vector2i(0, 4) },
	"junction": { "scene": preload("res://scenes/block_units/junction.tscn"), "atlas": Vector2i(3,0) },
}

var destroy_timer = Timer.new()
var collapse_timer = Timer.new()
var refill_timer = Timer.new()

var grid = []
var void_cell_atlas = Vector2i(0, 4)
var next_cells_queue = []
var queue_size = 4

#var block_unit_one = null
#var block_unit_two = null
#var last_place = Vector2(0,0)
#var last_direction = Vector2(0,0)
#var move_checked = false

#var first_touch = Vector2(0,0)
#var final_touch = Vector2(0,0)
#var controlling = false

func _ready():
	state = move
	setup_timers()
	randomize()
	grid = make_2d_array()
	void_cell_atlas = possible_block_units_kvp["void"]["atlas"]

	# fill the queue with random cells up to queue_size
	for i in range(queue_size):
		next_cells_queue.append(make_random_cell())

func make_random_cell():
	var rand = floor(randf_range(0, possible_block_units_kvp.size()))
	var block_unit = possible_block_units_kvp.values()[rand]
	return block_unit

func get_clicked_tile_coordinate(mouse_position):
	#print ("event mousePos=", mouse_position)
	#print ("get_local_mouse_position()=", get_local_mouse_position())
	
	# cell position is (col,row) position of the grid
	var cell_position_vec2 = local_to_map(get_local_mouse_position())
	
	# atlas position is how your sprite atlas are defined in TileMap (visual editor)
	var atlas_vec2 = get_cell_atlas_coords(0, cell_position_vec2)
	
	#print("cell_position_vec2=", cell_position_vec2)
	#print("cell_atlas_coord=", atlas_vec2)
	# since GDScript does not have anonymous tuples, we'll just combine the 2 vecs2's as vec4
	return Vector4i(cell_position_vec2.x, cell_position_vec2.y, atlas_vec2.x, atlas_vec2.y)

func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# if the cell is empty, populate it
		var clicked_cell_vec2x2 = get_clicked_tile_coordinate(event.position)
		var clicked_cell_vec2 = Vector2i(clicked_cell_vec2x2.x, clicked_cell_vec2x2.y)
		var clicked_sprite_atlas_vec2 = Vector2i(clicked_cell_vec2x2.z, clicked_cell_vec2x2.w)

		# NOTE: if clicked cell atlas is (-1, -1), user clicked OUTSIDE the grid
		if clicked_sprite_atlas_vec2.x == -1 and clicked_sprite_atlas_vec2.y == -1:
			# opt out
			print("1a")
			pass

		print("1b")
		pass
	else:
		# else if cell is visible, replace it
		print("2")
		pass
		
func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed :
		# force this cell to become void?
		var clicked_cell_vec2x2 = get_clicked_tile_coordinate(event.position)
		var clicked_cell_vec2 = Vector2i(clicked_cell_vec2x2.x, clicked_cell_vec2x2.y)
		var clicked_sprite_atlas_vec2 = Vector2i(clicked_cell_vec2x2.z, clicked_cell_vec2x2.w)

		# NOTE: if clicked cell atlas is (-1, -1), user clicked OUTSIDE the grid
		if clicked_sprite_atlas_vec2.x == -1 and clicked_sprite_atlas_vec2.y == -1:
			# opt out
			pass
		else:
			if event.button_index == MOUSE_BUTTON_LEFT:
				# pop the queue and replace it
				print("3a: ", clicked_cell_vec2, clicked_sprite_atlas_vec2)
				var next_cell = next_cells_queue.pop_front()
				next_cells_queue.append(make_random_cell())
				grid[clicked_cell_vec2.x][clicked_cell_vec2.y] = next_cell["atlas"]
				set_cell(0, clicked_cell_vec2, 0, next_cell["atlas"])
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				# erase it using void_cell_atlas
				print("3b: ", clicked_cell_vec2, clicked_sprite_atlas_vec2)
				grid[clicked_cell_vec2.x][clicked_cell_vec2.y] = void_cell_atlas
				set_cell(0, clicked_cell_vec2, 0, void_cell_atlas)

func setup_timers():
	destroy_timer.connect("timeout", Callable(self, "destroy_matches"))
	destroy_timer.set_one_shot(true)
	destroy_timer.set_wait_time(0.2)
	add_child(destroy_timer)

	collapse_timer.connect("timeout", Callable(self, "collapse_columns"))
	collapse_timer.set_one_shot(true)
	collapse_timer.set_wait_time(0.2)
	add_child(collapse_timer)

	refill_timer.connect("timeout", Callable(self, "refill_columns"))
	refill_timer.set_one_shot(true)
	refill_timer.set_wait_time(0.2)
	add_child(refill_timer)

func make_2d_array():
	var array = []
	var cell_rect = get_used_rect()
	var height = cell_rect.size.y
	var width = cell_rect.size.x
	print("height=", height)
	print("wdith=", width)
	for i in width:
		array.append([])
		for j in height:
			array[i].append(null)
			set_cell(0, Vector2i(i, j), 0, void_cell_atlas)
	return array

#func restricted_fill(place):
#	if is_in_array(empty_spaces, place):
#		return true
#	return false
#
#func is_in_array(array, item):
#	for i in array.size():
#		if array[i] == item:
#			return true
#	return false
#
#func match_at(i, j, color):
#	if i > 1:
#		if grid[i - 1][j] != null && grid[i - 2][j] != null:
#			if grid[i - 1][j].color == color && grid[i - 2][j].color == color:
#				return true
#	if j > 1:
#		if grid[i][j - 1] != null && grid[i][j - 2] != null:
#			if grid[i][j - 1].color == color && grid[i][j - 2].color == color:
#				return true
#	pass
#
#func grid_to_pixel(column, row):
#	var new_x = x_start + offset * column
#	var new_y = y_start + -offset * row
#	return Vector2(new_x, new_y)
#
#func pixel_to_grid(pixel_x,pixel_y):
#	var new_x = round((pixel_x - x_start) / offset)
#	var new_y = round((pixel_y - y_start) / -offset)
#	return Vector2(new_x, new_y)
#
#func is_in_grid(grid_position):
#	if grid_position.x >= 0 && grid_position.x < width:
#		if grid_position.y >= 0 && grid_position.y < height:
#			return true
#	return false
#
#func touch_input():
#	if Input.is_action_just_pressed("ui_touch"):
#		if is_in_grid(pixel_to_grid(get_global_mouse_position().x,get_global_mouse_position().y)):
#			first_touch = pixel_to_grid(get_global_mouse_position().x,get_global_mouse_position().y)
#			controlling = true
#	if Input.is_action_just_released("ui_touch"):
#		if is_in_grid(pixel_to_grid(get_global_mouse_position().x,get_global_mouse_position().y)) && controlling:
#			controlling = false
#			final_touch = pixel_to_grid(get_global_mouse_position().x,get_global_mouse_position().y )
#			touch_difference(first_touch, final_touch)
#
#func swap_block_units(column, row, direction):
#	var first_block_unit = grid[column][row]
#	var other_block_unit = grid[column + direction.x][row + direction.y]
#	if first_block_unit != null && other_block_unit != null:
#		store_info(first_block_unit, other_block_unit, Vector2(column, row), direction)
#		state = wait
#		grid[column][row] = other_block_unit
#		grid[column + direction.x][row + direction.y] = first_block_unit
#		first_block_unit.move(grid_to_pixel(column + direction.x, row + direction.y))
#		other_block_unit.move(grid_to_pixel(column, row))
#		if !move_checked:
#			find_matches()
#
#func store_info(first_block_unit, other_block_unit, place, direciton):
#	block_unit_one = first_block_unit
#	block_unit_two = other_block_unit
#	last_place = place
#	last_direction = direciton
#	pass
#
#func swap_back():
#	if block_unit_one != null && block_unit_two != null:
#		swap_block_units(last_place.x, last_place.y, last_direction)
#	state = move
#	move_checked = false
#
#func touch_difference(grid_1, grid_2):
#	var difference = grid_2 - grid_1
#	if abs(difference.x) > abs(difference.y):
#		if difference.x > 0:
#			swap_block_units(grid_1.x, grid_1.y, Vector2(1, 0))
#		elif difference.x < 0:
#			swap_block_units(grid_1.x, grid_1.y, Vector2(-1, 0))
#	elif abs(difference.y) > abs(difference.x):
#		if difference.y > 0:
#			swap_block_units(grid_1.x, grid_1.y, Vector2(0, 1))
#		elif difference.y < 0:
#			swap_block_units(grid_1.x, grid_1.y, Vector2(0, -1))
#
#func _process(_delta):
#	if state == move:
#		touch_input()
#
#func find_matches():
#	for i in width:
#		for j in height:
#			if grid[i][j] != null:
#				var current_color = grid[i][j].color
#				if i > 0 && i < width -1:
#					if !is_piece_null(i - 1, j) && !is_piece_null(i + 1, j):
#						if grid[i - 1][j].color == current_color && grid[i + 1][j].color == current_color:
#							match_and_dim(grid[i - 1][j])
#							match_and_dim(grid[i][j])
#							match_and_dim(grid[i + 1][j])
#				if j > 0 && j < height -1:
#					if !is_piece_null(i, j - 1) && !is_piece_null(i, j + 1):
#						if grid[i][j - 1].color == current_color && grid[i][j + 1].color == current_color:
#							match_and_dim(grid[i][j - 1])
#							match_and_dim(grid[i][j])
#							match_and_dim(grid[i][j + 1])
#	destroy_timer.start()
#
#func is_piece_null(column, row):
#	if grid[column][row] == null:
#		return true
#	return false
#
#func match_and_dim(item):
#	item.matched = true
#	item.dim()
#
#func destroy_matches():
#	var was_matched = false
#	for i in width:
#		for j in height:
#			if grid[i][j] != null:
#				if grid[i][j].matched:
#					was_matched = true
#					grid[i][j].queue_free()
#					grid[i][j] = null
#	move_checked = true
#	if was_matched:
#		collapse_timer.start()
#	else:
#		swap_back()
#
#func collapse_columns():
#	for i in width:
#		for j in height:
#			if grid[i][j] == null && !restricted_fill(Vector2(i,j)):
#				for k in range(j + 1, height):
#					if grid[i][k] != null:
#						grid[i][k].move(grid_to_pixel(i, j))
#						grid[i][j] = grid[i][k]
#						grid[i][k] = null
#						break
#	refill_timer.start()
#
#func refill_columns():
#	for i in width:
#		for j in height:
#			if grid[i][j] == null && !restricted_fill(Vector2(i,j)):
#				var rand = floor(randf_range(0, possible_block_units.size()))
#				var block_unit = possible_block_units[rand].instantiate()
#				var loops = 0
#				while (match_at(i, j, block_unit.color) && loops < 100):
#					rand = floor(randf_range(0,possible_block_units.size()))
#					loops += 1
#					block_unit = possible_block_units[rand].instantiate()
#				add_child(block_unit)
#				block_unit.position = grid_to_pixel(i, j - y_offset)
#				block_unit.move(grid_to_pixel(i,j))
#				grid[i][j] = block_unit
#	after_refill()
#
#func after_refill():
#	for i in width:
#		for j in height:
#			if grid[i][j] != null:
#				if match_at(i, j, grid[i][j].color):
#					find_matches()
#					destroy_timer.start()
#					return
#	state = move
#	move_checked = false
#
