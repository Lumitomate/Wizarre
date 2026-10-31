extends Node2D
## Régression : une plaque de pression qui s'enfonce PORTE le joueur.
##
## Un StaticBody2D déplacé ne porte PAS le CharacterBody2D debout dessus :
## le sorcier ne tient que grâce à floor_snap_length (1 px par pas de
## physique, cf. sorcerer.tscn). Dès qu'une plaque descend plus vite que
## ça — machine à sous : 16 px / 0,3 s = 1,78 px par pas dès que le jeu
## tourne à 30 fps — le sorcier perd le sol, `_physics_process` appelle
## set_state(FALL) (animation de chute parasite) et, `is_on_floor()` étant
## faux, un appui sur A ne déclenche plus de saut.
##
## Les 3 plaques du jeu sont donc des AnimatableBody2D (sync_to_physics,
## défaut), comme l'ascenseur de la homepage : le corps est déplacé DANS le
## pas de physique et le CharacterBody2D hérite de sa vitesse — le joueur
## descend AVEC la plaque.
##
## Le framerate est volontairement DÉGRADÉ (Engine.max_fps = 20) : à 60 fps
## le bug ne se voit pas (0,89 px par pas, juste sous la tolérance de
## 1 px). C'est précisément ce qui l'a rendu invisible si longtemps.
##
## Lancé comme scène :
## godot --headless res://tests/test_plaques_pression.tscn

const MACHINE := "res://scenes/niveaux/magasin/magasin_casino/gambling_machin.tscn"
const PLAQUE_GENERIQUE := "res://scenes/pressure_plate.tscn"
const PLAQUE_REFLEX := "res://scenes/niveaux/magasin/pressureplate_2players.tscn"
const SORCIER := "res://scenes/entities/players/sorcerer.tscn"

## Framerate dégradé : c'est là que le bug apparaissait.
const FPS_DEGRADE := 20
## Fenêtre de mesure, en pas de physique : couvre largement l'enfoncement
## le plus long (16 px en 0,3 s = 18 pas à 60 Hz).
const PAS_MESURE := 60
## Pieds du sorcier = centre + 32 px (capsule 10×30 décalée de (0,1),
## le tout à l'échelle 2 — cf. sorcerer.tscn)
const PIEDS := 32.0

var _failures := 0
var sorcier: Sorcerer


func _check(ok: bool, label: String) -> void:
	if ok:
		print("OK: " + label)
	else:
		print("FAIL: " + label)
		_failures += 1


## Sorcier réel (mêmes réglages que la scène), posé à `position_depart` :
## le CENTRE du corps, pas les pieds.
func _poser_sorcier(position_depart: Vector2) -> void:
	sorcier = load(SORCIER).instantiate()
	sorcier.controller_id = 0
	sorcier.load_data()
	sorcier.input_device = 100
	add_child(sorcier)
	sorcier.global_position = position_depart
	sorcier.velocity = Vector2.ZERO
	# Deux pas de physique : le temps de se poser et d'être vu au sol
	await get_tree().physics_frame
	await get_tree().physics_frame


func _ranger() -> void:
	sorcier.queue_free()
	sorcier = null
	await get_tree().physics_frame


