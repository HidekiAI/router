extends TextureRect

@export var width: int
@export var height: int
@export var offset: int
@export var y_offset: int

@onready var x_start = ((get_window().size.x / 2.0) - ((width/2.0) * offset ) + (offset / 2))
@onready var y_start = ((get_window().size.y / 2.0) + ((height/2.0) * offset ) - (offset / 2))


# Called when the node enters the scene tree for the first time.
func _ready():
	# # set midpoint of texture as origin so that we do not have to alter the TextureRect each time it may have been reset
	# var mid_x = self.texture.get_width() / 2
	# var mid_y = self.texture.get_height() / 2
	# self.position.x = mid_x * -1.0
	# self.position.y = mid_y * -1.0
	self.position.x = x_start
	self.position.y = y_start

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
