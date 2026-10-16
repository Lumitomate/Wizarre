extends Node
## Test headless du squash & stretch : les effets déforment le SPRITE
## autour des pieds, JAMAIS le CharacterBody2D (contrainte d'or : scale
## du body inchangé et position intacte). Les courbes sont appelées
## directement (déterministe — les tweens avancent en temps réel, pas
## au rythme des steps de physique headless) ; le déclenchement RÉEL du
## squash à l'atterrissage physique est vérifié par polling. Lancé comme
## scène : godot --headless res://tests/test_squash_stretch.tscn

var step := 0
var phase := 0
var sorcier: Sorcerer
var sprite: AnimatedSprite2D
var body_pos_avant: Vector2
var body_scale_avant: Vector2


func _verifier_body() -> void:
	var intact := sorcier.scale == body_scale_avant \
		and sorcier.global_position == body_pos_avant
	print("body intact (scale et position inchangés): ", intact, " (true attendu)")


func _ready() -> void:
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
	# Posé au sol (pieds = centre + 32 px, surface à y = 450)
	sorcier.global_position = Vector2(300, 418)
	sorcier.frozen = true  # physique court-circuitée : courbes pilotées à la main
	sprite = sorcier.get_node("AnimatedSprite2D")
	body_pos_avant = sorcier.global_position
	body_scale_avant = sorcier.scale  # (2, 2) par conception de la scène


func _physics_process(_delta: float) -> void:
	step += 1
	match phase:
		0:
			if step == 2:
				print(">>> anticipation (courbe à t=0.2 : phase de compression)")
				sorcier._appliquer_anticipation(0.2)
				print("anticipation compressée (scale.y < 0.97): ", sprite.scale.y < 0.97, " (true attendu)")
				print("anticipation élargie (scale.x > 1.03): ", sprite.scale.x > 1.03, " (true attendu)")
				_verifier_body()
				phase = 1
		1:
			if step == 3:
				sorcier._appliquer_anticipation(1.0)
				print("anticipation retombée (scale ~1): ",
					absf(sprite.scale.x - 1.0) < 0.02 and absf(sprite.scale.y - 1.0) < 0.02,
					" (true attendu)")
				phase = 2
		2:
			if step == 4:
				# Stretch : montée à vitesse max → étiré verticalement,
				# rétréci horizontalement
				sorcier.velocity = Vector2(0, -sorcier.stretch_vitesse_max)
				sorcier._update_effets_visuels(1.0 / 60.0)
				print("stretch en montée (scale.y > 1.05): ", sprite.scale.y > 1.05, " (true attendu)")
				print("stretch affiné (scale.x < 1): ", sprite.scale.x < 1.0, " (true attendu)")
				_verifier_body()
				phase = 3
		3:
			if step == 5:
				# Inclinaison : course à pleine vitesse vers la droite
				sorcier.velocity = Vector2(400, 0)
				sorcier._update_effets_visuels(1.0)
				print("inclinaison vers la droite (rotation > 0.05 rad): ",
					sprite.rotation > 0.05, " (true attendu)")
				phase = 4
		4:
			if step == 6:
				# Arrêt : retour doux à 0°
				sorcier.velocity = Vector2.ZERO
				sorcier._update_effets_visuels(1.0)
				print("inclinaison retombée à 0 (rotation ~0): ",
					absf(sprite.rotation) < 0.01, " (true attendu)")
				phase = 5
		5:
			if step == 7:
				print(">>> squash d'atterrissage (courbe à t=0.3 : tenue pleine)")
				sorcier._appliquer_squash_atterrissage(0.3, 1.0)
				print("squash d'impact (scale.y < 0.98): ", sprite.scale.y < 0.98, " (true attendu)")
				print("squash élargi (scale.x > 1.02): ", sprite.scale.x > 1.02, " (true attendu)")
				_verifier_body()
				phase = 6
		6:
			if step == 8:
				sorcier._appliquer_squash_atterrissage(1.0, 1.0)
				print("squash retombé (scale ~1): ",
					absf(sprite.scale.x - 1.0) < 0.02 and absf(sprite.scale.y - 1.0) < 0.02,
					" (true attendu)")
				phase = 7
		7:
			if step == 9:
				# Atterrissage RÉEL : la physique reprend, chute de 100 px,
				# le tween de squash doit se déclencher tout seul
				print(">>> atterrissage réel (chute 100 px)")
				sorcier.velocity = Vector2.ZERO
				sorcier.frozen = false
				sorcier.global_position = Vector2(300, 318)
				phase = 8
				step = 0
		8:
			if step > 5 and sprite.scale.y < 0.98:
				print("squash déclenché par l'atterrissage physique: ",
					sprite.scale.y < 0.98, " (true attendu)")
				# Ici le body a légitimement bougé (chute = gameplay) :
				# l'invariant ne porte que sur le scale, jamais modifié
				print("body scale intact: ", sorcier.scale == body_scale_avant, " (true attendu)")
				print("=== TEST TERMINÉ ===")
				get_tree().quit()
			elif step > 300:
				print("ÉCHEC: pas de squash à l'atterrissage réel")
				get_tree().quit()