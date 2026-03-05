class_name PlayerInfo extends Control

enum ColorId {
	Red,
	Green,
	Blue,
	Yellow
}

enum GemmeColor {
	Red,
	Blue,
	Yellow
}

enum LifeNb {
	ZERO,
	ONE,
	TWO,
	THREE
}

enum GemmeNb {
	FIVE_OR_MORE,
	FOUR,
	THREE,
	TWO,
	ONE,
	ZERO
}

var ammunitions: Array[int] = [0, 0, 0]
var lives: = 0

func _ready() -> void:
	refresh_status()


func refresh_status() -> void:
	var lives_nb: LifeNb = LifeNb.ZERO
	match lives:
		0:
			lives_nb = LifeNb.ZERO
		1:
			lives_nb = LifeNb.ONE
		2:
			lives_nb = LifeNb.TWO
		3:
			lives_nb = LifeNb.THREE
	$HudVie.frame = lives_nb
	
	var ammo_nb: GemmeNb = GemmeNb.FIVE_OR_MORE
	for munition_type in range(ammunitions.size()):
		match ammunitions[munition_type]:
			0:
				ammo_nb = GemmeNb.ZERO
			1:
				ammo_nb = GemmeNb.ONE
			2:
				ammo_nb = GemmeNb.TWO
			3:
				ammo_nb = GemmeNb.THREE
			4:
				ammo_nb = GemmeNb.FOUR
		
		match munition_type:
			GemmeColor.Red:
				$HudGemneF.frame = ammo_nb
			GemmeColor.Yellow:
				$HudGemneL.frame = ammo_nb
			GemmeColor.Blue:
				$HudGemneG.frame = ammo_nb

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
	refresh_status()
	
func _on_life_changed(amount: int) -> void:
	lives = amount
	print("Dégats reçus! Vies restantes (" + str(lives) + ")")
	refresh_status()
