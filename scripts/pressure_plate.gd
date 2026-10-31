extends Node2D
class_name PressurePlate

## Plaque de pression à bouton : le joueur se tient DESSUS, la plaque
## s'enfonce de press_depth px sous son poids.
##
## Le mouvement (vitesse, courbe, durée de remontée) vient de
## PressurePlateMotion — la loi commune aux plaques du jeu, dont la
## référence est celle du shop reflex. Ici, seule la COURSE est propre à
## la plaque : press_depth. Ne jamais coder une durée en dur ici.
##
## Le corps mobile est un AnimatableBody2D (et non un StaticBody2D) : un
## StaticBody2D déplacé ne PORTE PAS le CharacterBody2D qui le chevauche.
## Le sorcier ne tenait dessus que grâce à floor_snap_length (1 px par pas
## de physique, cf. sorcerer.tscn) : dès que la plaque descend plus vite
## que ça, il perd le sol, passe en set_state(FALL) et un appui sur A ne
## déclenche plus de saut. AnimatableBody2D (sync_to_physics, défaut)
## déplace le corps DANS le pas de physique et le CharacterBody2D hérite
## de sa vitesse : le joueur descend AVEC la plaque, quel que soit le
## framerate. Même montage que l'ascenseur (map1_elevator.tscn).

signal activated
signal deactivated

@export var target_path: NodePath
## Course de l'enfoncement (px). Seul réglage propre à cette plaque.
@export var press_depth: float = 4.0

@onready var plate_body: AnimatableBody2D = $StaticBody2D
@onready var trigger_area: Area2D = $TriggerArea

var target: Node
var bodies_on_plate: Array = []
var press_tween: Tween
var rest_position: Vector2

func _ready() -> void:
	target = get_node_or_null(target_path)
	rest_position = plate_body.position

	trigger_area.body_entered.connect(_on_body_entered)
	trigger_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player_group"):
		return
	if body in bodies_on_plate:
		return

	bodies_on_plate.append(body)
	if bodies_on_plate.size() == 1:
		_activate()

func _on_body_exited(body: Node) -> void:
	if body in bodies_on_plate:
		bodies_on_plate.erase(body)

	if bodies_on_plate.is_empty():
		_deactivate()

func _activate() -> void:
	emit_signal("activated")
	if target and target.has_method("activate"):
		target.activate()
	_animate_plate(rest_position.y + press_depth)

func _deactivate() -> void:
	emit_signal("deactivated")
	if target and target.has_method("deactivate"):
		target.deactivate()
	_animate_plate(rest_position.y)

## Descente et remontée : même course, donc même durée (cf.
## PressurePlateMotion). Seule la cible change.
func _animate_plate(cible_y: float) -> void:
	if press_tween:
		press_tween.kill()
	press_tween = PressurePlateMotion.animer(self, plate_body, cible_y, press_depth)
	
	
