extends Node

# Node name: AutoloadGlobalsSettings

# load from persisted storage (will @export) so that it can be set via editor
@export var settings = {
	"test_var_1": 0,
	"test_var_2": 1,
}
