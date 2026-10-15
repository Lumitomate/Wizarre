extends Node
## Test headless du vol d'absorption des objets : au contact, signal
## attrapee émis IMMÉDIATEMENT, objet PAS encore libéré (il vole),
## rétrécissement en cours, sphère blanche créée ; à l'arrivée
## (~0,4 s + absorption), le sort est chargé dans le tube et l'objet
## libéré. Lancé comme scène : godot --headless res://tests/test_vol_objet.tscn

var step := 0
var sorcier: Sorcerer
var objet: AttackObject
var attrapee_emise := false


func _ready() -> void:
	var sorc_scene: PackedScene = load("res://scenes/entities/players/sorcerer.tscn")
	sorcier = sorc_scene.instantiate()
	sorcier.controller_id = 0
	sorcier.load_data()
	add_child(sorcier)
	var obj_scene: PackedScene = load("res://scenes/objets/obj_p1_seeds.tscn")
	objet = obj_scene.instantiate()
	add_child(objet)
	objet.global_position = Vector2(300, 300)
	sorcier.global_position = Vector2(340, 300)
	sorcier.selected_tube = 0
	# Tubes vidés (load_data les remplit avec les sorts par défaut)
	sorcier.spells = {0: {}, 1: {}, 2: {}}
	objet.attrapee.connect(func(_s: Sorcerer) -> void: attrapee_emise = true)


func _physics_process(_delta: float) -> void:
	step += 1
	if step == 3:
		# Contact simulé
		objet._on_body_entered(sorcier)
		print(">>> contact")
	if step == 4:
		print("attrapee émis au contact: ", attrapee_emise, " (true attendu)")
		print("objet encore en vol (pas libéré): ", is_instance_valid(objet) and objet.is_inside_tree(),
			" (true attendu)")
		print("sphère créée: ", objet._sphere != null, " (true attendu)")
		print("sort PAS encore chargé: ", sorcier.spells[0].is_empty(), " (true attendu)")
	if step == 10:
		# ~0.12s après le contact : rétrécissement en cours
		print("rétrécissement en cours: ", objet.scale.x < 1.0, " (true attendu)")
		print("sphère visible (fondu en cours): ", objet._sphere.modulate.a > 0.0, " (true attendu)")
		# Sphère colorée : famille de l'objet (P1 → plante → vert)
		var attendu: Color = WizardPalette.get_attack_family_color(GlobalEnum.AttackType.P1)
		var c := objet._sphere.modulate
		print("sphère couleur élément (vert plante): ",
			Color(c.r, c.g, c.b).is_equal_approx(attendu), " (true attendu)")
	if step == 40:
		# ~0.6s après le contact : vol (0.4s) + absorption (0.05s) terminés
		print("objet libéré après absorption: ", not is_instance_valid(objet) or not objet.is_inside_tree(),
			" (true attendu)")
		print("sort chargé à l'arrivée (P1 dans tube 0): ",
			sorcier.spells[0].get("attack_type", -1) == GlobalEnum.AttackType.P1, " (true attendu)")
		print("=== TEST TERMINÉ ===")
		get_tree().quit()
