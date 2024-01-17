extends Node

# NOTE: If you try to @export AND @onready on a same variable, @export will stomp/override
# what was set in @onready.  i.e.:
# @onready @export var my_custom_meter_value = "init_hello"  # make sure to set it to "export_goodbye" in the Inspector editor
# on _ready() func, it will assume the var to be "hello", but if on inspector editor, it was set to "goodbye"

# reference this as globals.AutoloadPlayfieldCellTileset rather than via get_node() as a backup method
@onready var AutoloadPlayfieldCellTileset =  null

# load from persisted storage (will @export) so that it can be set via editor
@export var settings = {
	"test_var_1": 0,
	"test_var_2": 1,
}

# cell_clicked signal notifies subscribers to pop the head and push to tail, animate, etc
signal cell_clicked(cell_value: AutoloadGlobals.BLOCK_KEYS, cell_position: Vector2i)

# constants
enum BLOCK_KEYS {
	UNDEFINED,
	VOID,
	LINE_BLOCK1,
	LINE_BLOCK2,
	LINE_BLOCK3,
	LINE_BLOCK4,
	ROUTE1_STRAIGHT,
	ROUTE1_90DEG,
	ROUTE2,
	ROUTE3,
	ROUTE_JOIN2T,
	ROUTE_JOIN3,
	JUNCTION,
}

# When the atlas position changes in TileSet "playfield_cell_tileset.tres", in which TileSet has been
# named per tile so that it can be reverse looked up by name rather than by atlas-position which can
# change and is not too ideal...
# NOTE that the value is based on what is needed to get and set cells;  If we're calling/using 'TileMap.set_cell()',
# we generally want the Vector2i atlas_coords for TileSetAtlasSource.  For TileSetScenesCollectionSource, we'd
# force/assume atlas coordinate is always Vector2i(0,0) (as documented in TileMap.set_cell()), and we'd want to
# record-and-lookup source_id associated to the tile.
# Value associated to the Key are:
# * reference pointer of the preload() scene
# * resource_path of the scene for quick lookup against TileSet source (for TileSetScenesCollectionSource)
# * source_id - for aformenetioned TileSetScenesCollectionSource, we need to know which source_id to use
# Source_ID can be visually spotted (even edited) via visual editor under "Tiles" panel for each scenes
# which represents as a tile, but one can also dynamically lookup via TileSet.get_source_id(index) followed by TileSet.get_source(source_id) 
# (or TileSetScenesCollectionSource.get_scene_tile_id(index)), all in all, what we need is to associate source_id for each tile
# which we find in the TileSet of the TileMap so that we can take actions correctly.
# In any case, this author has decided to dynamically extract source_id rather than hard-code assign it, because this authoer
# is too lazy to remember to update the source_id when the tileset gets deleted/removed and re-added, edited (the source_id) via
# editor, or removed.  It's pain enough that if the paths (including filenames) of the scene changes, I'd have to update the
# dictionary below, but at least I don't have to remember to update the source_id.
@onready var possible_block_units_kvp = {
	BLOCK_KEYS.LINE_BLOCK1: { "scene": preload("res://scenes/block_units/line_block1.tscn"), "resource_path": "res://scenes/block_units/line_block1.tscn" , "source_id": 3 },
	BLOCK_KEYS.LINE_BLOCK2: { "scene": preload("res://scenes/block_units/line_block2.tscn"), "resource_path": "res://scenes/block_units/line_block2.tscn" , "source_id": 4 },
	BLOCK_KEYS.LINE_BLOCK3: { "scene": preload("res://scenes/block_units/line_block3.tscn"), "resource_path": "res://scenes/block_units/line_block3.tscn" , "source_id": 5 },
	BLOCK_KEYS.LINE_BLOCK4: { "scene": preload("res://scenes/block_units/line_block4.tscn"), "resource_path": "res://scenes/block_units/line_block4.tscn" , "source_id": 6 },
	BLOCK_KEYS.ROUTE1_STRAIGHT: { "scene": preload("res://scenes/block_units/route1_straight.tscn"), "resource_path": "res://scenes/block_units/route1_straight.tscn" , "source_id": 8 },
	BLOCK_KEYS.ROUTE1_90DEG: { "scene": preload("res://scenes/block_units/route1_90deg.tscn"), "resource_path": "res://scenes/block_units/route1_90deg.tscn" , "source_id": 7 },
	BLOCK_KEYS.ROUTE2: { "scene": preload("res://scenes/block_units/route2.tscn"), "resource_path": "res://scenes/block_units/route2.tscn" , "source_id": 9 },
	BLOCK_KEYS.ROUTE3: { "scene": preload("res://scenes/block_units/route3.tscn"), "resource_path": "res://scenes/block_units/route3.tscn" , "source_id": 10 },
	BLOCK_KEYS.ROUTE_JOIN2T: { "scene": preload("res://scenes/block_units/route_join2T.tscn"), "resource_path": "res://scenes/block_units/route_join2T.tscn" , "source_id": 11 },
	BLOCK_KEYS.ROUTE_JOIN3: { "scene": preload("res://scenes/block_units/route_join3.tscn"), "resource_path": "res://scenes/block_units/route_join3.tscn" , "source_id": 12 },
	BLOCK_KEYS.VOID: { "scene": preload("res://scenes/block_units/void.tscn"), "resource_path": "res://scenes/block_units/void.tscn" , "source_id": 13 },
	BLOCK_KEYS.JUNCTION: { "scene": preload("res://scenes/block_units/junction.tscn"), "resource_path": "res://scenes/block_units/junction.tscn" , "source_id": 2 },
}

