extends TileMap

func _ready() -> void:
	var tile_dimension = self.get_used_rect().size
	assert(tile_dimension.x > 0, "TileMap_NextTiles.gd._ready() - tile dimension is 0, this is not allowed")
	assert(tile_dimension.y > 0, "TileMap_NextTiles.gd._ready() - tile dimension is 0, this is not allowed")
	var queue_size = tile_dimension.x * tile_dimension.y
	print("\n\nTileMap_NextTiles.gd._ready() - tile dimension" + str(tile_dimension) + " -> " + str(queue_size))
	assert(queue_size > 0, "TileMap_NextTiles.gd._ready() - queue size is 0, this is not allowed")
	
	var k_layer = 0
	AutoloadGlobals.reset_all_to_voids(self, k_layer, true) # now that we've got the dimension, clear it and make it all void
	var void_source_id = AutoloadGlobals.possible_block_units_kvp[AutoloadGlobals.BLOCK_KEYS.VOID]["source_id"]

	# generate N random tiles 
	for i in range(queue_size):
		push_cell_tail(k_layer)

	var layered_maps: Array[Array] = AutoloadGlobals.evaluate_tilemap(self, "Playfield.gd._ready()")
	
	#AutoloadGlobals.cell_clicked.connect(_on_cell_clicked)

#func _process(delta: float) -> void:
	
#func _on_cell_clicked(cell_value: AutoloadGlobals.BLOCK_KEYS, cell_position: Vector2i):
#	# we really care-less on what cell was there, all we care about is to pop the head and add new cell to tail
#	pop_cell_head()
#	push_cell_tail()


# pops the head and makes sure to populate the tail with new random cell
func get_head() -> AutoloadGlobals.BLOCK_KEYS:
	var k_layer = 0
	var ret_key = pop_cell_head(k_layer)
	push_cell_tail(k_layer)
	return ret_key
	
# return N (count) tiles without popping
func peek(count) -> Array[AutoloadGlobals.BLOCK_KEYS]:
	var ret_array = []
	# if count is > queue size, return up to queue size
	var tile_dimension = self.get_used_rect().size
	assert(tile_dimension.x > 0, "TileMap_NextTiles.gd.peek() - tile dimension is 0, this is not allowed")
	assert(tile_dimension.y > 0, "TileMap_NextTiles.gd.peek() - tile dimension is 0, this is not allowed")
	if count > tile_dimension.x * tile_dimension.y:
		count = tile_dimension.x * tile_dimension.y

	for cell_index_x in range(0, tile_dimension.x ):
		for cell_index_y in range(0, tile_dimension.y ):
			var cell_source_id = self.get_cell_source_id(0, Vector2i(cell_index_x, cell_index_y))
			var cell_key = get_key_from_source_id(cell_source_id)
			if ret_array.size() < count:
				ret_array.append(cell_key)
			else:
				# opt out early, we're done
				return ret_array

	return ret_array

# Returns an array (in sequential order) of tiles for pushing and popping
# The array is basically dictionary keys from possible_block_units_kvp
func get_queue() -> Array:
	var tile_dimension = self.get_used_rect().size
	assert(tile_dimension.x > 0, "TileMap_NextTiles.gd.get_queue() - tile dimension is 0, this is not allowed")
	assert(tile_dimension.y > 0, "TileMap_NextTiles.gd.get_queue() - tile dimension is 0, this is not allowed")
	var array_size = tile_dimension.x * tile_dimension.y
	return peek(array_size)

func get_key_from_source_id(source_id: int) -> AutoloadGlobals.BLOCK_KEYS:
	for key in AutoloadGlobals.possible_block_units_kvp.keys():
		if AutoloadGlobals.possible_block_units_kvp[key]["source_id"] == source_id:
			return key
	return AutoloadGlobals.BLOCK_KEYS.VOID

