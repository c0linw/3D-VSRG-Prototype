extends Spatial

# info vars
var time
var lane
var chart_time
var type
var velocity

# input state vars
var hold_index = -1 # set it to its corresponding touch input index when judged. If index is -1, it is unregistered.
var held = false

# timing windows
const early_perfect_plus = 0.025
const late_perfect_plus = 0.025
const early_perfect = 0.050
const late_perfect = 0.050
const early_great = 0.100
const late_great = 0.100

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func can_judge(event_time):
	return event_time >= time-early_great && event_time <= time + late_great

func judge(event_time):
	if event_time >= time-early_perfect_plus && event_time <= time + late_perfect_plus:
		return [0, event_time - time]
	if event_time >= time-early_perfect && event_time <= time + late_perfect:
		return [1, event_time - time]
	elif event_time >= time-early_great && event_time <= time + late_great:
		return [2, event_time - time]
