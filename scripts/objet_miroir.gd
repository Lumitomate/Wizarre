extends Area2D

@export var item_tier : Enum.attacktier

var animation_suffix: String

func _ready() -> void:
	match miroir_color:
		MiroirColor.Or:
			animation_suffix = "Or"
		MiroirColor.Argent:
				animation_suffix = "Argent"
		MiroirColor.Bronze:
			animation_suffix = "Bronze"
			
	$Animatedsprite2D.play("Miroir_"+ animation_suffix)
	
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_group"):
		var sorcerer: Sorcerer = body
		sorcerer.add_ammo(gemme_color, 1)
		queue_free()
