class_name Gemme extends Area2D

enum GemmeColor {
	Red,
	Green,
	Blue,
}


@export var gemme_color: GemmeColor


var animation_suffix: String


func _ready() -> void:
	match gemme_color:
		GemmeColor.Blue:
			animation_suffix = "blue"
		GemmeColor.Red:
			animation_suffix = "red"
		GemmeColor.Green:
			animation_suffix = "green"
	$AnimatedSprite2D.play("shine_" + animation_suffix)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_group"):
		var sorcerer: Sorcerer = body
		sorcerer.add_ammo(gemme_color, 1)
		queue_free()
