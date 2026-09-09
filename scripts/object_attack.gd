class_name AttackObject extends Area2D

@export var item_attack_family: GlobalEnum.AttackFamily
@export var item_attack_type: GlobalEnum.AttackType
@export var item_attack_tier: GlobalEnum.AttackTier

var animation_name: String

func _ready() -> void:
	match item_attack_tier:
		GlobalEnum.AttackTier.III:
			animation_name = "Or"
		GlobalEnum.AttackTier.II:
			animation_name = "Argent"
		GlobalEnum.AttackTier.I:
			animation_name = "Bronze"
			
	$ObjetAttaqueAnimation.play(animation_name)
	
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_group"):
		var sorcerer: Sorcerer = body
		var tube_index: int = sorcerer.selected_tube
		
		# En boutique : le remplacement n'a lieu que si un tube est activé.
		# Sinon l'objet reste en place, le joueur doit d'abord activer un tube.
		if sorcerer.in_shop and tube_index == -1:
			return
		
		# Hors boutique : ancien comportement famille → tube
		if tube_index == -1:
			match item_attack_family:
				GlobalEnum.AttackFamily.Red:
					tube_index = 0   # Fossil
				GlobalEnum.AttackFamily.Yellow:
					tube_index = 1   # Pure
				GlobalEnum.AttackFamily.Blue:
					tube_index = 2   # Tainted
				_:
					tube_index = 0
		
		sorcerer.set_attack(tube_index, item_attack_type, item_attack_tier)
		queue_free()
