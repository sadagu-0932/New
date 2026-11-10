class_name StartLine
extends Node2D
## 출발선 (맵 글자 L, 한 칸짜리 조각을 세로로 이어 그린다).
## 플레이어가 선을 오른쪽으로 넘으면 타이머 시작 = 출발. 그 전에는 마음대로 움직이고 스킬 설정도 된다.
## 맵에 출발선이 하나라도 있으면 PlayerInput 은 첫 입력으로 출발시키지 않는다.

const GROUP := &"start_line"


func _ready() -> void:
	add_to_group(GROUP)
	var sprite := Sprite2D.new()
	sprite.texture = DB.theme.load_texture("start_line")
	add_child(sprite)


func _physics_process(_delta: float) -> void:
	if Game.clock_running:
		return
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Node2D
	# 플레이어 중심이 선(칸 가운데)을 넘으면 출발
	if player != null and player.global_position.x >= global_position.x:
		Game.start_clock()
