extends StaticBody2D
## Porte d'épreuve du magasin intro : fermée à l'arrivée, elle s'ouvre
## (anim ouverture_<type>) quand la scène hôte le demande — c'est-à-dire
## quand le joueur du couloir a pris l'objet de sa bulle.
##
## Basée sur shop_trial_door.tscn (script override) : même assets, même
## ZonePassage de détection de passage, mais AUCUNE ouverture automatique
## (le shop_trial_door.gd d'origine s'ouvre seul après 1,5 s selon des
## conditions de run — pas ce qu'on veut ici) et AUCUNE fermeture.

@export var door_type: GlobalEnum.DoorType

## Porte ouverte (anim lancée ou terminée) : le passage dans la ZonePassage
## ne compte pour la ShopDoor que si la porte du couloir est ouverte.
var opened := false


func _ready() -> void:
	# Fermée de base : pose l'anim d'ouverture à sa frame 0, sans la jouer
	# (stop() affiche la frame 0). L'ouverture ne démarrera qu'avec ouvrir().
	$AnimatedSprite2D.animation = StringName("ouverture_" + _suffixe())
	$AnimatedSprite2D.stop()


func ouvrir() -> void:
	if opened:
		return
	opened = true
	$AnimatedSprite2D.play()


## Convention de shop_trial_door.gd : la collision saute quand l'anim
## d'ouverture atteint la frame 10 (porte entièrement levée).
func _process(_delta: float) -> void:
	if opened and $AnimatedSprite2D.frame == 10:
		$CollisionShape2D.set_deferred("disabled", true)


func _suffixe() -> String:
	match door_type:
		GlobalEnum.DoorType.TIME:
			return "temps"
		GlobalEnum.DoorType.NO_DAMAGE:
			return "dieu"
		_:
			return "amitie"
