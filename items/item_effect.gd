class_name ItemEffect
extends Resource
## 소모품을 썼을 때의 효과 한 줄.
## kind: "heal" 체력 회복(칸) · "ammo" 탄약 회복(발)
## (새 kind 를 만들 때만 Inventory.apply_effect 에 코드가 필요하다. 아이템 추가는 data 만으로)

@export var kind: String = ""
@export var amount: int = 0
