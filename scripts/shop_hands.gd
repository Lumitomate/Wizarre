extends Node2D
## Magasin Shophands (3 ou 4 joueurs) : le « décideur » — un joueur tiré au
## sort à CHAQUE visite — est enfermé en haut au centre avec 3 plaques de
## pression ; les autres sorciers attendent enfermés dans 3 espaces clos
## (droite, gauche, bas), posés sur les Marker2D_spawnerSorcier_N.
##
## Le magasin ne distribue qu'UN SEUL objet par visite : quand une main du
## décideur s'est entièrement ouverte (cf. shop_hands_decider.gd — repos =
## main fermée, tenir la plaque l'ouvre), l'objet du cadre central glisse
## dans la direction pointée, disparaît, puis réapparaît en émergeant
## doucement du bloc 5/0 de la tilemap dans l'espace choisi. Sa hitbox ne
## s'active qu'une fois le haut du bloc dépassé : il devient attrapable
## (pas de physique moteur, montée scriptée).
##
## La porte de sortie (dans l'enclos du décideur) ne s'ouvre que lorsque
## l'objet a été attrapé ; quand le décideur la touche, TOUT LE MONDE est
## téléporté au niveau suivant (goto_level change la scène entière, les
## receveurs n'ont pas à sortir de leurs espaces).
##
## À 3 joueurs : la main du bas et sa plaque sont retirées (cf. le décideur),
## et l'espace du bas est scellé dans la tilemap : la rangée (7..19, 9) est
## remplie de blocs 4/2, et tout ce qui se trouve en dessous (jusqu'au
## plancher y=15) devient des blocs 1/1 (règle validée avec le propriétaire).
##
## Jalon : le choix du magasin par nombre de joueurs (course / shophands...)
## sera à terme pondéré par des variables exportées (cf. global.gd).

signal save_data

## Distance (px, coordonnées de la scène) du glissement de l'objet quand
## une main finit de se fermer, avant sa disparition.
@export var distance_glissement: float = 128.0
## Durée (s) du glissement de l'objet vers la direction choisie.
@export var duree_glissement: float = 0.35
## Durée (s) de la montée douce de l'objet hors du bloc (émergence).
@export var duree_emergence: float = 1.2

const SOURCE_ID := 0
## Coordonnées d'atlas du « bloc 5.0 » (bloc plein d'où émerge l'objet).
const BLOC_ATLAS := Vector2i(5, 0)
## Distance verticale (px) du centre du bloc 5/0 au point de flottement de
## l'objet dans l'espace clos (identique pour les 3 espaces : bloc sous le
## trou du plancher, flottement à mi-hauteur de l'intérieur de la boîte).
const HAUTEUR_FLOTTAISON := 99.0
## Montée (px) après laquelle la hitbox de l'objet s'active : le haut du
## bloc est dépassé, l'objet est attrapable (règle validée).
const SEUIL_HITBOX := 54.0

var _decideur: Sorcerer
var _receveurs: Array[Sorcerer] = []
var _objet: AttackObject
var _bloc_par_direction := {}   # Vector2 normalisé -> Vector2 (position du bloc)
var _objet_envoye := false
var _montee_hitbox_activee := false
var _porte_ouverte := false


