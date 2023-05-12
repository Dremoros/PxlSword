extends Node2D

var Room = preload("res://room.tscn")

#tile size of the room's tile in pxl
var tile_size = 32

#number of rooms we want to generate
var num_rooms = 50

#min an max number of tiles a room can have
var min_size = 4
var max_size = 10

# horizontal spread of the rooms
var hspread = 400

# % of rooms removed
var cull = 0.5

# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()
	make_rooms()

func make_rooms():
	for i in range(num_rooms):
		var pos = Vector2(randi_range(-hspread, hspread), 0)
		var r = Room.instantiate()
		var w = min_size + randi() % (max_size - min_size)
		var h = min_size + randi() % (max_size - min_size)
		r.make_room(pos, Vector2(w, h) * tile_size)
		$Rooms.add_child(r)
	# Wait for the rooms to settle
	await get_tree().create_timer(1).timeout
	# culling the rooms
	for room in $Rooms.get_children():
		if randf() < cull:
			room.queue_free()
		else:
			room.freeze = true

func _draw():
	for room in $Rooms.get_children():
		draw_rect(Rect2(room.position - room.size, room.size * 2), Color(0,0,0), false)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	queue_redraw()

func _input(event):
	if event.is_action_pressed('ui_select'):
		for n in $Rooms.get_children():
			n.queue_free()
		make_rooms()
	
	
	
