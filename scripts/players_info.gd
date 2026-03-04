extends Control

var ammunitions: Array[int] = [0, 0, 0]

func _ready() -> void:
	refresh_text()

func refresh_text() -> void:
	$Label.text = "[Red: " + str(ammunitions[0]) + "] [Blue: " + str(ammunitions[1]) + "] [Green: " + str(ammunitions[2]) + "]"
	
func _on_ammo_changed(ammunition_type: int, ammunition_amount: int):
	ammunitions[ammunition_type] = ammunition_amount
	refresh_text()
