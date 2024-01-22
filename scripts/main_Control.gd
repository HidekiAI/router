extends Control

func _ready():
	$ButtonPlay.connect("pressed", _on_Play_pressed)
	$ButtonQuit.connect("pressed", _on_Exit_pressed)

func _on_Play_pressed():
	get_tree().change_scene_to_file("res://scenes/bg_default.tscn")

func _on_Exit_pressed():
	get_tree().quit()
