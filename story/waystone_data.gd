class_name WaystoneData
extends Resource
## 웨이스톤 하나 (맵 글자 'Y', 맵에서 읽는 순서대로 AreaData.waystones 와 짝지어진다).
## 닿으면 활성화: 주인공 몸 안의 마석에 지도가 새겨진다 → 주변이 지도에서 밝혀지고, 회복 + 자동저장.
## 활성화한 웨이스톤끼리는 지도 화면에서 골라 순간이동할 수 있다.

@export var id: String = ""
@export var display_name: String = ""
## 활성화하면 지도에서 밝혀지는 지역 묶음 id 들 (비우면 이 웨이스톤이 서 있는 지역의 묶음)
@export var reveals: Array[String] = []
