extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _on_StartButton_button_down():
	# AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear2db($VolumeSlider.value))
	if get_tree().change_scene("res://Game.tscn") != OK:
		print ("Error changing scene to Game")

#func _on_VolumeSlider_value_changed(value):
#	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"),
#								linear2db(value))


func _on_StartButton_button_up():
	if get_tree().change_scene("res://Game.tscn") != OK:
		print ("Error changing scene to Game")
