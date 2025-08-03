extends Node

enum SkinType {
	DEFAULT,
	CAT,
	BOWLINGBALL
}

var selected_skin:SkinType = SkinType.DEFAULT

func get_skin_string(skin_type:SkinType) -> String:
	match skin_type:
		SkinType.CAT:
			return "Cat"
		SkinType.BOWLINGBALL:
			return "Bowling Ball"
		_:
			return "Default"

func get_skin_type_from_string(skin_str:String) -> SkinType:
	match skin_str:
		"Cat":
			return SkinType.CAT
		"Bowling Ball":
			return SkinType.BOWLINGBALL
		_:
			return SkinType.DEFAULT
			
