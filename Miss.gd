extends Node2D

var grid : Rect2 = Rect2(Vector2(0, 0), Vector2(32, 32))
var pos
var pic
var pictex = ImageTexture.new()

var length
var height
var decay = 0.500

func _ready():
	pic = load("res://Images/Gameplay/miss.png")
	length = get_viewport().size[1]*0.2
	height = length*0.5
	pos = Rect2(Vector2(0, 0), Vector2(length, height))
	pictex.create_from_image(pic.get_data())

func _process(delta):
	if decay <= 0:
		queue_free()
	decay -= delta
	translate(Vector2(0, -length*delta))
	update()

func _draw():
	draw_texture_rect(pictex, pos, false, Color(1,1,1,2*decay))
