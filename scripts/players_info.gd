class_name PlayerInfo extends Control

enum ColorId {
	Red,
	Green,
	Blue,
	Yellow
}

var ammunitions: Array[int] = [0, 0, 0]

func _ready() -> void:
	$AnimatedSprite2DRed.play()
	$AnimatedSprite2DGreen.play()
	$AnimatedSprite2DBlue.play()
	refresh_text()


func refresh_text() -> void:
	$LabelRed.text = "x" + str(ammunitions[0])
	$LabelGreen.text = "x" + str(ammunitions[1])
	$LabelBlue.text = "x" + str(ammunitions[2])


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
