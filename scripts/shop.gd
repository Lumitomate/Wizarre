extends Node2D
## Magasin classique (1-2 joueurs, tiré par ShopRouter) : 3 cabines
## (bubble_cabine.tscn, cf. CONTEXT.md — ne pas appeler ça « bulles »),
## une par couloir, chacune tenant son power-up.
##
## Règle validée « UN SEUL OBJET PAR VISITE » : dès qu'un sorcier ENTRE
## dans une cabine (début du rituel, signal sorcier_entre), les deux
## autres sont SCELLÉES (sceller()) — objet retiré, entrée bloquée et
## porte refermée avec son animation. L'équivalent cabine de l'ancienne
## règle des bulles de verre (premier contact, autres condamnées).
##
## Règle globale de sortie : ON NE QUITTE PAS LA PIÈCE PENDANT UN
## RITUEL. La sortie est ouverte à l'arrivée (partir sans rien prendre
## reste permis), REFERMÉE dès qu'un rituel démarre, ROUVERTE quand le
## sorcier ressort (signal sorcier_sorti).

signal save_data


func _ready() -> void:
	# Spawn les joueurs via PlayerManager (joueurs figés au démarrage de
	# la partie : pas de nouveau joueur si une manette se branche ici)
	PlayerManager.spawn_all_players(self)
	# Mode boutique activé pour tous les joueurs de cette scène
	for controller_id in PlayerManager.active_player_ids():
		var player: Sorcerer = PlayerManager.players.get(controller_id)
		if player != null:
			player.in_shop = true
	$ShopDoor.play()
	# Cinématique d'arrivée par la porte d'entrée (dgel des joueurs à la
	# refermeture, cf. entry_door_cinematic.gd)
	var porte := _find_entry_door()
	if porte != null:
		porte.lancer_cinematique()
	# Les spawners internes des cabines ne se voient pas entre eux
	# (parents différents) : l'hôte fait respecter la règle « jamais deux
	# fois le même type » (cf. magasins intro).
	_coordonner_types_objets()
	# Règle « un seul objet par visite » : première entrée → autres scellées.
	# Règle de sortie : rituel en cours → sortie refermée ; sorcier ressorti
	# → sortie rouverte (une cabine scellée ne peut plus rien émettre).
	for cabine: Cabin in _cabines():
		cabine.sorcier_entre.connect(_on_cabine_entree.bind(cabine))
		cabine.sorcier_sorti.connect(_on_sorcier_sorti)


## Porte d'entrée cinématique de cette scène (une seule : 1 porte/couloir)
func _find_entry_door() -> EntryDoorCinematic:
	for child in get_children():
		if child is EntryDoorCinematic:
			return child
	return null


func goto_level():
	save_data.emit()
	Global.goto_scene(GlobalEnum.Location.LEVEL)

func _on_shop_door_shop_entered() -> void:
	goto_level()


## Les 3 cabines de la scène (noms Cabine, Cabine2, Cabine3).
func _cabines() -> Array[Cabin]:
	return [$Cabine, $Cabine2, $Cabine3]


## Un sorcier est entré dans `source` : les autres cabines (non occupées)
## sont scellées pour toute la visite, et la sortie se referme (règle :
## on ne quitte pas la pièce pendant un rituel).
func _on_cabine_entree(_sorcier: Sorcerer, source: Cabin) -> void:
	for cabine: Cabin in _cabines():
		if cabine != source:
			cabine.sceller()
	$ShopDoor.fermer()
	# Pas de désélection des tubes ici : le changement de scène (niveau
	# suivant) recrée des sorciers neufs de toute façon.


## Le sorcier a fini son rituel et ressorti : la sortie se rouvre.
func _on_sorcier_sorti(_sorcier: Sorcerer) -> void:
	$ShopDoor.play()


## Règle « jamais deux fois le même type » entre les 3 cabines : la
## cabine 0 garde son type, les suivantes re-tirent parmi les types
## restants. Un spawner re-tiré voit son objet déjà instancié (avec
## l'ANCIEN type et son sprite) éliminé à son entrée dans la CABINE, et
## un objet neuf respawné (spawn_object relit chosen_object_type) — même
## mécanique que les magasins intro. ATTENTION : les objets sont ajoutés
## au PARENT du spawner (la cabine), pas au spawner — c'est donc le
## signal de la CABINE qui les voit (brancher sur le spawner ne
## déclenche jamais rien).
func _coordonner_types_objets() -> void:
	var cabines := _cabines()
	var pris: Array = []
	for i in cabines.size():
		var cabine: Cabin = cabines[i]
		var spawner: Node = cabine.get_node("SpawnerObjet")
		if "chosen_object_type" not in spawner:
			return
		var type_courant: int = spawner.chosen_object_type
		if type_courant in pris:
			var libres: Array = spawner.PROPOSABLE_TYPES.filter(
				func(t: int) -> bool: return t not in pris)
			spawner.chosen_object_type = libres[randi() % libres.size()]
			cabine.child_entered_tree.connect(_on_objet_remplace.bind(cabine, spawner))
		pris.append(spawner.chosen_object_type)


## Le premier objet entrant dans une cabine re-tirée est l'ancien (type
## doublon) : éliminé, remplacé par un objet au type re-tiré. La cabine
## doit réadopter le suivant (objet pointait sur l'éliminé) : remis à
## null.
func _on_objet_remplace(child: Node, cabine: Cabin, spawner: Node) -> void:
	if not (child is AttackObject):
		return
	var callable: Callable = _on_objet_remplace.bind(cabine, spawner)
	if cabine.child_entered_tree.is_connected(callable):
		cabine.child_entered_tree.disconnect(callable)
	if cabine.objet == child:
		cabine.objet = null
	child.queue_free()
	spawner.spawn_object()
