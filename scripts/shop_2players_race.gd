extends Node2D
## Magasin course à 2 joueurs : arrivée par les portes d'entrée (une par
## couloir), génération procédurale du layout des 2 couloirs (le MÊME
## layout pour les 2 joueurs), bulle de verre ouverte dès l'arrivée avec un
## objet spawné en son centre, sortie par la ShopDoor.
##
## Le layout est régénéré à CHAQUE arrivée dans la scène : faire un level et
## retomber sur ce magasin donne un parcours différent. La propriété
## layout_seed (exportée) permet de figer la génération pour la tester ;
## -1 = aléatoire.

signal save_data

## Seed de génération (-1 = aléatoire à chaque arrivée dans le magasin)
@export var layout_seed: int = -1

const GENERATOR := preload("res://scripts/corridor_layout_generator.gd")

# Coin haut-gauche de chaque couloir, en coordonnées de TileMap
const COULOIR_HAUT_ORIGIN := Vector2i(4, 4)
const COULOIR_BAS_ORIGIN := Vector2i(4, 11)
const COULOIR_SIZE := Vector2i(17, 4)


func _ready() -> void:
	# Spawn les joueurs via PlayerManager (joueurs figés au démarrage de
	# la partie : pas de nouveau joueur si une manette se branche ici)
	PlayerManager.spawn_all_players(self)
	# Mode boutique activé pour tous les joueurs de cette scène
	for controller_id in PlayerManager.active_player_ids():
		var player: Sorcerer = PlayerManager.players.get(controller_id)
		if player != null:
			player.in_shop = true
	# La porte de sortie s'ouvre dès l'arrivée dans la salle
	$ShopDoor.play()
	_generate_corridors()
	# La bulle s'ouvre dès l'arrivée (anim de cassure) ; sa hitbox saute
	# à la frame 15 dans _process, libérant l'objet spawné en son centre
	$Bubble/AnimatedSprite2D_Bulle.play("default")


func _process(_delta: float) -> void:
	var bubble_collision: CollisionShape2D = $Bubble/CollisionShape2D
	if not bubble_collision.disabled and $Bubble/AnimatedSprite2D_Bulle.frame >= 15:
		bubble_collision.set_deferred("disabled", true)


## Génère UN SEUL layout 17×4 et l'applique à l'identique aux 2 couloirs
## (le parcours du couloir du haut est identique à celui du bas).
func _generate_corridors() -> void:
	var rng := RandomNumberGenerator.new()
	if layout_seed >= 0:
		rng.seed = layout_seed
	else:
		rng.randomize()

	var layout: Array = GENERATOR.generer(rng)
	var tilemap: TileMapLayer = $TileMapLayer
	GENERATOR.appliquer(tilemap, COULOIR_HAUT_ORIGIN, layout)
	GENERATOR.appliquer(tilemap, COULOIR_BAS_ORIGIN, layout)


func goto_level():
	save_data.emit()
	Global.goto_scene(GlobalEnum.Location.LEVEL)


func _on_shop_door_shop_entered() -> void:
	goto_level()