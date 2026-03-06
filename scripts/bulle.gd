extends StaticBody2D

var can_open : bool = true

signal sorcerer_contact_bubble


func _ready() -> void:
	$AnimatedSprite2D.play("Idle")

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_group") and can_open:
		
		#var sorcerer:Sorcerer=body
		
		sorcerer_contact_bubble.emit()	
		open_bubble.call_deferred()
	
func open_bubble() -> void:
	$AnimatedSprite2D.play("Ouverture")

func _process(_delta: float) -> void:
	if $AnimatedSprite2D.frame >= 15:
		$CollisionShape2D.disabled = true
