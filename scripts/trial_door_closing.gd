extends StaticBody2D
## Porte d'épreuve fermante (magasin course) : ouverte dès l'arrivée, elle
## se referme quand la scène hôte le demande (à la fin du sablier) et se
## réouvre DÉFINITIVEMENT si un joueur passe pendant la fermeture.
##
## Mécanique :
##  1. Ouverte de base : dernière frame de l'anim d'ouverture, collision
##     désactivée.
##  2. La hitbox ZonePassage (Area2D, taille exacte du CollisionShape)
##     détecte le passage d'un joueur : la porte est alors verrouillée
##     ouverte pour toujours (elle ne pourra plus jamais se fermer).
##  3. fermer() (déclenché par la fin du sablier) : rejoue l'anim
##     d'ouverture À L'ENVERS (la porte descend progressivement). Pendant
##     toute la descente, la collision reste désactivée : un sorcier
##     (32 px de haut) peut passer dessous pendant que la porte de 64 px
##     descend. Dès qu'un joueur passe → réouverture immédiate + verrou.
##  4. Si la porte touche le sol sans que personne n'ait passé : la
##     collision s'active (blocage des retardataires).
##
## La scène (shop_trial_door.tscn) est partagée avec le magasin classique :
## ce script ne remplace shop_trial_door.gd QUE sur l'instance du magasin
## course (override de script sur le nœud instancié).

@export var door_type: GlobalEnum.DoorType

enum Etat { OUVERTE, DESCENTE, FERMEE }

var _etat: int = Etat.OUVERTE
## Une fois vrai : la porte ne peut plus jamais se refermer.
var _verrouillee_ouverte := false
var _suffixe: String

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _zone_passage: Area2D = $ZonePassage


func _ready() -> void:
	match door_type:
		GlobalEnum.DoorType.TIME:
			_suffixe = "temps"
		GlobalEnum.DoorType.FRIENDSHIP:
			_suffixe = "amitie"
		GlobalEnum.DoorType.NO_DAMAGE:
			_suffixe = "dieu"
	# Ouverte de base : dernière frame de l'anim d'ouverture, pas solide.
	# NB : stop() remet la frame à zéro → on la positionne APRÈS stop()
	_sprite.animation = StringName("ouverture_" + _suffixe)
	_sprite.stop()
	_sprite.frame = _sprite.sprite_frames.get_frame_count(_sprite.animation) - 1
	_collision.set_deferred("disabled", true)
	if not _sprite.animation_finished.is_connected(_on_animation_finished):
		_sprite.animation_finished.connect(_on_animation_finished)
	if not _zone_passage.body_entered.is_connected(_on_zone_passage_body_entered):
		_zone_passage.body_entered.connect(_on_zone_passage_body_entered)


## Ferme la porte (appelé par la scène hôte à la fin du sablier). Ignoré
## si la porte est déjà verrouillée ouverte ou en cours d'animation.
func fermer() -> void:
	if _verrouillee_ouverte or _etat != Etat.OUVERTE:
		return
	_etat = Etat.DESCENTE
	# Descente : l'anim d'ouverture jouée à l'envers depuis la dernière
	# frame (la porte descend progressivement vers le sol)
	_sprite.play_backwards(_sprite.animation)


## Un joueur entre dans le passage : la porte est verrouillée ouverte pour
## toujours. Si elle était en train de descendre, elle se réouvre
## immédiatement (l'anim reprend vers l'avant depuis la frame courante).
func _on_zone_passage_body_entered(body: Node2D) -> void:
	if not (body is Sorcerer):
		return
	deverrouiller()


## Déverrouille la porte : elle se réouvre (si elle était en train de
## descendre) et ne pourra plus jamais se fermer. Appelée par la porte
## elle-même (hitbox de passage) ou par la scène hôte quand les portes
## sont LIÉES : croiser l'une les déverrouille toutes les deux.
func deverrouiller() -> void:
	_verrouillee_ouverte = true
	if _etat == Etat.DESCENTE:
		# play() sur la même animation reprend vers l'avant depuis la
		# frame courante : la porte remonte d'où elle en était
		_etat = Etat.OUVERTE
		_sprite.play(_sprite.animation)
	elif _etat == Etat.FERMEE:
		# Porte déjà au sol (cas limite) : elle remonte depuis le début
		# de l'anim et la collision saute
		_etat = Etat.OUVERTE
		_collision.set_deferred("disabled", true)
		_sprite.play(_sprite.animation)


func _on_animation_finished() -> void:
	# Fin d'anim atteinte uniquement si la descente s'est achevée sans
	# passage (sinon _etat repasse à OUVERTE avant la fin de l'anim)
	if _etat == Etat.DESCENTE:
		_etat = Etat.FERMEE
		# Personne n'est passé : la porte devient solide au sol
		_collision.set_deferred("disabled", false)