# class based for usage by function return in flattened array (i.e. Array[CBLockUnit])
class CBlockUnit:
	var Key: BLOCK_KEYS
	var GridMapCoordinate: Vector2i	# 0-based, just happens (because it's 0-based) that (x,y) index are always in the same order as the grid
	var Layer: int

# offer few find() function, mainly because Dictionary does not have a filter(lambda) function
func get_key_from_resource_path(resource_path: String) -> BLOCK_KEYS:
	for key in possible_block_units_kvp:
		if possible_block_units_kvp[key]["resource_path"] == resource_path:
			return key
	return BLOCK_KEYS.VOID	# either return "" empty-string or "void"

func get_key_from_source_id(source_id: int) -> BLOCK_KEYS:
	# treat -1 (source_id is "empty") as "void"
	if source_id == -1:	
		return BLOCK_KEYS.VOID

	for key in possible_block_units_kvp:
		if possible_block_units_kvp[key]["source_id"] == source_id:
			return key
	return BLOCK_KEYS.VOID	# either return "" empty-string or "void"

func _extract_filename_from_resource_path(resource_path: String) -> String:
	var path = resource_path
	var filename = ""
	while path != "":
		var path_and_filename = path
		var path_and_filename_split = path_and_filename.split("/")
		var path_and_filename_split_count = path_and_filename_split.size()
		if path_and_filename_split_count > 0:
			filename = path_and_filename_split[path_and_filename_split_count - 1]
			break
		else:
			path = path_and_filename
	return filename

# updates possible_block_units_kvp[key].source_id
func _update_source_id_tilemap(tilemap: TileMap) -> void:
	# first, get count of all the tiles in TileSet, determine whether it is TileSetScenesCollectionSource, and if so, get the source_id
	var tileset = tilemap.tile_set
	return _update_source_id(tileset)

func _update_source_id(tileset: TileSet) -> void:
	# first, get count of all the tiles in TileSet, determine whether it is TileSetScenesCollectionSource, and if so, get the source_id
	var source_count = tileset.get_source_count()
	#print ("source_count: " + str(source_count))
	for source_index in range(source_count):
		var source_id = tileset.get_source_id(source_index)
		#print("index=" + str(source_index) + " - source_id: " + str(source_id))
		var source = tileset.get_source(source_id)
		if source is TileSetScenesCollectionSource:
			var scenes_in_this_tile = source.get_scene_tiles_count() # should usually just be 1, but in case there are more...
			for scene_tiles_index in range(scenes_in_this_tile):
				var tile_id = source.get_scene_tile_id(scene_tiles_index)
				var packed_scene = source.get_scene_tile_scene(tile_id)

				var found = get_key_from_resource_path(packed_scene.resource_path)
				if found != BLOCK_KEYS.UNDEFINED:
					print("Resource found '" + str(found) + "' in possible_block_units_kvp: '" + str(packed_scene.resource_path) + "', updating ID=" + str(source_id) )
					possible_block_units_kvp[found]["source_id"] = source_id
					print("# possible_block_units_kvp[" + str(found) + "]: " + str(possible_block_units_kvp[found]))
					#return id
				else:
					var filename = _extract_filename_from_resource_path(packed_scene.resource_path)
					possible_block_units_kvp[filename]["source_id"] = source_id
					print("Resource not found in possible_block_units_kvp: '" + str(packed_scene.resource_path) + "' filename: '" + str(filename) + "', adding source_id=" + str(source_id) + " to possible_block_units_kvp")
					print("# possible_block_units_kvp[" + str(filename) + "]: " + str(possible_block_units_kvp[filename]))
					#return id
		else:
			print("Source is not TileSetScenesCollectionSource: " + str(source))
	#return -1

