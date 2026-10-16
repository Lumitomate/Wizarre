extends Node
## Test headless de la fumée de contact : chute RÉELLE du sorcier sur un
## sol factice → bouffée à l'atterrissage ; modulation par la vitesse
## (grande chute → plus de particules que petite chute) ; seuil (force
## sous POUSSIERE_SEUIL_VITESSE → rien) ; force max → le quota complet.
## Lancé comme scène : godot --headless res://tests/test_poussiere.tscn

var step := 0
var phase := 0
var sorcier: Sorcerer
var compte_chute_courte := 0
var compte_chute_longue := 0


func _compter_particules() -> int:
	# Les particules sont attachées au niveau (parent du sorcier) : la
	# fumée reste à l'endroit du contact au lieu de suivre le sorcier
	var nombre := 0
	for enfant in sorcier.get_parent().get_children():
		if enfant is Sprite2D and enfant.has_meta("poussiere"):
			nombre += 1
	return nombre


func _premiere_particule() -> Sprite2D:
	for enfant in sorcier.get_parent().get_children():
		if enfant is Sprite2D and enfant.has_meta("poussiere"):
			return enfant
	return null


func _ready() -> void:
	# Sol factice : couche 1 (lue par le masque de collision du sorcier),
	# 600 px de large, 100 px d'épaisseur — haut de la surface à y = 450
	var sol := StaticBody2D.new()
	sol.collision_layer = 1
	var forme := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(600, 100)
	forme.shape = rectangle
	sol.add_child(forme)
	sol.position = Vector2(300, 500)
	add_child(sol)
	var scene: PackedScene = load("res://scenes/entities/players/sorcerer.tscn")
	sorcier = scene.instantiate()
	sorcier.controller_id = 0
	sorcier.load_data()
	add_child(sorcier)
	# Le sorcier repose à y = 418 (pieds = centre + 32 px, capsule ×2).
	# Chute 1 : 40 px → vitesse ~490 px/s, juste au-dessus du seuil (400)
	sorcier.global_position = Vector2(300, 378)


func _physics_process(_delta: float) -> void:
	step += 1
	match phase:
		0:
			# Chute courte : on attend les premières particules de fumée
			if step > 5 and _compter_particules() > 0:
				compte_chute_courte = _compter_particules()
				print("fumée à l'atterrissage (chute 40 px): ",
					compte_chute_courte, " particules (>0 attendu)")
				phase = 1
				step = 0
			elif step > 300:
				print("ÉCHEC: aucune fumée à l'atterrissage")
				get_tree().quit()
		1:
			if step == 5:
				# La fumée est fixée au monde : les particules ne doivent PAS
				# être enfants du sorcier (sinon elles colleraient à ses pieds)
				var particule := _premiere_particule()
				print("fumée attachée au niveau, pas au sorcier: ",
					particule != null and particule.get_parent() != sorcier, " (true attendu)")
			# Laisser les particules de la chute 1 mourir (durée 0.35s ~ 21 frames)
			if step > 40:
				# Chute 2 : 400 px → vitesse ~1550 px/s, force maximale
				sorcier.global_position = Vector2(300, 18)
				print(">>> remonté pour la grande chute")
				phase = 2
				step = 0
		2:
			if step > 5 and _compter_particules() > 0:
				compte_chute_longue = _compter_particules()
				print("fumée grande chute (400 px): ", compte_chute_longue, " particules")
				print("modulation par la vitesse (longue ≥ courte): ",
					compte_chute_longue >= compte_chute_courte, " (true attendu)")
				# Seuil : juste en dessous → aucune particule de plus
				var base := _compter_particules()
				sorcier.spawn_poussiere(sorcier.global_position, Vector2.UP,
					Sorcerer.POUSSIERE_SEUIL_VITESSE - 1.0)
				print("seuil respecté (rien sous 400 px/s): ",
					_compter_particules() == base, " (true attendu)")
				# Force maximale → le quota complet de particules
				sorcier.spawn_poussiere(sorcier.global_position, Vector2.UP,
					Sorcerer.POUSSIERE_VITESSE_MAX)
				var apres := _compter_particules() - base
				print("force max → ", apres, " particules (",
					Sorcerer.POUSSIERE_FORCE_MAX, " attendu)")
				print("=== TEST TERMINÉ ===")
				get_tree().quit()
			elif step > 300:
				print("ÉCHEC: pas de fumée à la grande chute")
				get_tree().quit()