func _ready() -> void:
	# Spawn les joueurs via PlayerManager (joueurs figés au démarrage de la
	# partie : pas de nouveau joueur si une manette se branche ici)
	PlayerManager.spawn_all_players(self)
	# Mode boutique activé pour tous les joueurs de cette scène
	for controller_id in PlayerManager.active_player_ids():
		var player: Sorcerer = PlayerManager.players.get(controller_id)
		if player != null:
			player.in_shop = true

	# Décideur tiré au sort à chaque visite ; les autres deviennent
	# receveurs, répartis au hasard dans les espaces clos
	_tirer_decideur()
	if _receveurs.size() < 3:
		$ShophandsDecider.retirer_main_du_bas()
		_sceller_espace_du_bas()
	_representer_receveurs()

	# Seul le décideur sort par la porte d'entrée : les receveurs se sont
	# auto-inscrits à la porte à leur spawn, on vide la file avant de
	# n'y (ré)inscrire que le décideur
	var porte: EntryDoorCinematic = _find_entry_door()
	if porte != null and _decideur != null:
		porte.reinitialiser_inscriptions()
		porte.inscrire_sorcier(_decideur, 0)
		_decideur._door_cine = porte
		porte.cinematique_terminee.connect(_on_cinematique_terminee)
		porte.lancer_cinematique()
	else:
		# Pas de porte (ou pas de joueur) : pas de cinématique, tout le
		# monde est libre immédiatement
		_on_cinematique_terminee()

	# Cartographie des blocs 5/0, APRÈS le scellement à 3 joueurs : la
	# direction de chaque main est reliée au bloc d'où émergera l'objet
	_cartographier_blocs()

	# Récupération de l'objet spawné (ajout deferred) par le spawner central
	child_entered_tree.connect(_on_child_entered_tree)
	# Décision du décideur → envoi de l'objet vers l'espace choisi
	$ShophandsDecider.direction_choisie.connect(_on_direction_choisie)


## Tire au hasard, parmi les joueurs actifs, celui qui décidera qui reçoit
## l'objet. Les autres deviennent les receveurs.
func _tirer_decideur() -> void:
	var joueurs: Array[Sorcerer] = []
	for controller_id in PlayerManager.active_player_ids():
		var player: Sorcerer = PlayerManager.players.get(controller_id)
		if player != null:
			joueurs.append(player)
	joueurs.shuffle()
	if joueurs.is_empty():
		# Ne devrait jamais arriver (routage 3-4 joueurs) : garde-fou pour
		# les tests headless et les ouvertures de scène hors partie
		push_error("Shophands : aucun joueur actif (routage 3-4 joueurs attendu)")
		return
	_decideur = joueurs[0]
	_receveurs.assign(joueurs.slice(1))


## Pose chaque receveur sur un marqueur d'espace clos (attribution au
## hasard, cf. tirage validé). Les receveurs se sont auto-inscrits à la
## porte d'entrée à leur spawn (comportement par défaut du sorcier) : on
## les « dé-fantôme » — visibles (fin du fade d'arrivée), solides, déliés
## de la porte — et gelés jusqu'à la refermeture de la porte du décideur.
func _representer_receveurs() -> void:
	var marqueurs: Array[Marker2D] = [
		$Marker2D_spawnerSorcier_2,
		$Marker2D_spawnerSorcier_3,
	]
	if _receveurs.size() >= 3:
		marqueurs.append($Marker2D_spawnerSorcier_4)
	marqueurs.shuffle()
	for i in _receveurs.size():
		var receveur: Sorcerer = _receveurs[i]
		receveur.position = marqueurs[i % marqueurs.size()].position
		receveur._door_cine = null
		receveur.collision_layer = receveur._collision_layer_origin
		receveur.dash_shader_material.set_shader_parameter("arrival_fade", 1.0)
		if receveur.has_node("SorcererSac"):
			receveur.get_node("SorcererSac").modulate.a = 1.0


## Scelle l'espace du bas (variante 3 joueurs, règle validée) : la rangée
## de tuiles (7..19, 9) passe en blocs 4/2, et tout ce qui se trouve en
## dessous (jusqu'au plancher y=15) devient des blocs 1/1.
func _sceller_espace_du_bas() -> void:
	var tm: TileMapLayer = $TileMapLayer
	for x in range(7, 20):
		tm.set_cell(Vector2i(x, 9), SOURCE_ID, Vector2i(4, 2))
		for y in range(10, 16):
			tm.set_cell(Vector2i(x, y), SOURCE_ID, Vector2i(1, 1))