# updates possible_block_units_kvp[key].source_id 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# NOTE: Autoload will only load Scene or GDScript, hence if tileset is still
	# in TRES format, the below will fail...
	if AutoloadPlayfieldCellTileset == null:
		AutoloadPlayfieldCellTileset = preload('res://scenes/playfield_cell_tileset.tres')

	#var globals = get_node("/rootPlayfiledCellTileset/AutoloadGlobals")
	
	# update possible_block_units_kvp with what is currently setup 
	if AutoloadPlayfieldCellTileset != null:
		if AutoloadPlayfieldCellTileset is TileSet:
			var tileset = AutoloadPlayfieldCellTileset
			_update_source_id(tileset)
		elif AutoloadPlayfieldCellTileset is TileMap:
			var tilemap = AutoloadPlayfieldCellTileset
			_update_source_id_tilemap(tilemap)
		#else:
		#	print("AutoloadPlayfieldCellTileset is not TileSet: " + str(AutoloadPlayfieldCellTileset))
	
	# DEBUG
	for key in possible_block_units_kvp.keys():
		print("possible_block_units_kvp[" + str(key) + "]: " + str(possible_block_units_kvp[key]))
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


# According to github source code for Layer.fix_invalid_tiles(), it is supposed to be it tests for:
# * if atlas coordinate is valid
# * if source_id is valid (i.e. not -1)
# * if alternative_tile is valid (i.e. not -1)
func locate_invalid_tiles(tilemap:TileMap) -> void:
	assert(tilemap.get_used_rect().size.x > 0, "tile dimension is x=0, this is not allowed")
	assert(tilemap.get_used_rect().size.y > 0, "tile dimension is y=0, this is not allowed")

	var invalid_count = 0
	for layer in tilemap.get_layers_count():
		if tilemap.is_layer_enabled(layer):
			for cell in tilemap.get_used_cells(layer):
				var source_id = tilemap.get_cell_source_id(layer, cell)
				var atlas_coords = tilemap.get_cell_atlas_coords(layer, cell)
				var alternative_tile = tilemap.get_cell_alternative_tile(layer, cell)
				if source_id == -1 or atlas_coords == Vector2i(-1, -1) or alternative_tile == -1:
					print("Invalid tile found at: layer=" + str(layer) + " cell="+ str(cell) + " source_id=" + str(source_id) + " atlas_coords=" + str(atlas_coords) + " alternative_tile=" + str(alternative_tile))
					#tilemap.set_cell(0, cell, possible_block_units_kvp[BLOCK_KEYS.VOID]["source_id"], Vector2i(0,0), 0)
					invalid_count += 1
	assert(invalid_count == 0, "Invalid tiles found, please fix them before continuing")

# TODO: When all is working, replace the debug call version with the non-debug version
func set_cell_by_source_id(tilemap: TileMap, layer: int, cell_position: Vector2i, source_id: int) -> void:
	var key = get_key_from_source_id(source_id)
	set_cell_by_key(tilemap, layer, cell_position, key)

	# NON-DEBUG version:
	#tilemap.set_cell(layer, cell_position, source_id, Vector2i(0,0), 0)

# TODO: When all is working, replace the debug call version with the non-debug version
func set_cell_by_key(tilemap: TileMap, layer: int, cell_position: Vector2i, block_key: BLOCK_KEYS) -> void:
	set_cell_by_key_debug(tilemap, layer, cell_position, block_key)

	# NON-DEBUG version:
	#tilemap.set_cell(layer, cell_position, possible_block_units_kvp[block_key]["source_id"], Vector2i(0,0), 0)

