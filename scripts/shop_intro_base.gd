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
##  - Face à lui, une CABINE (bubble_cabine.tscn, cf. CONTEXT.md) tenant
##    un objet visible dès l'arrivée. Le sorcier y entre : la porte se
##    referme derrière lui et le rituel de choix du tube démarre
##    (cf. cabin.gd).
##  - LA FIN DU RITUEL (sort installé — signal sort_installe) fait les
##    DEUX : elle valide le couloir (tous les couloirs ACTIFS validés →
##    la ShopDoor s'ouvre) et elle ouvre la porte défi du couloir, pour
##    laisser le sorcier rejoindre la sortie. Ni la fermeture de la
##    porte de la cabine, ni le passage dans la porte défi ne
##    conditionnent la sortie (règle validée avec le propriétaire).
##  - Les cabines actives ne proposent JAMAIS deux fois le même type
##    d'attaque (coordination par la sous-classe, cf.
##    _coordonner_types_objets).
##  - Selon le nombre de joueurs, les couloirs en trop sont SCELLÉS de
##    blocs 1:1 (portes d'entrée, cabines et portes dieu enterrées,
##    objets éliminés) — disposition propre à chaque sous-classe, cf.
##    _configurer_couloirs.

signal save_data

## Source de tilemap pour set_cell (atlas unique de la scène).
const SOURCE_ID := 0
## Coordonnées d'atlas du bloc plein de scellement.
const BLOC_SCELLEMENT := Vector2i(1, 1)

## Nombre de portes d'entrée dont la cinématique n'est pas encore finie.
var _portes_entree_actives := 0
## {couloir: bool} le rituel de la cabine du couloir est terminé
## (attaque installée).
var _rituels_finis: Dictionary = {}
## Couloirs actifs selon le nombre de joueurs (défini par la sous-classe).
var _couloirs_actifs: Array[int] = []
## La porte Shop a été ouverte (une fois pour toutes).
var _shop_ouverte := false


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
	# Règle « jamais deux fois le même type » entre les cabines actives
	# (sous-classe : les spawners ne se voient pas entre eux).
	_coordonner_types_objets()
	# Cabines des couloirs ACTIFS seulement (les cabines des couloirs
	# scellés restent muettes) : la fin du rituel (sort_installe) ouvre la
	# porte défi du couloir ET valide le couloir pour la ShopDoor.
	for couloir: int in _couloirs_actifs:
		var cabine := _cabine(couloir) as Cabin
		cabine.sort_installe.connect(_on_cabine_installee.bind(couloir))
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
## des cabines scellées.
func _configurer_couloirs(_nb_joueurs: int) -> void:
	pass


## SOUS-CLASSE : règle « jamais deux fois le même type d'attaque » entre
## les cabines actives. Les spawners ont déjà choisi et mis en file leurs
## objets (leur _ready précède celui de la racine, et chaque spawner ne
## voit que ses frères) : c'est l'hôte qui fait respecter la règle.
func _coordonner_types_objets() -> void:
	pass


## SOUS-CLASSE : cabine d'un couloir.
func _cabine(_couloir: int) -> Node2D:
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
	if player.has_node("PipeManager"):
		player.get_node("PipeManager").refresh_all()


## Fin du rituel d'une cabine (sort installé, juste avant la réouverture
## de ses portes) : la porte défi du couloir s'ouvre ET le couloir est
## validé ; tous les couloirs actifs validés ouvrent la ShopDoor.
func _on_cabine_installee(_sorcier: Sorcerer, _tube: int, _type: int, _tier: int,
		couloir: int) -> void:
	_ouvrir_porte_couloir(couloir)
	_rituels_finis[couloir] = true
	_verifier_ouverture_shop()


## Ouvre la porte dieu du couloir.
func _ouvrir_porte_couloir(couloir: int) -> void:
	var porte: Node = _porte_dieu(couloir)
	if porte != null:
		porte.ouvrir()


## Tous les couloirs actifs ont terminé leur rituel → la ShopDoor s'ouvre.
func _verifier_ouverture_shop() -> void:
	if _shop_ouverte:
		return
	for couloir: int in _couloirs_actifs:
		if not _rituels_finis.get(couloir, false):
			return
	_shop_ouverte = true
	$ShopDoor.play()


func goto_level() -> void:
	save_data.emit()
	Global.goto_scene(GlobalEnum.Location.LEVEL)


func _on_shop_door_shop_entered() -> void:
	goto_level()


## Une porte d'entrée a fini sa cinématique (joueur libéré). Le joueur
## court vers sa cabine : son entrée refermera la porte (cf. cabin.gd).
func _on_porte_entree_terminee() -> void:
	_portes_entree_actives -= 1