# return the key-name (of the dictionary) from the head of the queue (pop_cell_head the head)
# AND make sure to shift all slots so that the tail is now empty (VOID)
# NOTE: Pop does not really erase the head, what it really does is shifts all cells towards the head
# without affecting the (x,y) coordinates of the cell, and forcing/setting the tail to VOID
# Basically, the array size will NEVER grow or shrink (making it a bit more thread-safe this way)
func pop_cell_head(k_layer: int) -> AutoloadGlobals.BLOCK_KEYS:
	var void_source_id = AutoloadGlobals.possible_block_units_kvp[AutoloadGlobals.BLOCK_KEYS.VOID]["source_id"]

	# get the layered queues as an Array so it's easier to work with on push/pop
	var layered_queues: Array[Array] = AutoloadGlobals.evaluate_tilemap(self, "TileMap_NextTiles.gd.pop_cell_head()")
	assert(layered_queues.size() > 0, "There must be at least ONE layer for the queue TileMap")
	assert(layered_queues.size() > k_layer, "The layer index is out of bound for the queue TileMap")
	assert(layered_queues[0].size() > 0, "There must be at least ONE cell in the queue TileMap")
	# Assume that the TileMap is 1xN, and has NO holes, if there are available slots, they are marked as VOID source_id
	# hence queue[layer][0] is ALWAYS the head
	var queue = layered_queues[k_layer] as Array[AutoloadGlobals.CBlockUnit]
	var popped_head_block: AutoloadGlobals.CBlockUnit = queue[0] as AutoloadGlobals.CBlockUnit

	# shift all cells towards the head, and set the tail to VOID
	# NOTE also that we ASSUME queue is 1xN, hence the size of the array returned is the size (length/height) of the queue
	# edge case: if queue size is 1, then we just set it to VOID
	if queue.size() == 1:
		#self.set_cell(popped_head_block.Layer, popped_head_block.GridMapCoordinate, void_source_id, Vector2i(0, 0))
		AutoloadGlobals.set_cell_by_key(self, popped_head_block.Layer, popped_head_block.GridMapCoordinate, AutoloadGlobals.BLOCK_KEYS.VOID)	
		return popped_head_block.Key

	for i in range(0, queue.size() - 1):
		var current_cell = queue[i] as AutoloadGlobals.CBlockUnit
		var next_cell = queue[i + 1] as AutoloadGlobals.CBlockUnit

		# FOR DEBUG: Comment lines below for they eat up CPU
		var current_cell_source_id = AutoloadGlobals.possible_block_units_kvp[current_cell.Key]["source_id"]
		var next_cell_source_id = AutoloadGlobals.possible_block_units_kvp[next_cell.Key]["source_id"]
		if current_cell.GridMapCoordinate.y == 0:
			print(str(current_cell.GridMapCoordinate) + ": Old=" + str(current_cell_source_id) + " -> New=" + str(next_cell_source_id) + " (NEW, key=" + str(next_cell.Key) + ":" + str(AutoloadGlobals.possible_block_units_kvp[next_cell.Key]["resource_path"]) + ")")
		elif current_cell_source_id != next_cell_source_id:
			print(str(current_cell.GridMapCoordinate) + ": " + str(current_cell_source_id) + " != " + str(next_cell_source_id) + " (BUG!, key=" + str(next_cell.Key) + ":" + str(AutoloadGlobals.possible_block_units_kvp[next_cell.Key]["resource_path"]) + ")")
		else:
			print(str(current_cell.GridMapCoordinate) + ": " + str(current_cell_source_id) + " (key=" + str(next_cell.Key) + ":" + str(AutoloadGlobals.possible_block_units_kvp[next_cell.Key]["resource_path"]) + ")")
		# END DEBUG

		# usage of TileSetScenesCollectionSource requires atlas position to always be (0, 0) (not (-1, -1))
		#self.set_cell(current_cell.Layer, current_cell.GridMapCoordinate, next_cell_source_id, Vector2i(0, 0))
		AutoloadGlobals.set_cell_by_key(self, current_cell.Layer, current_cell.GridMapCoordinate, next_cell.Key)

	# now set the tail to VOID
	#self.set_cell(popped_head_block.Layer, Vector2i(popped_head_block.GridMapCoordinate.x, queue.size() - 1), void_source_id, Vector2i(0, 0))
	AutoloadGlobals.set_cell_by_key(self, popped_head_block.Layer, Vector2i(popped_head_block.GridMapCoordinate.x, queue.size() - 1), AutoloadGlobals.BLOCK_KEYS.VOID)

	return popped_head_block.Key

