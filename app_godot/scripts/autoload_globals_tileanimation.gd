extends Node

# Node name: AutoloadGlobalsTileAnimation

# Assume all blocks have 3 anaimations:
# "animate" - when the block is triggered due to resource is at the starting edge/side of the block
# "empty" - when it is initially dropped onto place (see _ready)
# "filled" - when resource is full/filled on the block
# TODO: Want a set of animations for full resource versus partial resrouce to represent amount and (pressure, flow, motor, etc) strength of the block
enum AnimationState { 
    NONE,
    ANIMATE, 
    EMPTY, 
    FILLED,
}

var kvp_animation_state = {
    AnimationState.NONE: "none",
    AnimationState.ANIMATE: "animate",
    AnimationState.EMPTY: "empty",
    AnimationState.FILLED: "filled",
}
