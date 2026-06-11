extends Control

# ==========================================
#  固定配置
# ==========================================
const GRID_WIDTH = 10
const GRID_HEIGHT = 20
const INITIAL_FALL_SPEED = 0.8
const DRAG_SENSITIVITY = 15
const LINES_PER_LEVEL = 10
const SCORE_TABLE = [0, 100, 300, 500, 800]  # 1/2/3/4 行消分
const LINE_WIDTH = 1
const GHOST_ALPHA = 0.25

const BORDER_COLOR = Color(1, 1, 1)
const LINE_COLOR = Color(0.3, 0.3, 0.3)
const BG_COLOR = Color(0.05, 0.05, 0.1)
const PREVIEW_BG = Color(0.12, 0.12, 0.18)

const COLORS = [
	Color(0,0,0),
	Color(0,1,1),
	Color(1,1,0),
	Color(1,0.5,0),
	Color(0,0,1),
	Color(1,0,1),
	Color(0,1,0),
	Color(1,0,0),
]

const SHAPES = [
	[[1,1,1,1]],
	[[1,1],[1,1]],
	[[1,0,0],[1,1,1]],
	[[0,0,1],[1,1,1]],
	[[0,1,0],[1,1,1]],
	[[0,1,1],[1,1,0]],
	[[1,1,0],[0,1,1]],
]

# ==========================================
#  游戏状态
# ==========================================
var grid: Array = []
var current_shape: Array = []
var current_color_idx: int = 0
var current_x: int = 0
var current_y: int = 0
var ghost_y: int = 0

var next_shape: Array = []
var next_color_idx: int = 0

var held_shape: Array = []
var held_color_idx: int = 0
var can_hold: bool = true

var bag: Array = []
var score: int = 0
var level: int = 1
var total_lines: int = 0
var game_over: bool = false
var started: bool = false

var cell_size: float = 1.0
var board_offset: Vector2 = Vector2.ZERO
var preview_cell_size: float = 14.0

# 消行闪烁
var lines_to_clear: Array = []
var is_flashing: bool = false
var flash_count: int = 0
var clear_animating: bool = false

# 输入状态
var mouse_down: bool = false
var mouse_start_pos: Vector2 = Vector2.ZERO
var drag_handled: bool = false
var touch_start: Vector2 = Vector2.ZERO
var touch_swipe: bool = false

# ==========================================
#  @onready 引用
# ==========================================
@onready var bg_rect: ColorRect = $Background
@onready var score_label: Label = $ScoreLabel
@onready var lines_label: Label = $LinesLabel
@onready var level_label: Label = $LevelLabel
@onready var next_preview: Node2D = $NextPreview
@onready var hold_preview: Node2D = $HoldPreview
@onready var fall_timer: Timer = $FallTimer
@onready var flash_timer: Timer = $FlashTimer

var game_over_panel: Control = null
var final_score_label: Label = null
var final_lines_label: Label = null
var restart_btn: Button = null

# ==========================================
#  初始化
# ==========================================
func _ready() -> void:
	_apply_theme()
	_setup_game()

func _apply_theme() -> void:
	size = get_viewport_rect().size

func _setup_game() -> void:
	create_game_over_ui()
	_init_game()

func start_game() -> void:
	started = true
	game_over = false
	score = 0
	level = 1
	total_lines = 0
	can_hold = true
	held_shape = []
	held_color_idx = 0

	init_grid()
	bag = []

	var idx = get_from_bag()
	current_shape = SHAPES[idx]
	current_color_idx = idx + 1
	idx = get_from_bag()
	next_shape = SHAPES[idx]
	next_color_idx = idx + 1

	current_x = GRID_WIDTH / 2 - current_shape[0].size() / 2
	current_y = 0

	fall_timer.wait_time = INITIAL_FALL_SPEED
	fall_timer.start()
	flash_timer.one_shot = false
	if not flash_timer.timeout.is_connected(_on_flash_tick):
		flash_timer.timeout.connect(_on_flash_tick)

	update_ghost()
	refresh_ui()

