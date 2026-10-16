extends Node
## Test headless de l'onde d'arrivée d'objet (anneau radial style Dead
## Cells) : anneau PAS créé au départ du vol, créé à l'absorption
## (arrivée dans le tube), enfant du sac, couleur selon la famille de
## l'objet (P1 → vert), expansion en cours puis fondu terminé, et rien
## pour un sorcier frozen. Lancé comme scène :
## godot --headless res://tests/test_onde_tube.tscn

var step := 0
var sorcier: Sorcerer
var sac: SorcererSac
var objet: AttackObject


func _ready() -> void:
	var sorc_scene: PackedScene = load("res://scenes/entities/players/sorcerer.tscn")
	sorcier = sorc_scene.instantiate()
	sorcier.controller_id = 0
	sorcier.load_data()
	add_child(sorcier)
	sac = sorcier.get_node("SorcererSac")
	var obj_scene: PackedScene = load("res://scenes/objets/obj_p1_seeds.tscn")
	objet = obj_scene.instantiate()
	add_child(objet)
	objet.global_position = Vector2(300, 300)
	sorcier.global_position = Vector2(340, 300)
	sorcier.selected_tube = 0
	# Tubes vidés (load_data les remplit avec les sorts par défaut)
	sorcier.spells = {0: {}, 1: {}, 2: {}}


func _physics_process(_delta: float) -> void:
	step += 1
	if step == 3:
		# Contact simulé → vol d'absorption
		objet._on_body_entered(sorcier)
		print(">>> contact")
	if step == 30:
		# ~0.5s après le contact : le vol (0.6s) est ENCORE en cours,
		# l'onde ne doit PAS encore exister (elle part à l'absorption,
		# pas à l'attrapage)
		print("onde absente pendant le vol: ", sac._onde_arrivee == null, " (true attendu)")
	if step == 42:
		# ~0.7s après le contact : vol terminé (0.6s), absorption (0.05s)
		# démarrée → l'onde existe, enfant du sac, couleur famille P1,
		# en expansion (scale au-dessus de l'échelle de départ)
		var attendu: Color = WizardPalette.get_attack_family_color(GlobalEnum.AttackType.P1)
		print("onde créée à l'absorption: ", sac._onde_arrivee != null, " (true attendu)")
		print("onde enfant du sac: ", sac._onde_arrivee.get_parent() == sac, " (true attendu)")
		var c := sac._onde_arrivee.modulate
		print("onde couleur famille (vert plante): ",
			Color(c.r, c.g, c.b).is_equal_approx(attendu), " (true attendu)")
		print("onde en expansion: ",
			sac._onde_arrivee.scale.x > SorcererSac.ONDE_SCALE_DEPART, " (true attendu)")
		# Particules radiales : 3 à 5 éclats créés avec l'onde, encore vivants
		var particules := 0
		for enfant in sac.get_children():
			if enfant is Sprite2D and enfant.has_meta("onde_particule"):
				particules += 1
		print("particules radiales (3 à 5): ", particules,
			" (true attendu: ", particules >= 3 and particules <= 5, ")")
	if step == 62:
		# ~1s après le contact : onde terminée (durée 0.3s après
		# l'absorption ~0.65s) → alpha à 0, sprite conservé (réutilisable)
		print("onde terminée (alpha 0): ", sac._onde_arrivee.modulate.a == 0.0, " (true attendu)")
	if step == 64:
		# Sorcier d'affichage du pause (frozen) : aucune onde
		var sorc2_scene: PackedScene = load("res://scenes/entities/players/sorcerer.tscn")
		var sorcier2: Sorcerer = sorc2_scene.instantiate()
		sorcier2.controller_id = 0
		sorcier2.load_data()
		add_child(sorcier2)
		sorcier2.frozen = true
		var sac2: SorcererSac = sorcier2.get_node("SorcererSac")
		sac2.flasher_onde(0, GlobalEnum.AttackType.F1)
		print("onde en pause (frozen) bloquée: ", sac2._onde_arrivee == null, " (true attendu)")
		print("=== TEST TERMINÉ ===")
		get_tree().quit()