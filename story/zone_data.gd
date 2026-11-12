class_name ZoneData
extends Resource
## 지역: 한 장으로 이어진 세상(AreaData) 안의 이름 붙은 작은 땅 (연구소, 마석 광산촌, 골렘 터, 거울 호수 …).
## 작은 지역 여럿이 모여 묶음(group)이 된다 (가운데 숲, 광산 골짜기, 쓰러진 숲 …).
## 네모가 아니라 구불구불한 모양이다 — 어느 칸이 어느 지역인지는 지역 맵(AreaData.regions_file)의 글자(key)로 정한다.
## 화면이 바뀌지 않고 걸어서 드나든다. 웨이스톤 탑을 켜면 그 지역이 지도에서 밝혀진다.
## 이름이 빈 지역은 아직 내용이 없는 미지의 땅.

@export var id: String = ""
@export var display_name: String = ""
## 지역 맵에서 이 지역을 나타내는 글자
@export var key: String = ""
## 이 지역이 든 묶음 (id · 이름). 웨이스톤 탑 하나가 묶음 하나를 통째로 지도에 연다
@export var group: String = ""
@export var group_name: String = ""
## 처음부터 지도에 밝혀져 있는지 (출발하는 연구소와 그 둘레 숲)
@export var revealed_at_start: bool = false
## 처음 들어왔을 때 흘러가는 글 (data/story.tres 의 lines 키, "" = 없음)
@export var enter_story_id: String = ""
## 맵 글자 → 적 데이터 이름 (data/enemies/ 의 파일 이름). 없는 글자는 기본 적
@export var enemy_overrides: Dictionary = {}
