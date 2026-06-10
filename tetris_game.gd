extends Control

# ================= 游戏配置 =================
const CELL_SIZE = 32
const GRID_WIDTH = 10
const GRID_HEIGHT = 20
const FALL_SPEED = 0.8
const DRAG_SENSITIVITY = 15

# 颜色
var colors = [
	Color(0,0,0),
	Color(0,1,1),
	Color(1,1,0),
	Color(1,0.5,0),
	Color(0,0,1),
	Color(1,0,1),
	Color(0,1,0),
	Color(1,0,0)
]

# 方块形状
var shapes = [
	[[1,1,1,1]],
	[[1,1],[1,1]],
	[[1,0,0],[1,1,1]],
	[[0,0,1],[1,1,1]],
	[[0,1,0],[1,1,1]],
	[[0,1,1],[1,1,0]],
	[[1,1,0],[0,1,1]]
]

# 游戏变量
var grid = []
var current_shape = []
var current_color = 0
var current_x = 0
var current_y = 0
var score = 0

# 鼠标拖拽临时变量
var mouse_down = false
var mouse_start_pos = Vector2.ZERO
var drag_handled = false

@onready var game_field = $GameField
@onready var score_label = $Label
@onready var fall_timer = $FallTimer

func _ready():
	# 初始化网格
	grid = []
	for y in range(GRID_HEIGHT):
		var row = []
		for x in range(GRID_WIDTH):
			row.append(0)
		grid.append(row)
	
	# 计时器
	fall_timer.timeout.connect(_on_fall_timer)
	fall_timer.wait_time = FALL_SPEED
	fall_timer.start()
	
	# 生成方块
	new_shape()
	update_score()
	
	# 游戏区域居中
	game_field.position = Vector2(
		(get_viewport_rect().size.x - GRID_WIDTH * CELL_SIZE) / 2,
		(get_viewport_rect().size.y - GRID_HEIGHT * CELL_SIZE) / 2
	)
	
	update_grid()

func new_shape():
	var idx = randi() % shapes.size()
	current_shape = shapes[idx]
	current_color = idx + 1
	current_x = GRID_WIDTH / 2 - current_shape[0].size() / 2
	current_y = 0

	if not is_valid_position(current_shape, current_x, current_y):
		get_tree().quit()

func _on_fall_timer():
	move_down()
	fall_timer.start()

func move_down():
	if is_valid_position(current_shape, current_x, current_y + 1):
		current_y += 1
	else:
		lock_shape()
		clear_lines()
		new_shape()
	update_grid()

func is_valid_position(shape, x, y):
	for row in range(shape.size()):
		for col in range(shape[row].size()):
			if shape[row][col] != 0:
				var new_x = x + col
				var new_y = y + row
				if new_x < 0 or new_x >= GRID_WIDTH or new_y >= GRID_HEIGHT:
					return false
				if new_y >= 0 and grid[new_y][new_x] != 0:
					return false
	return true

func lock_shape():
	for row in range(current_shape.size()):
		for col in range(current_shape[row].size()):
			if current_shape[row][col] != 0:
				var x = current_x + col
				var y = current_y + row
				if y >= 0:
					grid[y][x] = current_color

func clear_lines():
	var lines_cleared = 0
	for y in range(GRID_HEIGHT):
		var full = true
		for x in range(GRID_WIDTH):
			if grid[y][x] == 0:
				full = false
				break
		if full:
			lines_cleared += 1
			for yy in range(y, 0, -1):
				grid[yy] = grid[yy-1].duplicate()
			var top_row = []
			for x in range(GRID_WIDTH):
				top_row.append(0)
			grid[0] = top_row
	if lines_cleared > 0:
		score += lines_cleared * 100
		update_score()

func update_grid():
	for child in game_field.get_children():
		child.queue_free()
	
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if grid[y][x] != 0:
				draw_cell(x, y, colors[grid[y][x]])
	
	for row in range(current_shape.size()):
		for col in range(current_shape[row].size()):
			if current_shape[row][col] != 0:
				var x = current_x + col
				var y = current_y + row
				draw_cell(x, y, colors[current_color])

func draw_cell(x, y, color):
	var cell = ColorRect.new()
	cell.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
	cell.position = Vector2(x * CELL_SIZE, y * CELL_SIZE)
	cell.color = color
	game_field.add_child(cell)

func rotate_shape():
	var rotated = []
	for col in range(current_shape[0].size()):
		var new_row = []
		for row in range(current_shape.size() - 1, -1, -1):
			new_row.append(current_shape[row][col])
		rotated.append(new_row)
	if is_valid_position(rotated, current_x, current_y):
		current_shape = rotated
		update_grid()

func move_dir(dir):
	if is_valid_position(current_shape, current_x + dir, current_y):
		current_x += dir
		update_grid()

func update_score():
	score_label.text = "分数: " + str(score)

# 统一输入处理：键盘 + 鼠标 + 触屏
func _input(event: InputEvent) -> void:
	# ========== 触屏（安卓真机） ==========
	if event is InputEventScreenTouch:
		if not event.pressed:
			rotate_shape()
		mouse_down = event.pressed
		mouse_start_pos = event.position
		drag_handled = false
		return
	
	if event is InputEventScreenDrag:
		if drag_handled:
			return
		if event.relative.x > DRAG_SENSITIVITY:
			move_dir(1)
			drag_handled = true
		elif event.relative.x < -DRAG_SENSITIVITY:
			move_dir(-1)
			drag_handled = true
		if event.relative.y > DRAG_SENSITIVITY:
			move_down()
			drag_handled = true
		return

	# ========== 鼠标（编辑器内） ==========
	if event is InputEventMouseButton:
		mouse_down = event.pressed
		if mouse_down:
			mouse_start_pos = event.position
			drag_handled = false
		else:
			# 单击鼠标 = 旋转
			if not drag_handled:
				rotate_shape()
		return
	
	if event is InputEventMouseMotion and mouse_down and not drag_handled:
		var delta = event.position - mouse_start_pos
		if abs(delta.x) > DRAG_SENSITIVITY:
			move_dir(1 if delta.x > 0 else -1)
			drag_handled = true
		elif delta.y > DRAG_SENSITIVITY:
			move_down()
			drag_handled = true
		return

	# ========== 键盘（电脑通用） ==========
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT: move_dir(-1)
			KEY_RIGHT: move_dir(1)
			KEY_DOWN: move_down()
			KEY_SPACE: rotate_shape()