func set_cell_by_key_debug(tilemap: TileMap, layer: int, cell_position: Vector2i, block_key: BLOCK_KEYS) -> void:
	var source_id = possible_block_units_kvp[block_key]["source_id"]
	var atlas_coords = tilemap.get_cell_atlas_coords(layer, cell_position) #	Vector2i(0,0)	# for TileSetScenesCollectionSource, it's always (0, 0)
	var alternative_tile = tilemap.get_cell_alternative_tile(layer, cell_position) # 0	# for TileSetScenesCollectionSource, it's always 0
	var current_source_id = tilemap.get_cell_source_id(layer, cell_position)	# -1 if cell is empty
	assert(source_id != -1, "source_id is -1 for block_key=" + str(block_key) + " (map/grid position " + str(cell_position) + ", layer " + str(layer) + ")")
	assert(atlas_coords != Vector2i(-1, -1), "atlas_coords is (-1, -1) at map/grid position " + str(cell_position) + " for layer " + str(layer) )
	assert(alternative_tile != -1, "alternative_tile is -1 at map/grid position " + str(cell_position) + " for layer " + str(layer) )
	assert(current_source_id != -1, "current_source_id is -1 at map/grid position " + str(cell_position) + " for layer " + str(layer) )

	print("\nset_cell(): layer=" + str(layer) + " " + str(cell_position) + ": Key=" + str(block_key) + " - SourceID=" + str(possible_block_units_kvp[block_key]["source_id"]) + ", resouce_path: '" + str(possible_block_units_kvp[block_key]["resource_path"]) + "'")	
	print("Current source_id: " + str( current_source_id ))
	print("Current atlas coords: " + str( atlas_coords) )
	print("Current alternative_tile: " + str( alternative_tile ))
	print("Current dimensions: " + str(tilemap.get_used_rect().size))
	assert(tilemap.get_used_rect().size.x > 0, "tile dimension is x=0, this is not allowed")
	assert(tilemap.get_used_rect().size.y > 0, "tile dimension is y=0, this is not allowed")

	if atlas_coords == Vector2i(-1, -1):
		print("WARNING: atlas_coords is (-1, -1), this is not allowed, setting to (0, 0)")
		atlas_coords = Vector2i(0, 0)
	if alternative_tile == -1:
		print("WARNING: alternative_tile is -1, this is not allowed, setting to 0")
		alternative_tile = 0
	if source_id == -1:
		print("WARNING: source_id is -1, this is not allowed, setting to VOID")
		source_id = possible_block_units_kvp[BLOCK_KEYS.VOID]["source_id"]

	# dump health of tilemap before we set_cell()
	var dimension_prior_to_fix = tilemap.get_used_rect().size
	locate_invalid_tiles(tilemap)
	tilemap.fix_invalid_tiles()
	locate_invalid_tiles(tilemap)
	var dimension_post_fix = tilemap.get_used_rect().size
	assert(dimension_post_fix == dimension_prior_to_fix, "dimension changed from " + str(dimension_prior_to_fix) + " to " + str(dimension_post_fix))

	# take snapshot before and after set_cell() to understand why fix_invalid_tiles() shrinks/removes the tilemap of what has been removed
	var dim_before_set = tilemap.get_used_rect().size
	assert(dimension_prior_to_fix == dim_before_set, "dimension changed from " + str(dimension_prior_to_fix) + " to " + str(dim_before_set))
	tilemap.set_cell(layer, cell_position, source_id, atlas_coords, alternative_tile)
	var dim_after_set = tilemap.get_used_rect().size
	assert(dim_before_set == dim_after_set, "dimension changed from " + str(dim_before_set) + " to " + str(dim_after_set))

	# WARNING: calling fix_invalid_tiles() AFTER set_cell() will shrink the tilemap if there are any invalid tiles, in which we do not want
	# because we want to preserve the original dimension of the tilemap, hence we call fix_invalid_tiles() is only here for tracking
	# before and after set_cell() to understand why fix_invalid_tiles() shrinks/removes the tilemap of what has been removed
	dimension_prior_to_fix = tilemap.get_used_rect().size
	assert(dim_before_set == dimension_prior_to_fix, "dimension changed from " + str(dimension_prior_to_fix) + " to " + str(dimension_post_fix))
	locate_invalid_tiles(tilemap)
	tilemap.fix_invalid_tiles()
	locate_invalid_tiles(tilemap)
	dimension_post_fix = tilemap.get_used_rect().size
	assert(dim_before_set == dimension_post_fix, "dimension changed from " + str(dim_before_set) + " to " + str(dimension_post_fix))
	assert(dimension_post_fix == dimension_prior_to_fix, "dimension changed from " + str(dimension_prior_to_fix) + " to " + str(dimension_post_fix))
	
	# DEBUG
	print("success: set_cell: (" + str(cell_position.x) + ", " + str(cell_position.y) + "): " + str(source_id))

