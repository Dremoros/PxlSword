extends Node2D

var Room = preload("res://room.tscn")

@onready var Map = $TileMap

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
	if event.is_action_pressed('ui_focus_next'):
		make_map()
	
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
			
	
func make_map():
	Map.clear()
	var full_rect = Rect2()
	for room in $Rooms.get_children():
		var r = Rect2(room.position - room.size,
					room.get_node("CollisionShape2D").shape.extents*2)
		full_rect = full_rect.merge(r)
	var topleft = Map.local_to_map(full_rect.position)
	var bottomright = Map.local_to_map(full_rect.end)
	for x in range(topleft.x, bottomright.x):
		for y in range(topleft.y, bottomright.y):
			Map.set_cell(0, Vector2i(x, y), 0, Vector2i(1,0), 0)
	
	# Carve the rooms from the walls
	var corridors = [] # One corridor per connection
	for room in $Rooms.get_children():
		var s = (room.size / tile_size).floor()
		var pos = Map.local_to_map(room.position)
		var ul = (room.position / tile_size).floor() - s
		#This iteration range create the space between the rooms
		for x in range(2, s.x * 2 - 1):
			for y in range(2, s.y * 2 - 1):
				Map.set_cell(0, Vector2i(ul.x + x, ul.y + y), 0, Vector2i(0,0), 0)
		# Carve connecting corridor
		var p = path.get_closest_point(room.position)
		for conn in path.get_point_connections(p):
			if not conn in corridors:
				var start = Map.local_to_map(Vector2(path.get_point_position(p).x, 
													path.get_point_position(p).y))
				var end = Map.local_to_map(Vector2(path.get_point_position(conn).x, 
													path.get_point_position(conn).y))
				carve_path(start, end)
		corridors.append(p)

func carve_path(start, end):
	
	var difference_x = sign(end.x - start.x)
	var difference_y = sign(end.y - start.y)
	
	if difference_x == 0:
		difference_x = pow(-1.0, randi() % 2)
	if difference_y == 0:
		difference_y = pow(-1.0, randi() % 2)
		
	var x_over_y = start
	var y_over_x = end
	
	if randi() % 2 > 0:
		x_over_y = end
		y_over_x = start

	for x in range(start.x, end.x, difference_x):
		Map.set_cell(0, Vector2i(x, y_over_x.y), 0, Vector2i(0,0), 0)
	for y in range(start.y, end.y, difference_y):
		Map.set_cell(0, Vector2i(x_over_y.x, y), 0, Vector2i(0,0), 0)
