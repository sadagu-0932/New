class_name DialoguePlayer
extends Node
## 대사 시스템 자리. 본편에서 story_triggered 를 받아 대사·컷씬을 재생한다.
## 데모에서는 트리거가 비활성이라 호출되지 않는다.
## TODO(본편): 대사 데이터 형식, 대사창 UI, 컷씬 연출


func _ready() -> void:
	Events.story_triggered.connect(_on_story_triggered)


func _on_story_triggered(story_id: String) -> void:
	# 본편에서 구현. 지금은 기록만 남긴다.
	print_verbose("story_triggered: ", story_id)
