class_name Level
extends Node2D
## 맵 하나 (타일 + 플레이어). 맵 파일 경로를 받아 코드로 구성한다.
## TODO(M4): 튜토리얼 7구간, 적 배치, StoryTrigger

var map_path: String = ""
var map: LevelMap
var player: Player
## 현재 디버그 구간 (0 = 시작 지점, 1~7 = 구간)
var current_section: int = 0


func _ready() -> void:
	map = LevelMap.load_from_file(map_path)
	add_child(LevelBuilder.build(map, DB.theme))

	player = Player.new()
	player.position = LevelMap.cell_center(map.spawn_cell)
	add_child(player)
	var size := map.pixel_size()
	player.camera.limit_left = 0
	player.camera.limit_top = 0
	player.camera.limit_right = size.x
	player.camera.limit_bottom = size.y

	Events.debug_section_step.connect(_on_debug_section_step)


## 디버그: 이전/다음 구간 시작 지점으로 이동
func _on_debug_section_step(delta: int) -> void:
	var sections: Array = map.section_cells.keys()
	if sections.is_empty():
		return
	sections.sort()
	var last: int = sections[sections.size() - 1]
	current_section = clampi(current_section + delta, 0, last)
	var cell := map.spawn_cell
	if map.section_cells.has(current_section):
		cell = map.section_cells[current_section]
	player.teleport(LevelMap.cell_center(cell))
