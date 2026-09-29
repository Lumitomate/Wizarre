extends Node2D
class_name Sablier

## Sablier en deux temps :
##  1. demarrer_rotation() : la rotation joue UNE SEULE FOIS, puis
##     l'écoulement du sable démarre automatiquement ;
##  2. l'écoulement dure duree_ecoulement secondes, puis
##     ecoulement_termine est émis. La scène hôte décide quoi faire à la
##     fin (fermer une porte, recharger le magasin...).
##
## demarrer() peut être appelé pour passer à l'écoulement avant la fin de
## la rotation (ex. quand les joueurs sont libérés) ; il est ignoré si
## l'écoulement est déjà en cours. À la scène hôte d'ajuster
## duree_ecoulement pour couvrir son temps de jeu.

signal ecoulement_termine

## Durée (secondes) de l'écoulement du sable.
@export var duree_ecoulement: float = 4.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	# À l'arrivée dans la scène : sablier figé sur la 1re frame de rotation,
	# en attente d'un demarrer_rotation()
	_sprite.animation = &"rotation"
	_sprite.frame = 0
	_sprite.stop()
	if not _sprite.animation_finished.is_connected(_on_animation_finished):
		_sprite.animation_finished.connect(_on_animation_finished)


## Démarre la séquence : la rotation joue une seule fois, puis le sable
## commence à couler automatiquement.
func demarrer_rotation() -> void:
	_sprite.speed_scale = 1.0
	_sprite.play(&"rotation")


## Force le passage à l'écoulement immédiatement (interrompt la rotation
## en cours). Ignoré si l'écoulement a déjà démarré.
func demarrer() -> void:
	if _sprite.animation == &"ecoulement":
		return
	_passe_a_ecoulement()


func _passe_a_ecoulement() -> void:
	_sprite.speed_scale = _vitesse_pour_duree(&"ecoulement", duree_ecoulement)
	_sprite.play(&"ecoulement")


## speed_scale à appliquer pour que l'animation `nom` (durée naturelle
## = nb frames / fps) dure exactement `duree` secondes.
func _vitesse_pour_duree(nom: StringName, duree: float) -> float:
	var fps := _sprite.sprite_frames.get_animation_speed(nom)
	var nb_frames := _sprite.sprite_frames.get_frame_count(nom)
	if duree <= 0.0 or fps <= 0.0 or nb_frames <= 0:
		return 1.0
	return (float(nb_frames) / fps) / duree


func _on_animation_finished() -> void:
	if _sprite.animation == &"ecoulement":
		# Le sable a fini de couler : préviens la scène hôte (le sablier
		# reste affiché sur sa dernière frame)
		ecoulement_termine.emit()
	else:
		# La rotation est finie : le sable commence à couler
		_passe_a_ecoulement()
