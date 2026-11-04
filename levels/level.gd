class_name Level
extends Node2D
## 맵 하나 (타일 + 소품 + 플레이어 + 탄 + 이펙트). 맵 파일 경로를 받아 코드로 구성한다.
## 자식 순서 = 매 틱 처리 순서: 타일 → 소품 → 플레이어 → 탄 → 이펙트
## (플레이어가 근접 판정을 켠 뒤 같은 틱에 탄이 패링 판정을 본다)
## TODO(M4): 튜토리얼 7구간, 적 배치, StoryTrigger

const GROUP_PROJECTILES := &"projectiles"

## 맵 글자 → 소품 스크립트
const PROPS := {
	"D": preload("res://levels/props/target_dummy.gd"),
	"T": preload("res://levels/props/test_turret.gd"),
}

var map_path: String = ""
var map: LevelMap
var player: Player
var projectiles: Node2D
var effects: Node2D
## 현재 디버그 구간 (0 = 시작 지점, 1~7 = 구간)
var current_section: int = 0


func _ready() -> void:
	map = LevelMap.load_from_file(map_path)
	add_child(LevelBuilder.build(map, DB.theme))

	var props := Node2D.new()
	props.name = "Props"
	add_child(props)
	for entry: Dictionary in map.props:
		var script: GDScript = PROPS.get(entry["char"])
		if script == null:
			continue
		var prop: Node2D = script.new()
		prop.position = LevelMap.cell_center(entry["cell"])
		props.add_child(prop)

	player = Player.new()
	player.position = LevelMap.cell_center(map.spawn_cell)
	add_child(player)
	var size := map.pixel_size()
	player.camera.limit_left = 0
	player.camera.limit_top = 0
	player.camera.limit_right = size.x
	player.camera.limit_bottom = size.y

	projectiles = Node2D.new()
	projectiles.name = "Projectiles"
	projectiles.add_to_group(GROUP_PROJECTILES)
	add_child(projectiles)

	effects = Node2D.new()
	effects.name = "Effects"
	effects.add_to_group(Effect.GROUP)
	add_child(effects)

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
