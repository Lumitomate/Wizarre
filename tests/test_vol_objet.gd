extends Node
## Test headless du vol d'absorption des objets : au contact, signal
## attrapee émis IMMÉDIATEMENT, objet PAS encore libéré (il vole),
## rétrécissement en cours, sphère blanche créée ; à l'arrivée
## (~0,4 s + absorption), le sort est chargé dans le tube et l'objet
## libéré. Lancé comme scène : godot --headless res://tests/test_vol_objet.tscn
##
## NB historique : ce test se contentait d'IMPRIMER ses booléens, sans
## jamais échouer. Il affichait donc « false (true attendu) » en silence
## pendant que la prise d'objet était cassée — un test qui ne peut pas
## échouer ne teste rien. Il utilise maintenant le _check / RESULT commun.

var step := 0
var sorcier: Sorcerer
var objet: AttackObject
var attrapee_emise := false
var _failures := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: " + label)
	else:
		print("FAIL: " + label)
		_failures += 1


func _ready() -> void:
	# Sol sous le sorcier : sans lui, le CharacterBody2D tombe à l'infini
	# (le vol suit le sorcier en live, donc le test passait quand même —
	# mais il ne testait plus un sorcier debout). Surface à y = 332, soit
	# les pieds du sorcier (centre + 32) → il se tient à y = 300.
	var sol := StaticBody2D.new()
	sol.collision_layer = 1
	var forme := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 40)
	forme.shape = rect
	forme.position = Vector2(576, 352)
	sol.add_child(forme)
	add_child(sol)

	var sorc_scene: PackedScene = load("res://scenes/entities/players/sorcerer.tscn")
	sorcier = sorc_scene.instantiate()
	sorcier.controller_id = 0
	sorcier.load_data()
	add_child(sorcier)
	var obj_scene: PackedScene = load("res://scenes/objets/obj_p1_seeds.tscn")
	objet = obj_scene.instantiate()
	add_child(objet)
	objet.global_position = Vector2(300, 300)
	# CHEVAUCHEMENT RÉEL obligatoire : essayer_attraper() refuse l'objet si
	# overlaps_body(sorcier) est faux (règle de la relance à l'ouverture
	# d'un tube). Capsule du sorcier : 40 px de large (rayon 10 × échelle 2) ;
	# disque de l'objet : ~22 px. À 40 px d'écart il n'y avait AUCUN
	# chevauchement, donc aucune prise — c'est ce qui avait cassé le test.
	sorcier.global_position = Vector2(320, 300)
	sorcier.selected_tube = 0
	# Tubes vidés (load_data les remplit avec les sorts par défaut)
	sorcier.spells = {0: {}, 1: {}, 2: {}}
	objet.attrapee.connect(func(_s: Sorcerer) -> void: attrapee_emise = true)


func _physics_process(_delta: float) -> void:
	step += 1
	if step == 3:
		# Contact simulé (le chevauchement physique est établi depuis 3 pas)
		objet._on_body_entered(sorcier)
	if step == 4:
		_check(attrapee_emise, "attrapee émis au contact")
		_check(is_instance_valid(objet) and objet.is_inside_tree(),
			"objet encore en vol (pas libéré)")
		_check(objet._sphere != null, "sphère créée")
		_check(sorcier.spells[0].is_empty(), "sort PAS encore chargé")
	if step == 10:
		# ~0.12 s après le contact : rétrécissement en cours
		_check(is_instance_valid(objet), "objet toujours vivant pendant le vol")
		if not is_instance_valid(objet):
			_terminer()
			return
		_check(objet.scale.x < 1.0, "rétrécissement en cours")
		var sphere: Node2D = objet._sphere
		_check(sphere != null, "sphère toujours là pendant le fondu")
		if sphere != null:
			_check(sphere.modulate.a > 0.0, "sphère visible (fondu en cours)")
			# Sphère colorée : famille de l'objet (P1 → plante → vert), posée
			# sur le HALO (le cœur est blanc-brûlant)
			var attendu: Color = WizardPalette.get_attack_family_color(GlobalEnum.AttackType.P1)
			var halo: Sprite2D = sphere.get_node("Halo")
			var c := halo.modulate
			_check(Color(c.r, c.g, c.b).is_equal_approx(attendu),
				"sphère halo couleur élément (vert plante)")
			var coeur: Sprite2D = sphere.get_node("Coeur")
			_check(coeur.modulate == Color(1, 1, 1, 1)
				and coeur.material != null
				and (coeur.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD,
				"sphère cœur blanc-brûlant")
	if step == 50:
		# Après le contact : vol (0,6 s) + absorption (0,05 s) terminés. Marge
		# volontaire : mesuré libéré au pas 40, un pas de plus serait à la
		# limite du cycle des tweens.
		_check(not is_instance_valid(objet) or not objet.is_inside_tree(),
			"objet libéré après absorption")
		_check(sorcier.spells[0].get("attack_type", -1) == GlobalEnum.AttackType.P1,
			"sort chargé à l'arrivée (P1 dans tube 0)")
		_terminer()


func _terminer() -> void:
	if _failures == 0:
		print("RESULT: PASS")
		get_tree().quit(0)
	else:
		print("RESULT: FAIL (%d)" % _failures)
		get_tree().quit(1)
