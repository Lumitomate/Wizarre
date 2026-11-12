extends Node
## Test headless du cycle complet « remontée puis nouvelle descente » de
## l'ascenseur de la homepage. Reproduit le signalement : le joueur quitte
## la cabine en bas, l'ascenseur remonte, puis redescend à la prochaine
## montée à bord. Deux variantes :
##  A — le joueur est resté DANS la zone de détection (elle est plus
##      large que la cabine) quand l'ascenseur revient en haut : la jauge
##      est déjà pleine, il faut quand même réarmer un départ.
##  B — le joueur était sorti de la zone et re-rentre ensuite : front
##      montant classique.
## Lancé comme scène : godot --headless res://tests/test_ascenseur_retour.tscn

var step := 0
var ascenseur: Node2D
var sorcier: Sorcerer
var echecs := 0


func _ready() -> void:
	var scene: PackedScene = load("res://scenes/niveaux/terrain1/map1_elevator.tscn")
	ascenseur = scene.instantiate()
	add_child(ascenseur)
	var sorc_scene: PackedScene = load("res://scenes/entities/players/sorcerer.tscn")
	sorcier = sorc_scene.instantiate()
	sorcier.controller_id = 0
	sorcier.load_data()
	add_child(sorcier)
	# Simule une manette connectée (cf. test_ascenseur.gd)
	PlayerManager.known_controllers.assign([0])


func etat() -> String:
	return str(ascenseur._etat)


func verifier(nom: String, ok: bool) -> void:
	if not ok:
		echecs += 1
	print(("OK   " if ok else "ÉCHEC ") + nom)


func remplir_jauge() -> void:
	ascenseur.animated_sprite_2D.frame = ascenseur.NUMBER_OF_FRAME_ELEVATOR
	ascenseur._on_animated_sprite_2d_frame_changed()


## Un cycle complet : embarquement, jauge pleine, descente, arrivée en
## bas, remontée (personne n'est parti), retour en haut.
func cycle_complet_avec_remontee() -> void:
	ascenseur._on_area_2d_body_entered(sorcier)
	remplir_jauge()  # → DESCENTE
	ascenseur._on_mouvement_termine(&"ascenseur_mouv_descente")  # → AU_BAS
	ascenseur._on_delai_grace_timeout()  # → REMONTEE
	ascenseur._on_mouvement_termine(&"ascenseur_mouv_descente")  # → EN_HAUT


func _physics_process(_delta: float) -> void:
	step += 1
	if step == 3:
		# Cycle 1 : monte, descend, remonte — le joueur ne quitte JAMAIS
		# la zone de détection (variante A : il est descendu de la cabine
		# mais reste à côté, dans la zone plus large que la cabine).
		cycle_complet_avec_remontee()
		verifier("cycle 1 : retour EN_HAUT après remontée", etat() == "0")
	if step == 5:
		# Variante A : jauge cible pleine (joueur détecté) → PAS de rebond
		# instantané (anti-boucle préservée) mais délai de grâce en haut
		# démarré ; à son échéance, redépart.
		var timer_haut: Timer = ascenseur.get_node("AnimatableBody2D/TimerHaut")
		verifier("variante A : pas de rebond instantané, grâce en haut démarrée",
			etat() == "0" and not timer_haut.is_stopped())
		ascenseur._on_delai_grace_haut_timeout()
		verifier("variante A : redépart après le délai de grâce en haut",
			etat() == "1")
	if step == 7:
		# Cycle 2 jusqu'à la remontée, puis le joueur QUITTE la zone en
		# bas (body_exited réel) avant la remontée.
		ascenseur._on_mouvement_termine(&"ascenseur_mouv_descente")  # → AU_BAS
		ascenseur._on_area_2d_body_exited(sorcier)  # sortie réelle, zone vide
		ascenseur._on_delai_grace_timeout()  # → REMONTEE
		ascenseur._on_mouvement_termine(&"ascenseur_mouv_descente")  # → EN_HAUT
		var timer_haut: Timer = ascenseur.get_node("AnimatableBody2D/TimerHaut")
		verifier("cycle 2 : retour EN_HAUT, zone vide, pas de grâce haute",
			etat() == "0" and timer_haut.is_stopped())
	if step == 9:
		# Variante B : le joueur re-rentre après la remontée → front
		# montant classique → descente.
		ascenseur._on_area_2d_body_entered(sorcier)
		remplir_jauge()
		verifier("variante B : redépart après sortie puis re-entrée", etat() == "1")
	if step == 11:
		if echecs == 0:
			print("RESULT: PASS")
		else:
			print("RESULT: FAIL (%d)" % echecs)
		get_tree().quit(0 if echecs == 0 else 1)
