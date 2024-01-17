extends Node

var settings = {
	"test_var_1": 0,
	"test_var_2": 1,
}

# When the atlas position changes in TileSet "playfield_cell_tileset.tres"
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

## Called when the node enters the scene tree for the first time.
#func _ready() -> void:
#	pass # Replace with function body.


## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
#	pass
