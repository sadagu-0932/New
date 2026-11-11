class_name NpcData
extends Resource
## NPC 하나 (맵 글자 'N', 맵에서 읽는 순서대로 AreaData.npcs 와 짝지어진다).

@export var id: String = ""
@export var display_name: String = ""
## 그림 (story_props 시트의 애니메이션 이름)
@export var sprite: StringName = &"npc_a"
## 대사 (한 줄씩 넘긴다)
@export var lines: Array[String] = []
## 이 스토리 진행도가 생긴 뒤에는 alt_lines 를 말한다 ("" = 없음)
@export var alt_flag: String = ""
@export var alt_lines: Array[String] = []
