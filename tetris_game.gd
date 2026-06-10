extends Control

# ================= 游戏配置 =================
const CELL_SIZE = 32
const GRID_WIDTH = 10
const GRID_HEIGHT = 20
const FALL_SPEED = 0.8

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

@onready var game_field = $GameField
@onready var score_label = $Label
@onready var fall_timer = $FallTimer

func _ready():
	print("游戏开始初始化...")
	
	# 初始化网格
	grid = []
	for y in range(GRID_HEIGHT):
		var row = []
		for x in range(GRID_WIDTH):
			row.append(0)
		grid.append(row)
	
	# 计时器设置
	fall_timer.wait_time = FALL_SPEED
	fall_timer.timeout.connect(_on_fall_timer)
	
	# 生成第一个方块
	new_shape()
	update_score()
	
	# 把游戏区域居中
	game_field.position = Vector2(
		(get_viewport_rect().size.x - GRID_WIDTH * CELL_SIZE) / 2,
		(get_viewport_rect().size.y - GRID_HEIGHT * CELL_SIZE) / 2
	)
	
	print("初始化完成！")
	update_grid()

func new_shape():
	print("生成新方块...")
	var idx = randi() % shapes.size()
	current_shape = shapes[idx]
	current_color = idx + 1
	current_x = GRID_WIDTH / 2 - current_shape[0].size() / 2
	current_y = 0

	if not is_valid_position(current_shape, current_x, current_y):
		print("游戏结束！")
		get_tree().quit()

func _on_fall_timer():
	move_down()

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
	# 清空旧格子
	for child in game_field.get_children():
		child.queue_free()
	
	# 绘制网格里的方块
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if grid[y][x] != 0:
				draw_cell(x, y, colors[grid[y][x]])
	
	# 绘制当前方块
	for row in range(current_shape.size()):
		for col in range(current_shape[row].size()):
			if current_shape[row][col] != 0:
				var x = current_x + col
				var y = current_y + row
				draw_cell(x, y, colors[current_color])

# ========== 已修复：ColorRect 属性 ==========
func draw_cell(x, y, color):
	var cell = ColorRect.new()
	cell.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)  # 修复这里
	cell.position = Vector2(x * CELL_SIZE, y * CELL_SIZE) # 修复这里
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

func _input(event):
	if event is InputEventScreenTouch and event.pressed:
		rotate_shape()
	if event is InputEventScreenDrag:
		if event.relative.x > 15:
			move_dir(1)
		elif event.relative.x < -15:
			move_dir(-1)
		if event.relative.y > 15:
			move_down()