# we do not want to call TileMap.clear() for it will destroy the (x,y) coordinates of the original
# location, hence all push/add and pop/delete are actually just setting new TileSet source_id to the cell
# without affecting the (x,y) coordinates of that orignal location/cell!
# we need to know which layer to operate on, since we can have multiple layers
# in which other layers may be used for collisions, path-finding, sfx, etc...
func reset_all_to_voids(tilemap: TileMap, layer: int, fill_hole_with_void: bool) -> void:
	var void_source_id = possible_block_units_kvp[BLOCK_KEYS.VOID]["source_id"]
	var tile_dimension = tilemap.get_used_rect().size
	assert(tile_dimension.x > 0 || tile_dimension.y > 0, "TileMap is empty rect")

	# No need to get cell per coordinate, since dimension SHOULD match the tilemap
	for x in range(tile_dimension.x):
		for y in range(tile_dimension.y):
			var original_source_id = tilemap.get_cell_source_id(layer, Vector2i(x, y), false)
			var strdebug = "reset_all_to_voids: (" + str(x) + ", " + str(y) + "): " + str(original_source_id)
			# NOTE: if the cell is -1 (unused, hole), it will be skipped rather than forced to VOID
			if fill_hole_with_void == true or original_source_id != -1:
				#tilemap.set_cell(layer, Vector2i(x, y), void_source_id, Vector2i(0,0), 0)
				set_cell_by_key(tilemap, layer, Vector2i(x, y), BLOCK_KEYS.VOID)
				strdebug += " -> " + str(void_source_id) + " (VOID)"
			print(strdebug)
	
# shared static function (hopefully thread-safe) - but make sure to use 'AutoloadGlobals.call_deferred("evaluate_tilemap", tilemap, "debug_label")' if you suspect race-conditions
func evaluate_tilemap(tilemap: TileMap, debug_label: String) -> Array[Array]:
	print("\n[" + debug_label + "] - ==========================================================")
	# evaluate this TileMap
	var origin = tilemap.position	# relative to parent node (in pixel)
	var tile_dimension = tilemap.get_used_rect().size
	assert(tile_dimension.x > 0 || tile_dimension.y > 0, "TileMap is empty rect")
	var layer_count = tilemap.get_layers_count()

	# evaluate the TileSet for this map
	print("[" + debug_label + "] - " + ": TileMap LayerCount=" + str(tilemap.get_layers_count()) + " @ origin=" + str(origin) + " tile_dimension=" + str(tile_dimension))
	assert(tile_dimension.x > 0 && tile_dimension.y > 0, "TileMap is empty rect")
	var layers:Array[Array] = []
	for layer_index in range(layer_count):
		var used_cells = tilemap.get_used_cells(layer_index)	# Note that there seems to be a bug in which when ALL TileMaps are post-loaded, this returns one extra row (i.e. 1x5 returns 5 rows when loaded as-is but becomes 6 rows when all TileMaps are loaded)
		var blocks: Array[CBlockUnit] = evaluate_tileset(tilemap.tile_set, layer_index, tile_dimension, used_cells, tilemap.get_cell_source_id, debug_label)
		layers.append(blocks)	# append() is alias to push_back()
	
	# report final dimensions of each layer
	print("[" + debug_label + "] - total layers return: " + str(layers.size()) + " (out of " + str(layer_count) + " layers)" )
	for layer : Array[CBlockUnit] in layers:
		var str_line = "layer.size=" + str(layer.size()) + " - "
		for block : CBlockUnit in layer:
			str_line += "(" + str(block.Layer) + ":" + str(block.GridMapCoordinate) + ":" + str(block.Key) + "),"
		print("[" + debug_label + "] - " + str_line)
			
	print("[" + debug_label + "] - ==========================================================\n")
	assert(layers.size() >= 1, "TileMap possibly incorrectly setup, there should be AT LEAST ONE layer with AT LEAST ONE tile")
	return layers

func _is_used(cell_coord: Vector2i, used_cells: Array[Vector2i]) -> bool:
	for used_cell in used_cells:
		if used_cell == cell_coord:
			return true
	return false

