class_name PlayerInfo extends Control

enum ColorId {
	Blue,
	Red,
	Green,
	Yellow
}

var ammunitions: Array[int] = [0, 0, 0]

func _ready() -> void:
	refresh_text()


func refresh_text() -> void:
	$Label.text = "[Red: " + str(ammunitions[0]) + "] [Blue: " + str(ammunitions[1]) + "] [Green: " + str(ammunitions[2]) + "]"


func set_bg_color(color_id: ColorId):
	match color_id:
		ColorId.Blue:
			$ColorRect.color = Color(0.379, 0.573, 1.0, 1.0)
		ColorId.Red:
			$ColorRect.color = Color(1.0, 0.313, 0.345, 1.0)
		ColorId.Green:
			$ColorRect.color = Color(0.53, 1.0, 0.528, 1.0)
		ColorId.Yellow:
			$ColorRect.color = Color(1.0, 0.87, 0.277, 1.0)


func _on_ammo_changed(ammunition_type: int, ammunition_amount: int):
	ammunitions[ammunition_type] = ammunition_amount
	refresh_text()
