extends Node2D
## Magasin course à 2 joueurs : arrivée par les portes d'entrée (une par
## couloir), génération procédurale du layout des 2 couloirs (le MÊME
## layout pour les 2 joueurs), cabine (remplace la bulle de verre) qui
## contient l'objet, sortie par la ShopDoor.
##
## PORTE DE SORTIE : fermée à l'arrivée ; elle s'ouvre à la PREMIÈRE de
## ces deux échéances — fin du rituel de la cabine (attaque installée)
## ou fermeture TOTALE de la porte d'épreuve (elle a touché le sol).
## Si un retardataire a dashé sous la porte pendant la descente, elle ne
## se refermera jamais : la sortie attend alors la fin du rituel (le
## filet de sécurité ne joue que si personne n'entre jamais dans la
## cabine). Une fois ouverte, elle ne se referme jamais.
##
## Le layout est régénéré à CHAQUE arrivée dans la scène : faire un level et
## retomber sur ce magasin donne un parcours différent. La propriété
## layout_seed (exportée) permet de figer la génération pour la tester ;
## -1 = aléatoire.

signal save_data

## Nombre de portes d'entrée dont la cinématique n'est pas encore finie :
## le sablier démarre quand la dernière a terminé (tous les joueurs libres)
var _portes_entree_actives := 0

## La porte de sortie a été ouverte (une fois pour toutes).
var _sortie_ouverte := false

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
	# La porte de sortie reste FERMÉE à l'arrivée : elle s'ouvre à la
	# PREMIÈRE de ces deux échéances (règle validée avec le propriétaire) :
	#  - la fin du rituel de la cabine (sort_installe — l'attaque est
	#    installée, quelqu'un a gagné l'objet) ;
	#  - la fermeture TOTALE de la porte d'épreuve (signal fermee — elle
	#    a touché le sol sans qu'aucun passage ne l'ait déverrouillée).
	#    Un retardataire qui dash sous la porte pendant la descente la
	#    déverrouille pour de bon : elle ne se refermera jamais, et la
	#    sortie attendra la fin du rituel (cf. le filet de sécurité).
	$PorteMagasinEpreuve.fermee.connect(_essayer_ouvrir_sortie)
	# Filet de sécurité : armé à la fin du sablier (cf. _armer_filet_sortie).
	$Sablier.ecoulement_termine.connect(_armer_filet_sortie)
	# Le nœud de la cabine s'appelle "Bubble2" dans la scène (instance de
	# bubble_cabine.tscn, cf. CONTEXT.md : ne pas chercher "BubbleCabine").
	(get_node("Bubble2") as Cabin).sort_installe.connect(_essayer_ouvrir_sortie)
	# La rotation du sablier démarre avec l'ouverture des portes d'entrée
	$Sablier.demarrer_rotation()
	_generate_corridors()
	# L'objet est porté par la cabine (BubbleCabine), qui gère tout son rituel
	# d'entrée : plus de bulle à casser ici.
	# Cinématique d'arrivée : UNE porte par joueur (1 couloir chacun),
	# chaque porte lance sa propre séquence ; le dégel des joueurs se fait
	# à la refermeture de leur porte (cf. entry_door_cinematic.gd)
	for child in get_children():
		if child is EntryDoorCinematic:
			_portes_entree_actives += 1
			child.cinematique_terminee.connect(_on_porte_entree_terminee)
			child.lancer_cinematique()
	if _portes_entree_actives == 0:
		# Aucune porte d'entrée : le sablier démarre immédiatement
		$Sablier.demarrer()


## Une porte d'entrée a fini sa cinématique (porte refermée, joueur libéré).
## Quand la DERNIÈRE a terminé, tous les joueurs sont libres : le sablier
## démarre, et sa fin refermera la porte d'épreuve (connexion dans la scène).
func _on_porte_entree_terminee() -> void:
	_portes_entree_actives -= 1
	if _portes_entree_actives <= 0:
		$Sablier.demarrer()


## Filet de sécurité (ne devrait JAMAIS jouer en jeu normal) : la porte
## défi déverrouillée par un passage ne se refermera jamais ; si en plus
## personne n'entre jamais dans la cabine, la sortie resterait fermée
## pour toujours. Le filet l'ouvre après un long délai — JAMAIS pendant
## un rituel : cabine occupée à l'échéance → la fin du rituel ouvrira la
## sortie.
const DUREE_FILET := 10.0


func _armer_filet_sortie() -> void:
	if _sortie_ouverte:
		return
	get_tree().create_timer(DUREE_FILET).timeout.connect(func() -> void:
		if not _sortie_ouverte and not (get_node("Bubble2") as Cabin).est_occupee():
			_essayer_ouvrir_sortie())


## Ouvre la porte de sortie (première échéance : fin du rituel de la
## cabine, ou fermeture TOTALE de la porte d'épreuve — les deux
## événements sont connectés ici). Une fois ouverte, elle ne se referme
## pas. Les paramètres absorbent les 4 arguments du signal sort_installe
## (inutilisés ici).
func _essayer_ouvrir_sortie(_s: Sorcerer = null, _t: int = 0, _ty: int = 0,
		_ti: int = 0) -> void:
	if _sortie_ouverte:
		return
	_sortie_ouverte = true
	$ShopDoor.play()


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