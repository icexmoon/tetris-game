extends Node2D

# 用于显示 Next / Hold 方块的辅助节点

var shape: Array = []
var color_idx: int = 0
var cell_size: float = 14.0

var colors: Array = [
	Color(0,0,0),
	Color(0,1,1),
	Color(1,1,0),
	Color(1,0.5,0),
	Color(0,0,1),
	Color(1,0,1),
	Color(0,1,0),
	Color(1,0,0),
]

func display(s: Array, ci: int, cs: float) -> void:
	shape = s
	color_idx = ci
	cell_size = cs
	queue_redraw()

func clear_display() -> void:
	shape = []
	color_idx = 0
	queue_redraw()

func _draw() -> void:
	if shape.is_empty() or color_idx == 0:
		return

	var rows = shape.size()
	var cols = shape[0].size()
	var total_w = cols * cell_size
	var total_h = rows * cell_size

	# 居中绘制
	var draw_x = int(cols == 4) * cell_size * 0.5  # I 形特殊居中
	var draw_y = 0

	for row in range(rows):
		for col in range(cols):
			if shape[row][col] != 0:
				var r = Rect2(
					col * cell_size + draw_x + 1,
					row * cell_size + draw_y + 1,
					cell_size - 2,
					cell_size - 2
				)
				draw_rect(r, colors[color_idx])
