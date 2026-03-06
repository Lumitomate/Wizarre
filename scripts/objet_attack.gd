class_name AttackObject extends Area2D

@export var item_attack_family: Enum.AttackFamily
@export var item_attack_type: Enum.AttackType
@export var item_attack_tier: Enum.AttackTier

var animation_name: String

func _ready() -> void:
	print("Object created")
	match item_attack_tier:
		Enum.AttackTier.III:
			animation_name = "Or"
		Enum.AttackTier.II:
			animation_name = "Argent"
		Enum.AttackTier.I:
			animation_name = "Bronze"
			
	$ObjetAttaqueAnimation.play(animation_name)
	
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_group"):
		var sorcerer: Sorcerer = body
		sorcerer.set_attack(item_attack_family, item_attack_type, item_attack_tier)
		queue_free()
