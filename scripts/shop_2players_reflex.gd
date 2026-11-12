extends Node2D
## Magasin réflexe à 2 joueurs : UNE DOUBLE CONDITION à remplir à deux
## pour accéder à l'objet — pas un défi d'adresse, un pacte à négocier.
##
## FONCTIONNEMENT D'ENSEMBLE — le pipeline complet de la salle :
##  1. ARRIVÉE : les joueurs arrivent par la porte d'entrée cinématique
##     (Terrain1PortesEntree, cf. entry_door_cinematic.gd : gel des
##     joueurs pendant la cinématique, dgel à la refermeture).
##  2. PACTE : les 2 plaques de pression se font FACE. Les 2 joueurs
##     doivent se mettre d'accord (qui aura l'objet ?), puis maintenir
##     chacun une plaque EN MÊME TEMPS. Les 2 animations d'énergie
##     doivent atteindre leur dernière frame pendant que les 2 plaques
##     sont tenues : c'est la double condition d'ouverture. Personne ne
##     peut l'ouvrir seul — il faut l'aval de l'autre joueur.
##  3. TRAHISON POSSIBLE : l'accord n'engage à rien. Cabine ouverte,
##     quiconque y entre le premier remporte l'achat — courir vers la
##     cabine malgré la décision prise reste toujours possible. Le
##     mécanisme ne juge pas : il n'offre que la possibilité du pacte,
##     et celle de le trahir.
##  4. ACHAT : le premier entrant déclenche le rituel complet (cf.
##     cabin.gd : porte refermée derrière lui, choix d'un tube, bras
##     robot installe le sort, portes rouvrent). La cabine est inerte
##     ensuite : un seul achat, jamais deux.
##  5. SORTIE : la porte de sortie (ShopDoor) est FERMÉE à l'arrivée et
##     suit l'occupation de la cabine (cf. _maj_sortie) : ouverte dès
##     l'épreuve réussie tant que la cabine est libre, REFERMÉE tant
##     qu'un sorcier l'occupe (est_occupee(), y compris l'état DONE),
##     rouverte à la fin du rituel. Traverser la zone de sortie →
##     shop_entered → goto_level().
##
## SÉPARATION DES RÔLES : ce script ne gère QUE le spawn des joueurs et la
## porte de sortie. L'épreuve vit dans pressureplate_2players.gd, le
## rituel d'achat dans cabin.gd — la scène est un simple assemblage de
## Pressureplate2Players (plaques + cabine verrouillée), de la porte de
## sortie et de la porte d'entrée.
##
## TEST : godot --headless res://tests/test_shop_2players_reflex.tscn
## (l'épreuve seule : tests/test_plaques_pression.tscn ; la cabine seule :
## tests/test_cabine.tscn)

signal save_data

## Épreuve des plaques réussie (la cabine est déverrouillée).
var _epreuve_reussie := false
## Porte de sortie actuellement ouverte (elle s'ouvre et se referme
## selon l'occupation de la cabine).
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
	# La porte de sortie suit l'occupation de la cabine (cf. _process)
	get_node("Pressureplate2Players").epreuve_reussie.connect(
		func() -> void: _epreuve_reussie = true)
	# Cinématique d'arrivée par la porte d'entrée (dgel des joueurs à la
	# refermeture, cf. entry_door_cinematic.gd)
	var porte := _find_entry_door()
	if porte != null:
		porte.lancer_cinematique()


## Porte d'entrée cinématique de cette scène
func _find_entry_door() -> EntryDoorCinematic:
	for child in get_children():
		if child is EntryDoorCinematic:
			return child
	return null


func goto_level():
	save_data.emit()
	Global.goto_scene(GlobalEnum.Location.LEVEL)


func _process(_delta: float) -> void:
	_maj_sortie()


## La porte de sortie reste FERMÉE tant que l'épreuve n'est pas réussie.
## Une fois réussie : ouverte quand la cabine est libre (personne n'y
## entre, ou rituel terminé), refermée tant qu'un sorcier l'occupe — y
## compris pendant l'état DONE, quand le sorcier est encore dedans.
func _maj_sortie() -> void:
	if not _epreuve_reussie:
		return
	var cabine: Cabin = get_node_or_null("Pressureplate2Players/Cabine")
	if cabine == null:
		return
	if cabine.est_occupee():
		if _sortie_ouverte:
			_sortie_ouverte = false
			$ShopDoor.fermer()
	elif not _sortie_ouverte:
		_sortie_ouverte = true
		$ShopDoor.play()


func _on_shop_door_shop_entered() -> void:
	goto_level()