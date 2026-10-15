class_name ShopIntroBase
extends Node2D
## Classe de base des magasins intro (2 joueurs et 4 joueurs) : toute la
## mécanique commune, pour qu'une règle ne soit jamais écrite deux fois.
##
## Concept (validé avec le propriétaire, commun aux deux salles) :
##  - Chaque joueur arrive par sa porte d'entrée (cinématique, cf.
##    entry_door_cinematic.gd) dans son couloir.
##  - À l'entrée, les tubes de chaque joueur sont VIDÉS (aucun sort,
##    aucune icône), à CHAQUE passage.
##  - Face à lui, une bulle de verre contenant un objet visible dès
##    l'arrivée. La bulle casse au CONTACT du joueur (règle du magasin
##    classique) et l'objet devient prenable.
##  - Les bulles actives ne proposent JAMAIS deux fois le même type
##    d'attaque (coordination par la sous-classe, cf.
##    _coordonner_types_objets).
##  - La prise de l'objet ouvre la porte dieu du couloir ; la
##    ZonePassage de la porte dieu OUVERTE signe le passage du couloir
##    (garde-fou : le passage ne compte qu'après la prise de l'objet).
##  - Tous les couloirs ACTIFS passés → la ShopDoor s'ouvre ; la
##    traversée emmène tout le monde au niveau 1.
##  - Selon le nombre de joueurs, les couloirs en trop sont SCELLÉS de
##    blocs 1:1 (portes d'entrée, bulles et portes dieu enterrées,
##    objets éliminés) — disposition propre à chaque sous-classe, cf.
##    _configurer_couloirs.

signal save_data

## Source de tilemap pour set_cell (atlas unique de la scène).
const SOURCE_ID := 0
## Coordonnées d'atlas du bloc plein de scellement.
const BLOC_SCELLEMENT := Vector2i(1, 1)
## Frame de l'anim de cassure de la bulle où sa collision saute
## (convention du magasin course).
const BULLE_FRAME_CASSURE := 15

## Nombre de portes d'entrée dont la cinématique n'est pas encore finie.
var _portes_entree_actives := 0
## {objet: couloir} association objet ↔ couloir (posée au spawn).
var _objet_par_couloir: Dictionary = {}
## {couloir: bool} l'objet du couloir a été pris.
var _objets_pris: Dictionary = {}
## {couloir: bool} la ZonePassage de la porte dieu a été franchie.
var _passages: Dictionary = {}
## Couloirs actifs selon le nombre de joueurs (défini par la sous-classe).
var _couloirs_actifs: Array[int] = []
## La porte Shop a été ouverte (une fois pour toutes).
var _shop_ouverte := false
## {couloir: bool} la bulle du couloir a été cassée au contact.
var _bulles_cassees: Dictionary = {}


func _ready() -> void:
	# Spawn les joueurs via PlayerManager (joueurs figés au démarrage de
	# la partie : pas de nouveau joueur si une manette se branche ici)
	PlayerManager.spawn_all_players(self)
	var ids := PlayerManager.active_player_ids()
	for controller_id: int in ids:
		var player: Sorcerer = PlayerManager.players.get(controller_id)
		if player == null:
			continue
		player.in_shop = true
		# Règle de l'intro : le joueur arrive sans aucune attaque. Les
		# sorts ont été chargés de la run précédente : on les vide ici
		# (à CHAQUE passage, règle validée), icônes du sac comprises.
		_vider_tubes(player)
	# Repli selon le nombre de joueurs : couloirs actifs, scellement des
	# couloirs en trop, élimination de leurs objets (sous-classe).
	_configurer_couloirs(ids.size())
	# Association objets ↔ couloirs dès leur spawn (ajout différé du
	# spawner : les objets entrent dans l'arbre après ce _ready).
	for couloir: int in _couloirs_actifs:
		_bulle(couloir).child_entered_tree.connect(_on_objet_spawned.bind(couloir))
	# Règle « jamais deux fois le même type » entre les bulles actives
	# (sous-classe : les spawners ne se voient pas entre eux).
	_coordonner_types_objets()
	# Passage des portes dieu : la ZonePassage de chaque porte signe le
	# passage du couloir (mécanique ZonePassage de la salle race).
	for couloir: int in _couloirs_actifs:
		_porte_dieu(couloir).get_node("ZonePassage").body_entered.connect(
			_on_zone_passage.bind(couloir))
	# Bulles : la casse ne démarre qu'au CONTACT du joueur (règle
	# validée : l'objet flotte derrière la bulle fermée jusqu'à ce qu'on
	# la touche). Seuls les couloirs actifs sont écoutés.
	for couloir: int in _couloirs_actifs:
		_bulle(couloir).get_node("ZoneContact").body_entered.connect(
			_on_bulle_contactee.bind(couloir))
	# Porte de sortie : la traversée emmène tout le monde au niveau 1.
	if not $ShopDoor.shop_entered.is_connected(_on_shop_door_shop_entered):
		$ShopDoor.shop_entered.connect(_on_shop_door_shop_entered)
	# Cinématiques d'arrivée : une porte par couloir (les portes des
	# couloirs scellés restent muettes : personne n'en sort).
	for child in get_children():
		if child is EntryDoorCinematic:
			child.cinematique_terminee.connect(_on_porte_entree_terminee)
			child.lancer_cinematique()
			_portes_entree_actives += 1


