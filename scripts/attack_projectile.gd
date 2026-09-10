class_name AttackProjectile extends Area2D

# Classe de base des projectiles (Area2D). Factorise le comportement de
# contact commun : détection des corps des deux camps et application des
# dégâts. Les projectiles spécifiques surchargent can_damage() pour leurs
# règles propres (immunité du lanceur, délai d'activation, etc.).

@export var damage: int = 1


# Hook surchargeable : le corps peut-il être touché par ce projectile ?
func can_damage(_body: Node2D) -> bool:
	return true


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_group") or body.is_in_group("enemy_group"):
		if can_damage(body):
			body.hit(damage)
