extends Node2D
## Magasin réflexe à 3-4 joueurs : même pacte social que la version
## 2 joueurs (cf. shop_2players_reflex.gd pour le pipeline complet —
## double condition, accord entre joueurs, trahison possible), mais avec
## DEUX DISPOSITIFS indépendants (2× 2 plaques + 2 cabines). L'équipe se
## splitte en paires : chaque paire négocie SON accord, remplit SA double
## condition et gagne SA cabine (2 achats possibles pour 4 joueurs).
##
## DIFFÉRENCES AVEC LA VERSION 2 JOUEURS :
##  - la porte de sortie n'ouvre qu'après LES DEUX épreuves réussies ET
##    l'absence d'occupation dans TOUTES les cabines ; elle se referme
##    dès qu'UNE cabine est occupée, où que ce soit (cf. _maj_sortie) ;
##  - à 3 joueurs, les 2 épreuves restent faisables SÉQUENTIELLEMENT :
##    l'ouverture d'une cabine est one-shot, ses plaqueurs sont libérés
##    et vont compléter la 2e épreuve (2 plaqueurs suffisent par
##    épreuve). Rien à coder : c'est le comportement du dispositif.
##    (La trahison reste possible à tout moment, pacte ou pas.)
##
## SÉPARATION DES RÔLES : idem 2 joueurs — ce script ne gère que le spawn
## et la porte de sortie ; l'épreuve dans pressureplate_2players.gd, le
## rituel d'achat dans cabin.gd. Les dispositifs sont des instances de
## pressureplate_2players.tscn (chaque instance embarque sa cabine
## verrouillée « Cabine »).
##
## TEST : godot --headless res://tests/test_shop_4players_reflex.tscn
## (épreuve seule : tests/test_plaques_pression.tscn ; cabine seule :
## tests/test_cabine.tscn)

signal save_data

## Nombre d'épreuves réussies (une par dispositif).
var _epreuves_reussies := 0
## Nombre total d'épreuves (nombre de dispositifs câblés).
var _nb_epreuves := 0
## Porte de sortie actuellement ouverte.
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
	# Chaque dispositif signale la réussite de son épreuve
	for dispositif in _dispositifs():
		dispositif.epreuve_reussie.connect(_on_epreuve_reussie)
		_nb_epreuves += 1
	# La porte de sortie suit l'occupation des cabines (cf. _process)
	# Cinématique d'arrivée par la porte d'entrée (dgel des joueurs à la
	# refermeture, cf. entry_door_cinematic.gd)
	var porte := _find_entry_door()
	if porte != null:
		porte.lancer_cinematique()


## Les dispositifs d'épreuve de cette salle.
func _dispositifs() -> Array:
	return [$Pressureplate2Players, $Pressureplate2Players2]


## Les cabines des dispositifs (une par dispositif câblé).
func _cabines() -> Array[Cabin]:
	var cabines: Array[Cabin] = []
	for dispositif in _dispositifs():
		var cabine: Node = dispositif.get_node_or_null("Cabine")
		if cabine is Cabin:
			cabines.append(cabine)
	return cabines


func _on_epreuve_reussie() -> void:
	_epreuves_reussies += 1


func _process(_delta: float) -> void:
	_maj_sortie()


## La porte de sortie reste FERMÉE tant qu'une épreuve manque. Une fois
## TOUTES réussies : ouverte quand aucune cabine n'est occupée, refermée
## tant qu'un sorcier en occupe une — y compris pendant l'état DONE,
## quand le sorcier est encore dedans.
func _maj_sortie() -> void:
	if _epreuves_reussies < _nb_epreuves:
		return
	if _cabine_occupee():
		if _sortie_ouverte:
			_sortie_ouverte = false
			$ShopDoor.fermer()
	elif not _sortie_ouverte:
		_sortie_ouverte = true
		$ShopDoor.play()


func _cabine_occupee() -> bool:
	for cabine in _cabines():
		if cabine.est_occupee():
			return true
	return false


## Porte d'entrée cinématique de cette scène
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