func _init_game() -> void:
	calculate_layout()
	if not fall_timer.timeout.is_connected(_on_fall_timer):
		fall_timer.timeout.connect(_on_fall_timer)
	start_game()

func init_grid() -> void:
	grid = []
	for y in range(GRID_HEIGHT):
		var row: Array = []
		for x in range(GRID_WIDTH):
			row.append(0)
		grid.append(row)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		calculate_layout()
		queue_redraw()

# ==========================================
#  布局计算
# ==========================================
func calculate_layout() -> void:
	if not is_inside_tree() or score_label == null:
		return
	var view: Vector2 = get_viewport_rect().size
	var header_h: float = 90.0
	var margin_top: float = 8.0
	var margin_bottom: float = 12.0
	var side_margin: float = 10.0

	var usable_h: float = view.y - header_h - margin_top - margin_bottom
	var usable_w: float = view.x - side_margin * 2.0

	cell_size = floor(min(usable_w / GRID_WIDTH, usable_h / GRID_HEIGHT))
	if cell_size < 12:
		cell_size = 12

	var board_w: float = GRID_WIDTH * cell_size
	var board_h: float = GRID_HEIGHT * cell_size
	board_offset = Vector2(
		(view.x - board_w) / 2.0,
		margin_top + header_h
	)

	preview_cell_size = max(8.0, floor(cell_size * 0.55))

	var preview_area_y: float = margin_top + 22.0
	var preview_size: float = 4.0 * preview_cell_size + 4.0

	# Hold (左侧)
	var hold_x: float = board_offset.x - preview_size - 6.0
	if hold_x < 2.0:
		hold_x = 2.0
	hold_preview.position = Vector2(hold_x + 2.0, preview_area_y)

	# Next (右侧)
	var next_x: float = board_offset.x + board_w + 6.0
	var max_rx: float = view.x - preview_size - 2.0
	if next_x + preview_size > max_rx:
		next_x = max_rx
	next_preview.position = Vector2(next_x + 2.0, preview_area_y)

	# UI 标签订位
	score_label.position = Vector2(8, margin_top - 2)
	level_label.position = Vector2(view.x / 2.0 - 24.0, margin_top - 2)
	lines_label.position = Vector2(view.x - 90.0, margin_top - 2)
	score_label.add_theme_font_size_override("font_size", 14)
	level_label.add_theme_font_size_override("font_size", 14)
	lines_label.add_theme_font_size_override("font_size", 14)

	if game_over_panel:
		var pw: float = 260.0
		var ph: float = 220.0
		game_over_panel.position = Vector2(
			(view.x - pw) / 2.0,
			(view.y - ph) / 2.0
		)
		game_over_panel.size = Vector2(pw, ph)

	queue_redraw()

# ==========================================
#  7-bag 随机
# ==========================================
func get_from_bag() -> int:
	if bag.is_empty():
		for i in range(SHAPES.size()):
			bag.append(i)
		bag.shuffle()
	return bag.pop_front()

# ==========================================
#  幽灵方块 Y
# ==========================================
func update_ghost() -> void:
	ghost_y = current_y
	while is_valid_position(current_shape, current_x, ghost_y + 1):
		ghost_y += 1

# ==========================================
#  位置校验
# ==========================================
func is_valid_position(shape: Array, x: int, y: int) -> bool:
	for row in range(shape.size()):
		for col in range(shape[row].size()):
			if shape[row][col] != 0:
				var nx: int = x + col
				var ny: int = y + row
				if nx < 0 or nx >= GRID_WIDTH or ny >= GRID_HEIGHT:
					return false
				if ny >= 0 and grid[ny][nx] != 0:
					return false
	return true