# It is preferred that one calls evaluate_tilemap() instead of this, so that you'd get a
# bigger picture of the specific TileMap (since TileSet can be shared...)
func evaluate_tileset(tileset: TileSet, layer_index: int, tile_dimension_map: Vector2i, used_cells_for_this_map: Array[Vector2i], tilemap_get_cell_source_id_callback: Callable, debug_label: String) -> Array[CBlockUnit]:
	var ret_blocks: Array[CBlockUnit] = []

	var tiles = tile_dimension_map.x * tile_dimension_map.y

	print("\n[" + debug_label + "]\t\t(autoload_globals.gd(evaluate_tileset())) - Dimension (get_used_rect()): (" + str(tile_dimension_map.x) + ", " + str(tile_dimension_map.y) + ")")

	# NOTE1: get_used_cells() returns "all cells", ambiguously meaning all Tiles on the map (i.e. if there are more than one TileMap, it will be combined)
	# NOTE2: the map-coordinates is equivalent to x-Index and y-Index of the grid (i.e. the first cell is at (0,0))
	# NOTE3: TileMap.get_used_cells() returns by column-order, hence for example, on a 2x3 map, it will return (0,0), (0,1), (0,2), (1,0), (1,1), (1,2)
	# but the map-grid is row-ordered, hence the first cell is at (0,0), and the second cell is at (1,0), etc...
	# TODO: It would be curious to see what happens when 2 or more TileMaps that has different grid dimension (i.e. one map is 16x16 while another is 64x64)
	print("[" + debug_label + "] - " + "\t\tTileSet layer_index=" + str(layer_index) + " used cells count=" + str(used_cells_for_this_map.size()))
	for cell_position in used_cells_for_this_map:
		# NOTE: used_cells (tilemap.get_used_cells) is relative to Node2D.Transform origin position, NOT entire map coordinates
		var str_pos = str(cell_position)
		if cell_position.x == -1 and cell_position.y == -1:
			str_pos = "EMPTY"
		print("[" + debug_label + "] - " + "\t\t\tcell_position=" + str_pos )

	# NOTE1: cell_xy_index are also analogous to x-Index and y-Index of the grid (i.e. the first cell is at (0,0))
	# NOTE2: Because tile_dimension_map is based on MAP coordinates, if/when the "other" TileMap gets added to the MAP, 
	# it's dimension will become BIGGER, hence you MUST use used_cells (tilemap.get_used_cells) to determine WHICH part of the grid is for THIS TileMap
	# NOTE3: Unsure if it is a bug or by-design, but there will (currently) always be an empty row at the tail/bottom,
	# hence for example, on a 1x5 grid, the 6th row will be EMPTY, on a 11x6, the 7th row will be EMPTY, etc...
	for cell_y_index in range(0 , tile_dimension_map.y ):		# see NOTE3 in regards to the empty row at the tail/bottom
		var str_line = "y=" + str(cell_y_index) + ": "
		for cell_x_index in range(0 , tile_dimension_map.x ):
			if _is_used(Vector2i(cell_x_index, cell_y_index), used_cells_for_this_map):
				#NOTE: index is (by design) anaolgous to map/grid coordinates
				var source_id_from_tilemap = tilemap_get_cell_source_id_callback.call(layer_index,  Vector2i(cell_x_index, cell_y_index))
				var block = CBlockUnit.new()
				block.Key = get_key_from_source_id(source_id_from_tilemap) # get_cell_source_id() retrurns -1 if cell DOES NOT EXIST
				block.GridMapCoordinate = Vector2i(cell_x_index, cell_y_index)
				block.Layer = layer_index
				var str_source_id = str(source_id_from_tilemap)
				if source_id_from_tilemap == -1:
					str_source_id = "EMPTY"
				#str_line += "[" + str(block.GridMapCoordinate.x) + "," + str(block.GridMapCoordinate.y) + "](" +  str_source_id + "," + block.Key + "), "
				str_line += "(" +  str_source_id + ":" + str(block.Key) + "), "
				# Based on NOTE3, because of the (current) way in which we always plave "something" ("void") preset, we assume that "EMPTY" (-1)
				# differs from "void" tile/cell, hence IF the very last row is EMPTY, assume it is the undesired extra row that was placed 
				var skip_row = false
				if cell_y_index == tile_dimension_map.y - 1 and cell_x_index == tile_dimension_map.x - 1 and source_id_from_tilemap == -1:
					# we've encountered that unwanted row...
					print("[" + debug_label + "] - " + "### Skipping (" + str(cell_y_index) + ", " + str(cell_x_index) + ") = " + str(source_id_from_tilemap) )
					skip_row = true
				else:
					ret_blocks.push_back(block)	# make sure to use push_back(alias to append()) (as compared to push_front() or insert(0, x) so it does not get re-indexed)
			else:
				str_line += str(Vector2i(cell_x_index, cell_y_index)) + "=UNUSED"
				var block = CBlockUnit.new()
				block.Key = BLOCK_KEYS.VOID
				block.GridMapCoordinate = Vector2i(cell_x_index, cell_y_index)
				block.Layer = layer_index
				ret_blocks.push_back(block)
		print("[" + debug_label + "] - " + str_line)

	print("Total blocks: " + str(ret_blocks.size()))
	assert(ret_blocks.size() >= 1, "TileMap possibly incorrectly setup, there should be AT LEAST ONE tile in a layer")
	return ret_blocks

