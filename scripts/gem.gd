class_name Gem extends Area2D


@export var gem_color: GlobalEnum.AttackFamily


var animation_suffix: String


func _ready() -> void:
	match gem_color:
		GlobalEnum.AttackFamily.Blue:
			animation_suffix = "blue"
		GlobalEnum.AttackFamily.Red:
			animation_suffix = "red"
		GlobalEnum.AttackFamily.Yellow:
			animation_suffix = "yellow"
	$AnimatedSprite2D.play("shine_" + animation_suffix)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_group"):
		var sorcerer: Sorcerer = body
		var tube_index = {
			GlobalEnum.AttackFamily.Red: 0,
			GlobalEnum.AttackFamily.Yellow: 1,
			GlobalEnum.AttackFamily.Blue: 2
		}.get(gem_color, -1)
		if tube_index != -1:
			sorcerer.add_energy(tube_index, 1)
		queue_free()
