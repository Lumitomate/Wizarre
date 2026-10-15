extends Node
## Test headless de l'« objet vivant » : lévitation (sinus vertical,
## phase fixée pour être déterministe), onde de chaleur (création,
## expansion), ébranlement au contact sans tube ouvert (recul puis
## retour élastique à zéro), et extinction de tout au moment de
## l'attrapage. Lancé comme scène :
## godot --headless res://tests/test_objet_vivant.tscn

var step := 0
var sorcier: Sorcerer
var objet: AttackObject
var base := Vector2.ZERO


func _ready() -> void:
	var sorc_scene: PackedScene = load("res://scenes/entities/players/sorcerer.tscn")
	sorcier = sorc_scene.instantiate()
	sorcier.controller_id = 0
	sorcier.load_data()
	sorcier.in_shop = true
	add_child(sorcier)
	var obj_scene: PackedScene = load("res://scenes/objets/obj_p1_seeds.tscn")
	objet = obj_scene.instantiate()
	objet.position = Vector2(300, 300)
	add_child(objet)
	# Phase fixée APRÈS add_child (le _ready de l'objet la randomise) :
	# offset maximal au démarrage, comportement déterministe
	objet._phase_levitation = PI / 2
	base = objet.position
	sorcier.global_position = objet.global_position + Vector2(-40, 0)


func _physics_process(_delta: float) -> void:
	step += 1
	if step == 5:
		# Lévitation : l'objet a quitté sa base verticalement (≤ amplitude)
		var ecart := objet.position.y - base.y
		print("lévitation: écart vertical ", ecart, " (~+4.8 attendu, phase fixée)")
		print("lévitation dans l'amplitude: ", ecart > 4.0 and ecart < 5.5, " (true attendu)")
		print("lévitation: pas de dérive horizontale ", absf(objet.position.x - base.x) < 0.01,
			" (true attendu)")
	if step == 8:
		# Onde de chaleur DÉSACTIVÉE (ONDE_ACTIVE = false) : jamais créée,
		# jamais visible (le shader reste de côté pour réactivation)
		print("onde désactivée (non créée): ", objet._onde == null, " (true attendu)")
	if step == 20:
		# Contact sans tube ouvert : ébranlement, PAS d'attrapage
		sorcier.selected_tube = -1
		objet._on_body_entered(sorcier)
		print(">>> contact sans tube ouvert")
	if step == 24:
		print("recul en cours (poussée): ", objet._recul.length() > 1.0, " (true attendu)")
		print("poussée opposée au joueur (vers +x): ", objet._recul.x > 0.0, " (true attendu)")
		print("objet toujours présent: ", is_instance_valid(objet), " (true attendu)")
	if step == 160:
		# Retour élastique terminé (0.13 + 2.1 s ≈ 134 frames)
		print("retour élastique terminé: ", objet._recul.length() < 0.01, " (true attendu)")
		print("recul horizontal nul: ", absf(objet.position.x - base.x) < 0.01, " (true attendu)")
	if step == 162:
		# Attrapage : tube ouvert → vol ; l'onde et l'ébranlement cessent
		sorcier.selected_tube = 0
		sorcier.spells = {0: {}, 1: {}, 2: {}}
		objet._on_body_entered(sorcier)
		print(">>> attrapage (tube ouvert)")
	if step == 166:
		print("onde éteinte au vol: ", objet._onde == null or not is_instance_valid(objet._onde),
			" (true attendu)")
		print("sphère du vol créée: ", objet._sphere != null, " (true attendu)")
		print("=== TEST TERMINÉ ===")
		get_tree().quit()
