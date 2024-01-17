extends TileMap

func _test() -> void:
	var t = tile_set

# converter/translate atlas postion to possible_block_units_kvp key
func _get_key(pos: Vector2i) -> String:
	var globals = get_node("res://scripts/autoload_globals.gd")
	# iterate through possible_block_units_kvp and find the key that matches the atlas position
	for key in globals.possible_block_units_kvp.keys():
		var atlas_pos = globals.possible_block_units_kvp[key]["atlas"]
		if atlas_pos == pos:
			return key
	return "void" 	# failure, no key found, default to void

# convert/translate key to atlas position
func _get_atlas_pos(key: String) -> Vector2i:
	var globals = get_node("res://scripts/autoload_globals.gd")
	# unsure how Godot handles invalid keys (i.e. most functional languages prefer to crash), so we'll do find first
	if !globals.possible_block_units_kvp.has(key):
		return Vector2i(-1, -1) 	# failure, return invalid position
	var atlas_pos = globals.possible_block_units_kvp[key]["atlas"]
	return atlas_pos

# return N (count) tiles without popping
func peek(count):
	pass
	# if count is > queue size, return up to queue size


# Returns an array (in sequential order) of tiles for pushing and popping
# The array is basically dictionary keys from possible_block_units_kvp
func get_queue() -> Array:
	return null
	
	
	# get number of tiles in the map; depending on how it was layed out, it could be
	# number of rows in single column (vertical), or number of columns in single row (horizontal)
	# but either way, either column or row is 1, and the other is the number of tiles
	var queue_rect = get_used_rect()
	var tile_rect_dim = queue_rect.size 	# assumes either column or row is 1

	var tiles =  []
	if tile_rect_dim.x == 1:
		# assume it's vertical
		for i in range(tile_rect_dim.y):
			var cell = tile_rect_dim[0][i]
			var tile = _get_key(cell)
			tiles.append(tile)
	elif tile_rect_dim.y == 1:
		# assume it's horizontal
		queue_size = tile_rect_dim.x
	else:
		# failure/assert, neither is 1
		pass 	# TODO: assert if neither of them is 1

	# build an array of tiles in the queue
	for i in range(queue_size):
		var tile = _get_key()
		tiles.append(tile)

func _ready() -> void:
	# generate N random tiles 
	for i in range(queue_size):
		push()


func pop():
	# return head of the queue
	pass

func make_random_cell():
	var globals = get_node("res://scripts/autoload_globals.gd")

	var rand = floor(randf_range(0, globals.possible_block_units_kvp.size()))
	var block_unit = globals.possible_block_units_kvp.values()[rand]
	return block_unit

func push():
	# first see if we're at the max-limit, if so, pop() to make space
	
	# randomize and add to queue
	next_cells_queue.append(make_random_cell())
	
#func _process(delta: float) -> void:
