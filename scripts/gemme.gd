class_name Gemme extends Area2D


@export var gemme_color: Enum.AttackFamily


var animation_suffix: String


func _ready() -> void:
	match gemme_color:
		Enum.AttackFamily.Blue:
			animation_suffix = "blue"
		Enum.AttackFamily.Red:
			animation_suffix = "red"
		Enum.AttackFamily.Yellow:
			animation_suffix = "yellow"
	$AnimatedSprite2D.play("shine_" + animation_suffix)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_group"):
		var sorcerer: Sorcerer = body
		sorcerer.add_ammo(gemme_color, 1)
		queue_free()
