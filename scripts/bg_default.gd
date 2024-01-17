extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Assumes it has at least 2 children:
	# 1. $TileMap_Playfield
	# 2. $TileMap_NextTiles
	# in which, I need TileMap_NextTiles to be initialized AFTER the Playfield, so that it can set itself
	# up for randomized tiles
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