# ==========================================
#  方块操作
# ==========================================
func rotate_shape() -> void:
	if game_over or clear_animating:
		return
	var rotated: Array = []
	for col in range(current_shape[0].size()):
		var new_row: Array = []
		for row in range(current_shape.size() - 1, -1, -1):
			new_row.append(current_shape[row][col])
		rotated.append(new_row)
	if is_valid_position(rotated, current_x, current_y):
		current_shape = rotated
		# Wall kick: 尝试左右微移
		if not is_valid_position(current_shape, current_x, current_y):
			for kick in [1, -1, 2, -2]:
				if is_valid_position(current_shape, current_x + kick, current_y):
					current_x += kick
					break
		update_ghost()
		queue_redraw()

func move_dir(dir: int) -> void:
	if game_over or clear_animating:
		return
	if is_valid_position(current_shape, current_x + dir, current_y):
		current_x += dir
		update_ghost()
		queue_redraw()

func move_down() -> void:
	if game_over or clear_animating:
		return
	if is_valid_position(current_shape, current_x, current_y + 1):
		current_y += 1
		update_ghost()
		queue_redraw()
	else:
		lock_and_clear()

func hard_drop() -> void:
	if game_over or clear_animating:
		return
	while is_valid_position(current_shape, current_x, current_y + 1):
		current_y += 1
	update_ghost()
	lock_and_clear()

func hold_piece() -> void:
	if game_over or clear_animating or not can_hold:
		return
	can_hold = false
	if held_shape.is_empty():
		held_shape = current_shape
		held_color_idx = current_color_idx
		_spawn_next()
	else:
		var tmp_s = current_shape
		var tmp_c = current_color_idx
		current_shape = held_shape
		current_color_idx = held_color_idx
		held_shape = tmp_s
		held_color_idx = tmp_c
		current_x = GRID_WIDTH / 2 - current_shape[0].size() / 2
		current_y = 0
		if not is_valid_position(current_shape, current_x, current_y):
			trigger_game_over()
			return
		update_ghost()
		queue_redraw()
	hold_preview.display(held_shape, held_color_idx, preview_cell_size)
	refresh_ui()

func _spawn_next() -> void:
	current_shape = next_shape
	current_color_idx = next_color_idx
	current_x = GRID_WIDTH / 2 - current_shape[0].size() / 2
	current_y = 0
	can_hold = true

	var idx = get_from_bag()
	next_shape = SHAPES[idx]
	next_color_idx = idx + 1

	if not is_valid_position(current_shape, current_x, current_y):
		trigger_game_over()
		return
	update_ghost()
	next_preview.display(next_shape, next_color_idx, preview_cell_size)
	if held_shape.is_empty():
		hold_preview.clear_display()
	else:
		hold_preview.display(held_shape, held_color_idx, preview_cell_size)
	refresh_ui()
	queue_redraw()

# ==========================================
#  锁定 + 消行
# ==========================================
func lock_shape() -> void:
	for row in range(current_shape.size()):
		for col in range(current_shape[row].size()):
			if current_shape[row][col] != 0:
				var x: int = current_x + col
				var y: int = current_y + row
				if y >= 0:
					grid[y][x] = current_color_idx

func find_full_lines() -> Array:
	var lines: Array = []
	for y in range(GRID_HEIGHT):
		var full: bool = true
		for x in range(GRID_WIDTH):
			if grid[y][x] == 0:
				full = false
				break
		if full:
			lines.append(y)
	return lines

func lock_and_clear() -> void:
	lock_shape()
	var full_lines = find_full_lines()
	if full_lines.size() > 0:
		start_flash_animation(full_lines)
	else:
		_spawn_next()
		fall_timer.start()

func start_flash_animation(lines: Array) -> void:
	lines_to_clear = lines
	is_flashing = true
	flash_count = 0
	clear_animating = true
	flash_timer.wait_time = 0.08
	flash_timer.start()

func _on_flash_tick() -> void:
	flash_count += 1
	queue_redraw()
	if flash_count >= 6:
		flash_timer.stop()
		finish_line_clear()

