class_name DodgeData
extends Resource
## 회피 데이터 베이스. 회피 형태(대시/구르기/순간이동)는 미정이라
## 형태마다 DodgeData 하위 클래스 + DodgeAbility 하위 클래스를 짝으로 만든다.
## 교체는 data/dodge.tres 를 다른 형태의 리소스로 바꾸기만 하면 된다.
## TODO(미정): 회피 세부 형태 확정


## 이 데이터에 맞는 회피 동작 객체를 만든다
func create_ability() -> DodgeAbility:
	push_error("DodgeData.create_ability() 를 하위 클래스에서 구현해야 함")
	return null
