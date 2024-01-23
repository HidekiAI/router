class_name BlockUnitBase extends Node2D

var state: AutoloadGlobalsTileAnimation.AnimationState
var total_frames: int

func _init():
	state = AutoloadGlobalsTileAnimation.AnimationState.EMPTY
	total_frames = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# always use the very first (empty) frame
	var sprite = get_node("AnimatedSprite2D")
	if sprite != null:
		sprite.play(AutoloadGlobalsTileAnimation.kvp_animation_state[AutoloadGlobalsTileAnimation.AnimationState.EMPTY])
		state = AutoloadGlobalsTileAnimation.AnimationState.EMPTY

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var sprite = get_node("AnimatedSprite2D")
	if sprite == null:
		return

	if state != AutoloadGlobalsTileAnimation.AnimationState.ANIMATE:
		# if not playing, animate it
		cb_animate()

	# TODO: Signal on entry
	
	# TODO: Signal on exit


# signal received to animate
func cb_animate() -> void:
	#var sprite = $AnimatedSprite2D
	var sprite = get_node("AnimatedSprite2D")
	if sprite == null:
		return
	
	state = AutoloadGlobalsTileAnimation.AnimationState.ANIMATE
	var str_state = AutoloadGlobalsTileAnimation.kvp_animation_state[state] as String
	total_frames = sprite.sprite_frames.get_frame_count(str_state)
	print("Srpite('Junction') - cb_animate() - state="+ str(state) + ", str_state="+ str_state + ", total_frames="+ str(total_frames) )
	# trigger it
	sprite.play(str_state)