func finish_line_clear() -> void:
	var count = lines_to_clear.size()
	# 从下往上消除
	lines_to_clear.sort()
	lines_to_clear.reverse()
	for y in lines_to_clear:
		for yy in range(y, 0, -1):
			grid[yy] = grid[yy - 1].duplicate()
		grid[0] = []
		for _i in range(GRID_WIDTH):
			grid[0].append(0)

	score += SCORE_TABLE[count] * level
	total_lines += count
	var new_level = total_lines / LINES_PER_LEVEL + 1
	if new_level > level:
		level = new_level
		fall_timer.wait_time = max(0.05, INITIAL_FALL_SPEED - (level - 1) * 0.055)

	is_flashing = false
	clear_animating = false
	lines_to_clear = []

	_spawn_next()
	fall_timer.start()

# ==========================================
#  计时器回调
# ==========================================
func _on_fall_timer() -> void:
	if not game_over and not clear_animating:
		move_down()
		if not game_over:
			fall_timer.start()

# ==========================================
#  绘制
# ==========================================
func _draw() -> void:
	if not started:
		return
	_draw_board()

func _draw_board() -> void:
	var board_x = board_offset.x
	var board_y = board_offset.y
	var bw = GRID_WIDTH * cell_size
	var bh = GRID_HEIGHT * cell_size

	# 外边框
	draw_rect(Rect2(board_x - 1, board_y - 1, bw + 2, bh + 2), BORDER_COLOR, false, 1.5)

	# 网格线（淡）
	var grid_col = LINE_COLOR
	for x in range(GRID_WIDTH + 1):
		var px = board_x + x * cell_size
		draw_line(Vector2(px, board_y), Vector2(px, board_y + bh), grid_col, 0.5)
	for y in range(GRID_HEIGHT + 1):
		var py = board_y + y * cell_size
		draw_line(Vector2(board_x, py), Vector2(board_x + bw, py), grid_col, 0.5)

	# 已锁定方块
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if grid[y][x] != 0:
				# 检查是否在闪烁
				if is_flashing and y in lines_to_clear:
					if flash_count % 2 == 1:
						var fc = Color(1, 1, 1, 0.9)
						draw_cell_at(x, y, fc)
				else:
					draw_cell_at(x, y, COLORS[grid[y][x]])

	if game_over:
		return

	# 幽灵方块
	draw_ghost_piece()

	# 当前方块
	for row in range(current_shape.size()):
		for col in range(current_shape[row].size()):
			if current_shape[row][col] != 0:
				var gx = current_x + col
				var gy = current_y + row
				draw_cell_at(gx, gy, COLORS[current_color_idx])

func draw_cell_at(gx: int, gy: int, color: Color) -> void:
	var pos = board_offset + Vector2(gx * cell_size + 1, gy * cell_size + 1)
	draw_rect(Rect2(pos, Vector2(cell_size - 2, cell_size - 2)), color)

func draw_ghost_piece() -> void:
	var ghost_col = COLORS[current_color_idx]
	ghost_col.a = GHOST_ALPHA
	for row in range(current_shape.size()):
		for col in range(current_shape[row].size()):
			if current_shape[row][col] != 0:
				var gx = current_x + col
				var gy = ghost_y + row
				if gy >= 0 and gy < GRID_HEIGHT and grid[gy][gx] == 0:
					var pos = board_offset + Vector2(gx * cell_size + 1, gy * cell_size + 1)
					draw_rect(Rect2(pos, Vector2(cell_size - 2, cell_size - 2)), ghost_col, true)
					draw_rect(Rect2(pos, Vector2(cell_size - 2, cell_size - 2)), COLORS[current_color_idx], false, 1.0)

# ==========================================
#  UI 刷新
# ==========================================
func refresh_ui() -> void:
	score_label.text = str(score)
	level_label.text = "Lv " + str(level)
	lines_label.text = str(total_lines) + " 行"
	queue_redraw()

