class_name StoryTrigger
extends Node2D
## 스토리 트리거 자리. 본편에서 대사·컷씬을 연결한다.
## 스피드런 데모(DEMO_MODE)에서는 비활성 → 아무 일도 일어나지 않는다. 스토리판에서는 켜진다.
## 구간마다 입구에 하나씩 미리 배치된다 (TutorialDirector).

var story_id: String = ""
## 플레이어가 이 거리 안에 들어오면 발동 (px, TutorialData.story_trigger_radius)
var radius: float = 0.0
var enabled: bool = false
var fired: bool = false


func _init(id: String = "", trigger_radius: float = 0.0) -> void:
	story_id = id
	radius = trigger_radius


func _ready() -> void:
	enabled = Game.is_story_mode() or not Game.is_demo_mode()


func _physics_process(_delta: float) -> void:
	if not enabled or fired:
		return
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Node2D
	if player and player.global_position.distance_to(global_position) <= radius:
		fired = true
		Events.story_triggered.emit(story_id)