## SOUS-CLASSE : définit _couloirs_actifs selon nb_joueurs, scelle les
## couloirs inactifs (_sceller_zone) et branche l'élimination des objets
## des bulles scellées.
func _configurer_couloirs(_nb_joueurs: int) -> void:
	pass


## SOUS-CLASSE : règle « jamais deux fois le même type d'attaque » entre
## les bulles actives. Les spawners ont déjà choisi et mis en file leurs
## objets (leur _ready précède celui de la racine, et chaque spawner ne
## voit que ses frères) : c'est l'hôte qui fait respecter la règle.
func _coordonner_types_objets() -> void:
	pass


## SOUS-CLASSE : bulle d'un couloir.
func _bulle(_couloir: int) -> Node2D:
	return null


## SOUS-CLASSE : porte dieu d'un couloir.
func _porte_dieu(_couloir: int) -> Node:
	return null


## Scelle une zone de la tilemap en blocs 1:1 (cases debut → fin
## incluses) : disposition demandée par le propriétaire.
func _sceller_zone(debut: Vector2i, fin: Vector2i) -> void:
	var tilemap: TileMapLayer = $TileMapLayer
	for y in range(debut.y, fin.y + 1):
		for x in range(debut.x, fin.x + 1):
			tilemap.set_cell(Vector2i(x, y), SOURCE_ID, BLOC_SCELLEMENT)


## Vide les 3 tubes du sorcier (aucun sort, aucune icône, tube désélectionné).
func _vider_tubes(player: Sorcerer) -> void:
	player.spells = {0: {}, 1: {}, 2: {}}
	player.selected_tube = -1
	if player.has_node("SorcererSac"):
		player.get_node("SorcererSac").refresh_all()


## Un objet (AttackObject) vient d'entrer dans l'arbre sous une bulle :
## mémorisé pour son couloir, sa prise ouvrira la porte dieu du couloir.
func _on_objet_spawned(child: Node, couloir: int) -> void:
	if child is AttackObject:
		_objet_par_couloir[child] = couloir
		if not child.attrapee.is_connected(_on_objet_attrape):
			child.attrapee.connect(_on_objet_attrape.bind(couloir))


## Contact d'un joueur avec une bulle d'un couloir actif : la bulle casse
## (une seule fois), sa collision sautera à la frame de cassure (cf.
## _process) et l'objet flottant derrière devient prenable.
func _on_bulle_contactee(body: Node2D, couloir: int) -> void:
	if not (body is Sorcerer):
		return
	if couloir not in _couloirs_actifs or _bulles_cassees.get(couloir, false):
		return
	_bulles_cassees[couloir] = true
	_bulle(couloir).get_node("AnimatedSprite2D_Bulle").play(&"default")


func _process(_delta: float) -> void:
	# Collision des bulles cassées : saute à la frame de cassure
	# (pattern du magasin course). Une bulle intacte (Idle, frame 0) garde
	# sa collision : elle bloque le passage jusqu'à son ouverture.
	for couloir: int in _couloirs_actifs:
		if _bulles_cassees.get(couloir, false):
			_collision_bulle_si_cassee(_bulle(couloir))


func _collision_bulle_si_cassee(bulle: Node2D) -> void:
	var collision: CollisionShape2D = bulle.get_node("CollisionShape2D")
	if not collision.disabled and bulle.get_node("AnimatedSprite2D_Bulle").frame >= BULLE_FRAME_CASSURE:
		collision.set_deferred("disabled", true)


## Prise d'un objet : l'objet du couloir est marqué pris et la porte dieu
## du couloir s'ouvre (anim dieu). Le passage dans la ZonePassage ouvrira
## ensuite la ShopDoor (cf. _on_zone_passage).
func _on_objet_attrape(_sorcier: Sorcerer, couloir: int) -> void:
	_objets_pris[couloir] = true
	var porte: Node = _porte_dieu(couloir)
	if porte != null:
		porte.ouvrir()


## Passage franchi via ZonePassage : le bind place le couloir APRÈS le
## corps (signal body_entered → (body, couloir)). Ne compte que si
## l'objet du couloir a été pris (garde-fou validé). Tous les couloirs
## actifs passés → la ShopDoor s'ouvre.
func _on_zone_passage(body: Node2D, couloir: int) -> void:
	if not (body is Sorcerer):
		return
	if couloir not in _couloirs_actifs:
		return
	if not _objets_pris.get(couloir, false):
		return
	_passages[couloir] = true
	_verifier_ouverture_shop()


func _verifier_ouverture_shop() -> void:
	if _shop_ouverte:
		return
	for couloir: int in _couloirs_actifs:
		if not _passages.get(couloir, false):
			return
	_shop_ouverte = true
	$ShopDoor.play()


func goto_level() -> void:
	save_data.emit()
	Global.goto_scene(GlobalEnum.Location.LEVEL)


func _on_shop_door_shop_entered() -> void:
	goto_level()


## Une porte d'entrée a fini sa cinématique (joueur libéré). Le joueur
## court vers sa bulle : le contact la cassera (cf. _on_bulle_contactee).
func _on_porte_entree_terminee() -> void:
	_portes_entree_actives -= 1