# ==========================================
#  Game Over
# ==========================================
func trigger_game_over() -> void:
	game_over = true
	started = false
	fall_timer.stop()
	flash_timer.stop()
	is_flashing = false
	clear_animating = false

	if final_score_label:
		final_score_label.text = "最终得分: " + str(score)
	if final_lines_label:
		final_lines_label.text = "消行: " + str(total_lines) + "  |  等级: " + str(level)
	if game_over_panel:
		game_over_panel.visible = true
	queue_redraw()

func create_game_over_ui() -> void:
	game_over_panel = Panel.new()
	game_over_panel.visible = false

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.12, 0.92)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.3, 0.5, 1)
	game_over_panel.add_theme_stylebox_override(&"panel", style)

	var vb = VBoxContainer.new()
	vb.anchors_preset = Control.PRESET_FULL_RECT
	vb.add_theme_constant_override("separation", 12)
	vb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var title = Label.new()
	title.text = "游戏结束"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.add_theme_constant_override("outline_size", 1)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))

	final_score_label = Label.new()
	final_score_label.text = "最终得分: 0"
	final_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	final_score_label.add_theme_font_size_override("font_size", 22)
	final_score_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))

	final_lines_label = Label.new()
	final_lines_label.text = "消行: 0  |  等级: 1"
	final_lines_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	final_lines_label.add_theme_font_size_override("font_size", 16)
	final_lines_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))

	restart_btn = Button.new()
	restart_btn.text = "重新开始"
	restart_btn.custom_minimum_size = Vector2(160, 48)

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.4, 0.8, 1)
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_width_top = 1
	btn_style.border_width_bottom = 1
	btn_style.border_color = Color(0.4, 0.6, 1, 1)
	restart_btn.add_theme_stylebox_override(&"normal", btn_style)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.3, 0.5, 0.9, 1)
	hover_style.corner_radius_top_left = 8
	hover_style.corner_radius_top_right = 8
	hover_style.corner_radius_bottom_left = 8
	hover_style.corner_radius_bottom_right = 8
	restart_btn.add_theme_stylebox_override(&"hover", hover_style)

	restart_btn.add_theme_font_size_override("font_size", 18)
	restart_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	restart_btn.pressed.connect(_on_restart)

	vb.add_spacer(true)
	vb.add_child(title)
	vb.add_child(final_score_label)
	vb.add_child(final_lines_label)
	vb.add_spacer(true)
	vb.add_child(restart_btn)
	vb.add_spacer(true)

	game_over_panel.add_child(vb)
	add_child(game_over_panel)

func _on_restart() -> void:
	if game_over_panel:
		game_over_panel.visible = false
	start_game()

# ==========================================
#  输入处理
# ==========================================
func _input(event: InputEvent) -> void:
	if game_over:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
			_on_restart()
		return

	# 触屏
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start = event.position
			touch_swipe = false
		else:
			if not touch_swipe:
				rotate_shape()
		return

	if event is InputEventScreenDrag:
		if touch_swipe:
			return
		var dx = event.relative.x
		var dy = event.relative.y
		if abs(dx) > DRAG_SENSITIVITY:
			move_dir(1 if dx > 0 else -1)
			touch_swipe = true
		elif dy > DRAG_SENSITIVITY:
			move_down()
			touch_swipe = true
		elif dy < -DRAG_SENSITIVITY * 2:
			hold_piece()
			touch_swipe = true
		return

	# 鼠标
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
		elif delta.y < -DRAG_SENSITIVITY * 2:
			hold_piece()
			drag_handled = true
		return

	# 键盘
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				move_dir(-1)
			KEY_RIGHT, KEY_D:
				move_dir(1)
			KEY_DOWN, KEY_S:
				move_down()
			KEY_UP, KEY_W:
				hard_drop()
			KEY_SPACE:
				rotate_shape()
			KEY_C, KEY_SHIFT:
				hold_piece()
			KEY_R:
				_on_restart()