## Relie chaque direction de main au bloc 5/0 correspondant (trouvé dans la
## tilemap) : c'est de ce bloc qu'émergera l'objet dans l'espace choisi.
## À appeler APRÈS le scellement à 3 joueurs (le bloc du bas disparaît).
func _cartographier_blocs() -> void:
	var centre_decideur: Vector2 = $ShophandsDecider.position
	for cellule in $TileMapLayer.get_used_cells():
		if $TileMapLayer.get_cell_atlas_coords(cellule) != BLOC_ATLAS:
			continue
		var position_bloc: Vector2 = to_local(
			$TileMapLayer.to_global($TileMapLayer.map_to_local(cellule))
		)
		var delta: Vector2 = position_bloc - centre_decideur
		var direction: Vector2
		if absf(delta.y) > absf(delta.x):
			direction = Vector2.DOWN if delta.y > 0.0 else Vector2.UP
		else:
			direction = Vector2.RIGHT if delta.x > 0.0 else Vector2.LEFT
		_bloc_par_direction[direction] = position_bloc


## L'objet vient d'être spawné par le spawner central (ajout deferred) :
## il flotte au centre du cadre, DERRIÈRE son sprite transparent et derrière
## les tuiles (l'émergence depuis le bloc sera lisible). Sa hitbox est
## désactivée tant qu'il est au centre : le décideur ne peut pas le voler
## (sinon softlock : plus d'objet à distribuer, porte jamais ouverte).
func _on_child_entered_tree(child: Node) -> void:
	if _objet == null and child is AttackObject:
		_objet = child
		child.z_index = -1
		child.monitoring = false
		if not child.attrapee.is_connected(_on_objet_attrape):
			child.attrapee.connect(_on_objet_attrape)


## La décision est gravée : l'objet glisse dans la direction pointée par la
## main, disparaît, puis réapparaît au bloc de l'espace choisi d'où il
## émerge doucement (pas de physique moteur : montée scriptée).
func _on_direction_choisie(direction: Vector2) -> void:
	if _objet == null or _objet_envoye:
		return
	if not _bloc_par_direction.has(direction):
		push_error("Shophands : aucun bloc 5/0 trouvé pour la direction %s" % direction)
		return
	_objet_envoye = true
	_montee_hitbox_activee = false
	var bloc: Vector2 = _bloc_par_direction[direction]
	var tween := create_tween()
	# Glissement de l'objet dans la direction pointée par la main…
	tween.tween_property(
		_objet, "position",
		_objet.position + direction * distance_glissement,
		duree_glissement
	)
	# … puis disparition, courte pause, et réapparition au bloc de l'espace
	# choisi, d'où il émerge doucement.
	tween.tween_callback(func(): _objet.visible = false)
	tween.tween_interval(0.2)
	tween.tween_callback(func() -> void:
		_objet.position = bloc
		_objet.visible = true)
	tween.tween_method(_monter_objet.bind(bloc), 0.0, 1.0, duree_emergence) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Montée douce de l'objet hors du bloc (t = progression 0→1). Sa hitbox
## s'active dès qu'il a dépassé le haut du bloc : il devient attrapable
## même en plein vol (règle validée : dès que sa hitbox sort du bloc).
func _monter_objet(t: float, bloc: Vector2) -> void:
	var depart: Vector2 = bloc
	var arrivee: Vector2 = bloc + Vector2(0, -HAUTEUR_FLOTTAISON)
	_objet.position = depart.lerp(arrivee, t)
	if not _montee_hitbox_activee and _objet.position.y <= bloc.y - SEUIL_HITBOX:
		_montee_hitbox_activee = true
		# set_deferred : on est peut-être en pleine passe physique
		_objet.set_deferred("monitoring", true)


## L'objet a été attrapé : la porte de sortie (dans l'enclos du décideur)
## peut enfin s'ouvrir.
func _on_objet_attrape(_sorcier: Sorcerer) -> void:
	if _porte_ouverte:
		return
	_porte_ouverte = true
	$ShopDoor.play()


func _on_cinematique_terminee() -> void:
	for receveur in _receveurs:
		if is_instance_valid(receveur):
			receveur.frozen = false


func goto_level() -> void:
	save_data.emit()
	Global.goto_scene(GlobalEnum.Location.LEVEL)


func _on_shop_door_shop_entered() -> void:
	goto_level()


func _find_entry_door() -> EntryDoorCinematic:
	for child in get_children():
		if child is EntryDoorCinematic:
			return child
	return null