## Déclenche l'appui (`declencher`), puis mesure pendant PAS_MESURE pas :
## le sorcier ne doit JAMAIS quitter le sol, JAMAIS jouer « fall », et
## doit descendre de `course` px — AVEC la plaque.
func _mesurer(label: String, declencher: Callable, course: float) -> void:
	# Référence AVANT le déclenchement : les plaques sont des
	# AnimatableBody2D animés au pas de physique (tween en
	# TWEEN_PROCESS_PHYSICS, _physics_process) — le sorcier est porté dès
	# le pas suivant, donc toute attente après le déclenchement
	# rognerait la course mesurée.
	var y_debut := sorcier.position.y
	declencher.call()
	var pas_en_l_air := 0
	var frames_de_chute := 0
	for i in PAS_MESURE:
		if not sorcier.is_on_floor():
			pas_en_l_air += 1
		if sorcier.get_node("AnimatedSprite2D").animation == "fall":
			frames_de_chute += 1
		await get_tree().physics_frame
	var descente := sorcier.position.y - y_debut
	_check(pas_en_l_air == 0,
		"%s : ne quitte jamais le sol (%d pas en l'air)" % [label, pas_en_l_air])
	_check(frames_de_chute == 0,
		"%s : jamais l'animation de chute (%d frames)" % [label, frames_de_chute])
	# Garde-fou : si la plaque ne bougeait pas, les 2 checks ci-dessus
	# passeraient pour de mauvaises raisons.
	_check(absf(descente - course) < 1.0,
		"%s : descend AVEC la plaque (%.1f px, attendu %.1f)" % [label, descente, course])


## Machine à sous : les 3 piliers s'enfoncent de 16 px.
func _cas_machine() -> void:
	var machine: GamblingMachine = load(MACHINE).instantiate()
	add_child(machine)
	await get_tree().physics_frame
	# Haut du pilier central non enfoncé : 194 − 48/2 = 170 → centre 138
	await _poser_sorcier(Vector2(0, 170.0 - PIEDS))
	_check(sorcier.is_on_floor(), "machine à sous : le sorcier est posé sur le pilier central")
	# Index 1 = pilier central (même point d'entrée que le body_entered de
	# la ZoneDetection, cf. test_gambling_physique)
	await _mesurer("machine à sous (16 px)",
		func() -> void: machine.appuyer_plaque(1), 16.0)
	await _ranger()
	machine.queue_free()
	await get_tree().physics_frame


## Plaque générique (magasin des mains) : bouton de 4 px.
func _cas_plaque_generique() -> void:
	var plaque: PressurePlate = load(PLAQUE_GENERIQUE).instantiate()
	add_child(plaque)
	await get_tree().physics_frame
	# Haut du bouton non enfoncé : 0 − 16/2 = −8 → centre −40
	await _poser_sorcier(Vector2(0, -8.0 - PIEDS))
	_check(sorcier.is_on_floor(), "plaque générique : le sorcier est posé sur le bouton")
	# Même point d'entrée que la TriggerArea (le bandeau de détection fait
	# 1 px de haut : le test vise le PORTAGE, pas la détection)
	await _mesurer("plaque générique (4 px)",
		func() -> void: plaque._on_body_entered(sorcier), 4.0)
	await _ranger()
	plaque.queue_free()
	await get_tree().physics_frame


## Plaques réflexes à 2 joueurs (magasin de réflexe) : 4 px chacune.
func _cas_plaque_reflex() -> void:
	var reflex: Node2D = load(PLAQUE_REFLEX).instantiate()
	add_child(reflex)
	await get_tree().physics_frame
	# PlateLeft à (−64,−3), collision en (0,−6) de 32×4 → haut à −11
	await _poser_sorcier(Vector2(-64, -11.0 - PIEDS))
	_check(sorcier.is_on_floor(), "plaque réflexe : le sorcier est posé sur la plaque gauche")
	await _mesurer("plaque réflexe gauche (4 px)",
		func() -> void: reflex._on_plate_body_entered(sorcier, "left"), 4.0)
	await _ranger()
	reflex.queue_free()
	await get_tree().physics_frame


func _ready() -> void:
	Engine.max_fps = FPS_DEGRADE
	print("framerate dégradé à %d fps (physique à %d Hz) — condition du bug"
		% [FPS_DEGRADE, Engine.physics_ticks_per_second])

	await _cas_machine()
	await _cas_plaque_generique()
	await _cas_plaque_reflex()

	if _failures == 0:
		print("RESULT: PASS")
		get_tree().quit(0)
	else:
		print("RESULT: FAIL (%d)" % _failures)
		get_tree().quit(1)
