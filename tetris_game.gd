extends Control

# ================= 游戏固定配置（行列不变） =================
const GRID_WIDTH = 10
const GRID_HEIGHT = 20
const FALL_SPEED = 0.8
const DRAG_SENSITIVITY = 15
# 边框/线条颜色
const BORDER_COLOR = Color(1, 1, 1)
const LINE_COLOR = Color(0.3, 0.3, 0.3)
const LINE_WIDTH = 1

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
var CELL_SIZE = 1  # 运行时动态计算

# 鼠标/触屏临时变量
var mouse_down = false
var mouse_start_pos = Vector2.ZERO
var drag_handled = false

@onready var game_field = $GameField
@onready var score_label = $Label
@onready var fall_timer = $FallTimer

func _ready():
	# ========== 动态计算格子大小 & 自适应屏幕 ==========
	var view_size = get_viewport_rect().size
	# 边距，可自行微调大小
	var margin_top = 40
	var margin_bottom = 20
	var side_margin = 10
	
	var usable_height = view_size.y - margin_top - margin_bottom
	var usable_width = view_size.x - side_margin * 2

	# 按宽高比例计算单格尺寸，取最小值保证完整显示
	var cell_by_width = usable_width / GRID_WIDTH
	var cell_by_height = usable_height / GRID_HEIGHT
	CELL_SIZE = floor(min(cell_by_width, cell_by_height))

	# 初始化网格数据
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
	
	# 生成初始方块
	new_shape()
	update_score()
	
	# 修复：使用 position 替代 rect_position
	var total_w = GRID_WIDTH * CELL_SIZE
	var total_h = GRID_HEIGHT * CELL_SIZE
	game_field.position = Vector2(
		(view_size.x - total_w) / 2,
		margin_top
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
	# 清空旧元素
	for child in game_field.get_children():
		child.queue_free()
	
	# 绘制边框+网格线
	draw_border_and_lines()
	
	# 绘制落地方块
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if grid[y][x] != 0:
				draw_cell(x, y, colors[grid[y][x]])
	
	# 绘制当前活动方块
	for row in range(current_shape.size()):
		for col in range(current_shape[row].size()):
			if current_shape[row][col] != 0:
				var x = current_x + col
				var y = current_y + row
				draw_cell(x, y, colors[current_color])

# 绘制边框与网格线
func draw_border_and_lines():
	var total_w = GRID_WIDTH * CELL_SIZE
	var total_h = GRID_HEIGHT * CELL_SIZE
	# 外边框
	var border = ColorRect.new()
	border.size = Vector2(total_w, total_h)
	border.position = Vector2(0, 0)
	border.color = BORDER_COLOR
	border.z_index = -10
	game_field.add_child(border)

	# 垂直线
	for x in range(GRID_WIDTH + 1):
		var line = ColorRect.new()
		line.size = Vector2(LINE_WIDTH, total_h)
		line.position = Vector2(x * CELL_SIZE, 0)
		line.color = LINE_COLOR
		line.z_index = -5
		game_field.add_child(line)

	# 水平线
	for y in range(GRID_HEIGHT + 1):
		var line = ColorRect.new()
		line.size = Vector2(total_w, LINE_WIDTH)
		line.position = Vector2(0, y * CELL_SIZE)
		line.color = LINE_COLOR
		line.z_index = -5
		game_field.add_child(line)

func draw_cell(x, y, color):
	var cell = ColorRect.new()
	cell.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
	cell.position = Vector2(x * CELL_SIZE + 1, y * CELL_SIZE + 1)
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

# 输入处理（安卓触屏优先）
func _input(event: InputEvent) -> void:
	# 安卓触屏事件
	if event is InputEventScreenTouch:
		if event.pressed:
			rotate_shape()
			mouse_down = true
			mouse_start_pos = event.position
			drag_handled = false
		else:
			mouse_down = false
		return
	
	# 触屏滑动
	if event is InputEventScreenDrag:
		if drag_handled:
			return
		var delta_x = event.relative.x
		var delta_y = event.relative.y
		if abs(delta_x) > DRAG_SENSITIVITY:
			move_dir(1 if delta_x > 0 else -1)
			drag_handled = true
		elif delta_y > DRAG_SENSITIVITY:
			move_down()
			drag_handled = true
		return

	# 编辑器鼠标
	if event is InputEventMouseButton:
		mouse_down = event.pressed
		if mouse_down:
			mouse_start_pos = event.position
			drag_handled = false
		else:
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

	# 键盘控制
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT: move_dir(-1)
			KEY_RIGHT: move_dir(1)
			KEY_DOWN: move_down()
			KEY_SPACE: rotate_shape()
