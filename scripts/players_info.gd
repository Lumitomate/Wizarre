class_name PlayerInfo extends Control


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
	
	for munition_type in range(ammunitions.size()):
		var ammo_nb: GemmeNb = GemmeNb.FIVE_OR_MORE
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
			Enum.AttackFamily.Red:
				$HudGemneF.frame = ammo_nb
			Enum.AttackFamily.Yellow:
				$HudGemneL.frame = ammo_nb
			Enum.AttackFamily.Blue:
				$HudGemneG.frame = ammo_nb

func set_bg_color(color_id: Enum.SorcererColor):
		$SorcereColor.frame=color_id


func _on_ammo_changed(ammunition_type: int, ammunition_amount: int):
	ammunitions[ammunition_type] = ammunition_amount
	refresh_status()
	
func _on_life_changed(amount: int) -> void:
	lives = amount
	print("Dégats reçus! Vies restantes (" + str(lives) + ")")
	refresh_status()