# returns the key of a random block unit from the possible_block_units_kvp
func get_random_key() -> AutoloadGlobals.BLOCK_KEYS:
	var tileset_scene = AutoloadGlobals.AutoloadPlayfieldCellTileset

	var first_valid_rand_key = 2	# skip BLOCK_KEYS.VOID(1) and BLOCK_KEYS.UNDEFINED(0)
	var rand = floor(randf_range(first_valid_rand_key, AutoloadGlobals.possible_block_units_kvp.size()))
	var key = AutoloadGlobals.possible_block_units_kvp.keys()[rand]
	return key

# Push a random block unit to the TAIL of the queue (and pop is from the HEAD)
# NOTE: Push does not really add new cell to the tail, but rather, it locates the
# first available cell (VOID) and replaces it with a new block unit without
# affecting the (x,y) coordinates of the cell
# If there are no vailable cell, then we pop the head to make space
# (basically, shift 2nd cell to first, shift all down and set final/tail cell to VOID,
# and then we'd replace that new VOID cell with the new block/cell unit)
# Having a fixed size array (queue) makes it a bit more thread-safe...
func push_cell_tail(k_layer: int):
	var void_source_id = AutoloadGlobals.possible_block_units_kvp[AutoloadGlobals.BLOCK_KEYS.VOID]["source_id"]

	# first see if we're at the max-limit, if so, pop_cell_head() to make space
	var tile_dimension = self.get_used_rect().size
	var tiles = tile_dimension.x * tile_dimension.y
	assert(tile_dimension.x > 0, "TileMap_NextTiles.gd.push_cell_tail() - tile dimension is 0, this is not allowed")
	assert(tile_dimension.y > 0, "TileMap_NextTiles.gd.push_cell_tail() - tile dimension is 0, this is not allowed")

	# NOTE: Assume the queue TileMap is 1xN, hence the size of the array returned is the size (length/height) of the queue
	var layered_queues: Array[Array] = AutoloadGlobals.evaluate_tilemap(self, "TileMap_NextTiles.gd.push_cell_tail()")
	assert(layered_queues.size() > 0, "There must be at least ONE layer for the queue TileMap")
	assert(layered_queues.size() > k_layer, "The layer index is out of bound for the queue TileMap")
	assert(layered_queues[0].size() > 0, "There must be at least ONE cell in the queue TileMap")
	# Assume that the TileMap is 1xN, and has NO holes, if there are available slots, they are marked as VOID source_id
	# hence queue[layer][0] is ALWAYS the head
	var queue = layered_queues[k_layer] as Array[AutoloadGlobals.CBlockUnit]

	# also, assume that the length/size() of the queue array is always populated with something (i.e. use VOID as place holder)
	# cannot do blocks.find(AutoloadGlobals.BLOCK_KEYS.VOID, 0) to get index of first VOID position, since find does not use lambda,
	# so we'll count number of VOIDs and ASSUME that they are all at the tail (assumes "push" is equivalent to push_back if queue
	# size was dynamic)
	var void_count = queue.filter(func(x): return x.Key == AutoloadGlobals.BLOCK_KEYS.VOID).size()
	var dest_row_index = queue.size() - void_count 	# i.e. size=3, count=3, index=0; size=3, count=2, index=1; size=3, count=0; index=3; etc
	# edge-case when no void is found, we have to pop head to make space
	if void_count == 0:
		# if queue is full, pop the head to make space
		var discarded_head = pop_cell_head(k_layer)	# though not optimal, just grabbing the new queue is easier than shifting all cells down (and preserving the coordinates)
		var new_queue: Array[Array] = AutoloadGlobals.evaluate_tilemap(self, "TileMap_NextTiles.gd.push_cell_tail()")
		queue = new_queue[k_layer] as Array[AutoloadGlobals.CBlockUnit]
		dest_row_index = queue.size() - 1

	# now push to the first available slot
	var new_key = get_random_key()
	var source_id = AutoloadGlobals.possible_block_units_kvp[new_key]["source_id"]
	var block = queue[dest_row_index] as AutoloadGlobals.CBlockUnit
	#self.set_cell(block.Layer, block.GridMapCoordinate, source_id, Vector2i(0, 0))
	AutoloadGlobals.set_cell_by_key(self, block.Layer, block.GridMapCoordinate, new_key)
	print("Updating TileMap with new block unit: " + str(block.GridMapCoordinate) + "=" + str(new_key) + " (dest_row_index=" + str(dest_row_index) + ")"	)
	
