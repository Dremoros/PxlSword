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

#Astar pathfinding object
var path

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
	var room_positions = []
	for room in $Rooms.get_children():
		if randf() < cull:
			room.queue_free()
		else:
			room.freeze = true
			room_positions.append(Vector2(room.position.x, room.position.y))
	await get_tree().process_frame
	# generate a min span tree to connect the rooms
	path = find_mst(room_positions)

func _draw():
	for room in $Rooms.get_children():
		draw_rect(Rect2(room.position - room.size, room.size * 2), Color(0,0,0), false)
	
	if path:
		for p in path.get_point_ids():
			for c in path.get_point_connections(p):
				var pp = path.get_point_position(p)
				var cp = path.get_point_position(c)
				draw_line(Vector2(pp.x, pp.y), Vector2(cp.x, cp.y),
				Color(0,1,1), 15, true)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	queue_redraw()

func _input(event):
	if event.is_action_pressed('ui_select'):
		for n in $Rooms.get_children():
			n.queue_free()
		path = null
		make_rooms()
	
func find_mst(nodes):
	# Prim's algorithm
	var path = AStar2D.new()
	path.add_point(path.get_available_point_id(), nodes.pop_front())
	
	# repeat until no more nodes remain
	while nodes:
		var min_dist = INF # min dist so far
		var min_p = null # pos of that node
		var p = null # current pos
		# loop through all the points in the path
		
		for p0 in path.get_point_ids():
			var p1 = path.get_point_position(p0)
			for p2 in nodes:
				if p1.distance_to(p2) < min_dist:
					min_dist = p1.distance_to(p2)
					min_p = p2
					p = p1
		var n = path.get_available_point_id()
		path.add_point(n, min_p)
		path.connect_points(path.get_closest_point(p), n)
		nodes.erase(min_p)
	return path
			
	
