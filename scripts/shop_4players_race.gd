extends Node2D
## Magasin course à 3-4 joueurs : arrivée par 4 portes d'entrée (2 à
## gauche, 2 à droite), 4 zones procédurales 6×5 en SYMÉTRIE MIROIR (2 à
## gauche, 2 à droite), sortie centrale (ShopDoor) et bulle centrale avec
## un objet spawné en son centre.
##
## ZONES PROCÉDURALES 6×5 (coords de TileMap) :
##  - gauche  : (3,3)-(8,7)   et (3,10)-(8,14)   — layout TEL QUEL
##    (parcours gauche → droite, le piège à marche arrière fonctionne) ;
##  - droite  : (19,3)-(24,7)  et (19,10)-(24,14) — layout MIROIR
##    horizontal (parcours droite → gauche, même parcours symétrique).
## Les 4 zones sont toujours remplies ; à 3 joueurs, le 4e couloir reste
## vide (sa porte d'entrée se referme seule, cf. entry_door_cinematic.gd).
##
## PORTES D'ÉPREUVE LIÉES : 2 portes (une par côté), 2 sabliers. Les 2
## sabliers démarrent leur rotation avec l'ouverture des portes d'entrée ;
## la fin du premier écoulement referme LES DEUX portes ; un joueur qui
## passe par L'UNE des hitbox de passage les réouvre TOUTES LES DEUX
## (verrou partagé).

signal save_data

## Seed de génération (-1 = aléatoire à chaque arrivée dans le magasin)
@export var layout_seed: int = -1

const GENERATOR := preload("res://scripts/corridor_layout_generator.gd")

# Dimensions d'une zone procédurale
const ZONE_LARGEUR := 6
const ZONE_HAUTEUR := 5

# Coins haut-gauche des zones, en coords de TileMap
const ZONES_GAUCHE := [Vector2i(3, 3), Vector2i(3, 10)]
const ZONES_DROITE := [Vector2i(19, 3), Vector2i(19, 10)]

# Nombre de portes d'entrée dont la cinématique n'est pas encore finie :
# les sabliers passent à l'écoulement quand la dernière a terminé
var _portes_entree_actives := 0


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
	# La rotation des 2 sabliers démarre avec l'ouverture des portes
	# d'entrée ; la fin d'un écoulement referme les 2 portes d'épreuve
	for sablier in _sabliers():
		sablier.demarrer_rotation()
		sablier.ecoulement_termine.connect(_fermer_portes_epreuve)
	# Hitbox de passage des 2 portes liées : croiser l'une déverrouille
	# les deux (verrou partagé)
	for porte in _portes_epreuve():
		porte.get_node("ZonePassage").body_entered.connect(_on_zone_passage_traversee)
	_generate_zones()
	# La bulle s'ouvre dès l'arrivée (anim de cassure) ; sa hitbox saute
	# à la frame 15 dans _process, libérant l'objet spawné en son centre
	$Bubble/AnimatedSprite2D_Bulle.play("default")
	# Cinématique d'arrivée : UNE porte par joueur (1 couloir chacun) ;
	# à 3 joueurs, la porte restante se referme seule
	for child in get_children():
		if child is EntryDoorCinematic:
			_portes_entree_actives += 1
			child.cinematique_terminee.connect(_on_porte_entree_terminee)
			child.lancer_cinematique()
	if _portes_entree_actives == 0:
		_demarrer_ecoulement()


func _process(_delta: float) -> void:
	var bubble_collision: CollisionShape2D = $Bubble/CollisionShape2D
	if not bubble_collision.disabled and $Bubble/AnimatedSprite2D_Bulle.frame >= 15:
		bubble_collision.set_deferred("disabled", true)


func _portes_epreuve() -> Array:
	return [$PorteMagasinEpreuve, $PorteMagasinEpreuve2]


func _sabliers() -> Array:
	return [$Sablier, $Sablier2]


## Une porte d'entrée a fini sa cinématique (porte refermée, joueur
## libéré). Quand la DERNIÈRE a terminé, tous les joueurs sont libres :
## les sabliers passent à l'écoulement (no-op s'il a déjà commencé : la
## rotation n'aurait duré que 1,25 s et le sable coule déjà).
func _on_porte_entree_terminee() -> void:
	_portes_entree_actives -= 1
	if _portes_entree_actives <= 0:
		_demarrer_ecoulement()


func _demarrer_ecoulement() -> void:
	for sablier in _sabliers():
		sablier.demarrer()


## Fin d'un écoulement de sablier : les DEUX portes d'épreuve se ferment
## (le fermer() est ignoré si une porte est déjà verrouillée ouverte).
func _fermer_portes_epreuve() -> void:
	for porte in _portes_epreuve():
		porte.fermer()


## Un joueur a passé la hitbox d'UNE des portes : les DEUX se réouvrent
## et restent ouvertes (verrou partagé).
func _on_zone_passage_traversee(body: Node2D) -> void:
	if not (body is Sorcerer):
		return
	for porte in _portes_epreuve():
		porte.deverrouiller()


## Génère UN layout 6×5 et l'applique aux 4 zones : tel quel à gauche
## (parcours gauche → droite), miroir horizontal à droite (parcours
## droite → gauche, symétrique de celui de gauche).
func _generate_zones() -> void:
	var rng := RandomNumberGenerator.new()
	if layout_seed >= 0:
		rng.seed = layout_seed
	else:
		rng.randomize()

	var layout: Array = GENERATOR.generer(rng, ZONE_LARGEUR, ZONE_HAUTEUR)
	var layout_miroir := _miroir_horizontal(layout)
	var tilemap: TileMapLayer = $TileMapLayer
	for origin in ZONES_GAUCHE:
		GENERATOR.appliquer(tilemap, origin, layout)
	for origin in ZONES_DROITE:
		GENERATOR.appliquer(tilemap, origin, layout_miroir)


## Retourne le layout retourné horizontalement (chaque ligne inversée) :
## le piège à marche arrière pousse alors vers la gauche, ce qui correspond
## au parcours droite → gauche des couloirs de droite.
static func _miroir_horizontal(layout: Array) -> Array:
	var miroir: Array = []
	for y in layout.size():
		var ligne: Array = []
		for x in range(layout[y].size() - 1, -1, -1):
			ligne.append(layout[y][x])
		miroir.append(ligne)
	return miroir


func goto_level():
	save_data.emit()
	Global.goto_scene(GlobalEnum.Location.LEVEL)


func _on_shop_door_shop_entered() -> void:
	goto_level()