# TileMap¶
# - void _tile_data_runtime_update ( int layer, Vector2i coords, TileData tile_data ) virtual
# - bool _use_tile_data_runtime_update ( int layer, Vector2i coords ) virtual
# - void add_layer ( int to_position )
# - void clear ( )
# - void clear_layer ( int layer )
# - void erase_cell ( int layer, Vector2i coords )
# - void fix_invalid_tiles ( )
# - void force_update ( int layer=-1 )
# - int get_cell_alternative_tile ( int layer, Vector2i coords, bool use_proxies=false ) const
# - Vector2i get_cell_atlas_coords ( int layer, Vector2i coords, bool use_proxies=false ) const
# - int get_cell_source_id ( int layer, Vector2i coords, bool use_proxies=false ) const
# - TileData get_cell_tile_data ( int layer, Vector2i coords, bool use_proxies=false ) const
# - Vector2i get_coords_for_body_rid ( RID body )
# - int get_layer_for_body_rid ( RID body )
# - Color get_layer_modulate ( int layer ) const
# - String get_layer_name ( int layer ) const
# - RID get_layer_navigation_map ( int layer ) const
# - int get_layer_y_sort_origin ( int layer ) const
# - int get_layer_z_index ( int layer ) const
# - int get_layers_count ( ) const
# - RID get_navigation_map ( int layer ) const
# - Vector2i get_neighbor_cell ( Vector2i coords, CellNeighbor neighbor ) const
# - TileMapPattern get_pattern ( int layer, Vector2i[] coords_array )
# - Vector2i[] get_surrounding_cells ( Vector2i coords )
# - Vector2i[] get_used_cells ( int layer ) const
# - Vector2i[] get_used_cells_by_id ( int layer, int source_id=-1, Vector2i atlas_coords=Vector2i(-1, -1), int alternative_tile=-1 ) const
# - Rect2i get_used_rect ( ) const
# - bool is_layer_enabled ( int layer ) const
# - bool is_layer_navigation_enabled ( int layer ) const
# - bool is_layer_y_sort_enabled ( int layer ) const
# - Vector2i local_to_map ( Vector2 local_position ) const
# - Vector2i map_pattern ( Vector2i position_in_tilemap, Vector2i coords_in_pattern, TileMapPattern pattern )
# - Vector2 map_to_local ( Vector2i map_position ) const
# - void move_layer ( int layer, int to_position )
# - void notify_runtime_tile_data_update ( int layer=-1 )
# - void remove_layer ( int layer )
# - void set_cell ( int layer, Vector2i coords, int source_id=-1, Vector2i atlas_coords=Vector2i(-1, -1), int alternative_tile=0 )
# - void set_cells_terrain_connect ( int layer, Vector2i[] cells, int terrain_set, int terrain, bool ignore_empty_terrains=true )
# - void set_cells_terrain_path ( int layer, Vector2i[] path, int terrain_set, int terrain, bool ignore_empty_terrains=true )
# - void set_layer_enabled ( int layer, bool enabled )
# - void set_layer_modulate ( int layer, Color modulate )
# - void set_layer_name ( int layer, String name )
# - void set_layer_navigation_enabled ( int layer, bool enabled )
# - void set_layer_navigation_map ( int layer, RID map )
# - void set_layer_y_sort_enabled ( int layer, bool y_sort_enabled )
# - void set_layer_y_sort_origin ( int layer, int y_sort_origin )
# - void set_layer_z_index ( int layer, int z_index )
# - void set_navigation_map ( int layer, RID map )
# - void set_pattern ( int layer, Vector2i position, TileMapPattern pattern )
# - void update_internals ( )
#
# TileSet¶
# - void add_custom_data_layer ( int to_position=-1 )
# - void add_navigation_layer ( int to_position=-1 )
# - void add_occlusion_layer ( int to_position=-1 )
# - int add_pattern ( TileMapPattern pattern, int index=-1 )
# - void add_physics_layer ( int to_position=-1 )
# - int add_source ( TileSetSource source, int atlas_source_id_override=-1 )
# - void add_terrain ( int terrain_set, int to_position=-1 )
# - void add_terrain_set ( int to_position=-1 )
# - void cleanup_invalid_tile_proxies ( )
# - void clear_tile_proxies ( )
# - Array get_alternative_level_tile_proxy ( int source_from, Vector2i coords_from, int alternative_from )
# - Array get_coords_level_tile_proxy ( int source_from, Vector2i coords_from )
# - int get_custom_data_layer_by_name ( String layer_name ) const
# - String get_custom_data_layer_name ( int layer_index ) const
# - Variant.Type get_custom_data_layer_type ( int layer_index ) const
# - int get_custom_data_layers_count ( ) const
# - bool get_navigation_layer_layer_value ( int layer_index, int layer_number ) const
# - int get_navigation_layer_layers ( int layer_index ) const
# - int get_navigation_layers_count ( ) const
# - int get_next_source_id ( ) const
# - int get_occlusion_layer_light_mask ( int layer_index ) const
# - bool get_occlusion_layer_sdf_collision ( int layer_index ) const
# - int get_occlusion_layers_count ( ) const
# - TileMapPattern get_pattern ( int index=-1 )
# - int get_patterns_count ( )
# - int get_physics_layer_collision_layer ( int layer_index ) const
# - int get_physics_layer_collision_mask ( int layer_index ) const
# - PhysicsMaterial get_physics_layer_physics_material ( int layer_index ) const
# - int get_physics_layers_count ( ) const
# - TileSetSource get_source ( int source_id ) const
# - int get_source_count ( ) const
# - int get_source_id ( int index ) const
# - int get_source_level_tile_proxy ( int source_from )
# - Color get_terrain_color ( int terrain_set, int terrain_index ) const
# - String get_terrain_name ( int terrain_set, int terrain_index ) const
# - TerrainMode get_terrain_set_mode ( int terrain_set ) const
# - int get_terrain_sets_count ( ) const
# - int get_terrains_count ( int terrain_set ) const
# - bool has_alternative_level_tile_proxy ( int source_from, Vector2i coords_from, int alternative_from )
# - bool has_coords_level_tile_proxy ( int source_from, Vector2i coords_from )
# - bool has_source ( int source_id ) const
# - bool has_source_level_tile_proxy ( int source_from )
# - Array map_tile_proxy ( int source_from, Vector2i coords_from, int alternative_from ) const
# - void move_custom_data_layer ( int layer_index, int to_position )
# - void move_navigation_layer ( int layer_index, int to_position )
# - void move_occlusion_layer ( int layer_index, int to_position )
# - void move_physics_layer ( int layer_index, int to_position )
# - void move_terrain ( int terrain_set, int terrain_index, int to_position )
# - void move_terrain_set ( int terrain_set, int to_position )
# - void remove_alternative_level_tile_proxy ( int source_from, Vector2i coords_from, int alternative_from )
# - void remove_coords_level_tile_proxy ( int source_from, Vector2i coords_from )
# - void remove_custom_data_layer ( int layer_index )
# - void remove_navigation_layer ( int layer_index )
# - void remove_occlusion_layer ( int layer_index )
# - void remove_pattern ( int index )
# - void remove_physics_layer ( int layer_index )
# - void remove_source ( int source_id )
# - void remove_source_level_tile_proxy ( int source_from )
# - void remove_terrain ( int terrain_set, int terrain_index )
# - void remove_terrain_set ( int terrain_set )
# - void set_alternative_level_tile_proxy ( int source_from, Vector2i coords_from, int alternative_from, int source_to, Vector2i coords_to, int alternative_to )
# - void set_coords_level_tile_proxy ( int p_source_from, Vector2i coords_from, int source_to, Vector2i coords_to )
# - void set_custom_data_layer_name ( int layer_index, String layer_name )
# - void set_custom_data_layer_type ( int layer_index, Variant.Type layer_type )
# - void set_navigation_layer_layer_value ( int layer_index, int layer_number, bool value )
# - void set_navigation_layer_layers ( int layer_index, int layers )
# - void set_occlusion_layer_light_mask ( int layer_index, int light_mask )
# - void set_occlusion_layer_sdf_collision ( int layer_index, bool sdf_collision )
# - void set_physics_layer_collision_layer ( int layer_index, int layer )
# - void set_physics_layer_collision_mask ( int layer_index, int mask )
# - void set_physics_layer_physics_material ( int layer_index, PhysicsMaterial physics_material )
# - void set_source_id ( int source_id, int new_source_id )
# - void set_source_level_tile_proxy ( int source_from, int source_to )
# - void set_terrain_color ( int terrain_set, int terrain_index, Color color )
# - void set_terrain_name ( int terrain_set, int terrain_index, String name )
# - void set_terrain_set_mode ( int terrain_set, TerrainMode mode )
