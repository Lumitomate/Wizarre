extends Node2D
## Magasin course à 3-4 joueurs : arrivée par 4 portes d'entrée (2 à
## gauche, 2 à droite), 4 zones procédurales 6×5 en SYMÉTRIE MIROIR (2 à
## gauche, 2 à droite), sortie centrale (ShopDoor) et cabine centrale
## (remplace la bulle de verre, cf. cabin.gd) qui contient l'objet.
##
## ZONES PROCÉDURALES 6×5 (coords de TileMap) :
##  - gauche  : (3,3)-(8,7)   et (3,10)-(8,14)   — layout TEL QUEL
##    (parcours gauche → droite, le piège à marche arrière fonctionne) ;
##  - droite  : (19,3)-(24,7)  et (19,10)-(24,14) — layout MIROIR
##    horizontal (parcours droite → gauche, même parcours symétrique).
## Les 4 zones sont toujours remplies ; à 3 joueurs, le 4e couloir reste
## vide (sa porte d'entrée se referme seule, cf. entry_door_cinematic.gd).
##
## PORTE D'ÉPREUVE : une seule porte, juste devant la cabine. 2 sabliers
## (un par côté) : ils démarrent leur rotation avec l'ouverture des
## portes d'entrée ; la fin du premier écoulement referme la porte ; un
## joueur qui passe par sa hitbox de passage la réouvre pour de bon.
##
## PORTE DE SORTIE : fermée à l'arrivée ; elle s'ouvre à la PREMIÈRE de
## ces deux échéances — fin du rituel de la cabine (attaque installée)
## ou fin des DEUX sabliers SUIVIE de la descente complète de la porte
## d'épreuve (répit des retardataires, cf. _on_sablier_fini). Une fois
## ouverte, elle ne se referme jamais.

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

# Nombre de sabliers qui ont fini de s'écouler : la sortie attend les DEUX.
var _sabliers_finis := 0
# La porte de sortie a été ouverte (une fois pour toutes).
var _sortie_ouverte := false


func _ready() -> void:
	# Spawn les joueurs via PlayerManager (joueurs figés au démarrage de
	# la partie : pas de nouveau joueur si une manette se branche ici)
	PlayerManager.spawn_all_players(self)
	# Mode boutique activé pour tous les joueurs de cette scène
	for controller_id in PlayerManager.active_player_ids():
		var player: Sorcerer = PlayerManager.players.get(controller_id)
		if player != null:
			player.in_shop = true
	# La porte de sortie reste FERMÉE à l'arrivée : elle s'ouvre à la
	# PREMIÈRE de ces deux échéances (règle validée avec le propriétaire,
	# comme dans la course 2 joueurs) : la fin du rituel de la cabine
	# (sort_installe), ou la fin des DEUX sabliers SUIVIE de la descente
	# COMPLÈTE de la porte d'épreuve (répit des retardataires, cf.
	# _on_sablier_fini).
	(get_node("Bubble2") as Cabin).sort_installe.connect(_essayer_ouvrir_sortie)
	# La rotation des 2 sabliers démarre avec l'ouverture des portes
	# d'entrée ; la fin d'un écoulement referme les 2 portes d'épreuve
	for sablier in _sabliers():
		sablier.demarrer_rotation()
		sablier.ecoulement_termine.connect(_fermer_portes_epreuve)
		sablier.ecoulement_termine.connect(_on_sablier_fini)
	# Hitbox de passage de la porte d'épreuve : la traverser la déverrouille
	# pour de bon
	for porte in _portes_epreuve():
		porte.get_node("ZonePassage").body_entered.connect(_on_zone_passage_traversee)
	_generate_zones()
	# L'objet est porté par la cabine (BubbleCabine), qui gère tout son
	# rituel d'entrée : plus de bulle à casser ici.
	# Cinématique d'arrivée : UNE porte par joueur (1 couloir chacun) ;
	# à 3 joueurs, la porte restante se referme seule
	for child in get_children():
		if child is EntryDoorCinematic:
			_portes_entree_actives += 1
			child.cinematique_terminee.connect(_on_porte_entree_terminee)
			child.lancer_cinematique()
	if _portes_entree_actives == 0:
		_demarrer_ecoulement()


func _portes_epreuve() -> Array:
	return [$PorteMagasinEpreuve]


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


## Fin d'UN sablier : la porte d'épreuve se ferme et le compteur avance.
## Quand les DEUX ont fini : la sortie attend la fin TOTALE de la
## fermeture de la porte d'épreuve — le répit des retardataires, celui
## qui a dashé sous la porte pendant qu'elle descendait a exactement le
## temps de la descente pour atteindre la cabine (même mécanique que la
## course 2 joueurs ; les deux scènes n'ont pas de classe de base).
func _on_sablier_fini() -> void:
	_sabliers_finis += 1
	if _sabliers_finis < _sabliers().size() or _sortie_ouverte:
		return
	get_tree().create_timer(_portes_epreuve()[0].duree_fermeture()).timeout.connect(
		_essayer_ouvrir_sortie)


## Ouvre la porte de sortie (première échéance : fin du rituel de la
## cabine, ou fin de la descente de la porte d'épreuve — les deux
## événements sont connectés ici). Une fois ouverte, elle ne se referme
## pas. Les paramètres absorbent les 4 arguments du signal sort_installe
## (inutilisés ici).
func _essayer_ouvrir_sortie(_s: Sorcerer = null, _t: int = 0, _ty: int = 0,
		_ti: int = 0) -> void:
	if _sortie_ouverte:
		return
	_sortie_ouverte = true
	$ShopDoor.play()


## Fin d'un écoulement de sablier : la porte d'épreuve se ferme
## (le fermer() est ignoré si la porte est déjà verrouillée ouverte).
func _fermer_portes_epreuve() -> void:
	for porte in _portes_epreuve():
		porte.fermer()


## Un joueur a passé la hitbox de la porte : elle se réouvre et reste
## ouverte pour de bon.
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
