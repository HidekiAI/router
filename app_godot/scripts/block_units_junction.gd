extends Object

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	AutoloadPrimitives.foo()	# this makes NO SENSE - why do I need to new() a singleton?

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

