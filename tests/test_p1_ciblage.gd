extends Node2D

## Test headless du ciblage des têtes carnivores (P1) — régression du
## symptôme « un ennemi est passé à côté d'une tête sans être mangé ».
##
## Scénario A (2 têtes, tier II) : une tête LIBRE doit pouvoir cibler un
## ennemi même si une autre tête, plus proche, est occupée (en train de
## manger / déjà ciblée). Inversement, entre deux têtes libres, la plus
## proche reste prioritaire (comportement existant préservé).
##
## Scénario B (1 tête, tier I) : un ennemi entré dans la zone pendant que
## la tête était occupée doit être ciblé dès que la tête redevient
## libre — body_entered ne se redéclenche pas tout seul (événement au
## bord, pas à l'état).
##
## Lancé comme scène : godot --headless res://tests/test_p1_ciblage.tscn

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK: " + msg)
	else:
		print("FAIL: " + msg)
		failures += 1


func _ready() -> void:
	await _test_deux_tetes()
	await _test_reacquisition_zone()
	if failures == 0:
		print("RESULT: PASS")
		get_tree().quit(0)
	else:
		print("RESULT: FAIL (%d)" % failures)
		get_tree().quit(1)


## Plante une graine P2... non P1 — sans sol dessous : elle ne plante
## jamais, on appelle _setup_tier à la main pour obtenir ses têtes.
func _plante(tier: int, pos: Vector2) -> AttackCarnivorousSeed:
	var graine: AttackCarnivorousSeed = (load("res://scenes/atk/atk_p1_carnivorous_seed.tscn") as PackedScene).instantiate()
	graine.position = pos
	graine.attack_tier = tier
	add_child(graine)
	await get_tree().process_frame
	graine._setup_tier(tier)
	await get_tree().process_frame
	return graine


func _ennemi(pos: Vector2) -> EnemyFlying:
	var ennemi: EnemyFlying = (load("res://scenes/entities/ennemies/enemy_2lifes.tscn") as PackedScene).instantiate()
	ennemi.position = pos
	add_child(ennemi)
	await get_tree().process_frame
	return ennemi


# --- Scénario A : deux têtes, la plus proche est occupée ------------------
func _test_deux_tetes() -> void:
	var graine := await _plante(2, Vector2(400, 300))
	check(graine.heads.size() == 2, "tier II → 2 têtes (obtenu %d)" % graine.heads.size())
	var tete_a: CarnivorousHead = graine.heads[0]
	var tete_b: CarnivorousHead = graine.heads[1]
	var ennemi := await _ennemi(tete_a.head.global_position)

	# 1. Comportement préservé : A libre et plus proche → B s'efface.
	tete_b._on_area_2d_body_entered(ennemi)
	check(tete_b.target_enemy == null,
		"2 têtes libres : la plus proche (A) reste prioritaire, B s'efface")

	# 2. LE BUG : A est occupée (mange une autre proie) → elle ne peut pas
	#    prendre l'ennemi ; B, libre, doit prendre le relais même si A est
	#    plus proche. Avant correctif : B s'efface aussi → l'ennemi passe
	#    sans être mangé par QUI QUE CE SOIT.
	tete_a.is_eating = true
	tete_b._on_area_2d_body_entered(ennemi)
	check(tete_b.target_enemy == ennemi,
		"A occupée → B libre prend le relais (l'ennemi n'est plus ignoré)")

	ennemi.queue_free()
	graine.queue_free()
	await get_tree().process_frame


# --- Scénario B : ennemi déjà dans la zone quand la tête se libère --------
func _test_reacquisition_zone() -> void:
	var graine := await _plante(1, Vector2(800, 300))
	check(graine.heads.size() == 1, "tier I → 1 tête")
	var tete: CarnivorousHead = graine.heads[0]

	# La tête est occupée quand l'ennemi entre dans sa zone : le
	# body_entered est ignoré (comportement normal à cet instant).
	tete.is_eating = true
	var ennemi := await _ennemi(tete.head.global_position + Vector2(0, -10))
	# Laisser la physique enregistrer le chevauchement (et le body_entered
	# ignoré à cause de is_eating).
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(tete.target_enemy == null, "tête occupée : l'entrée dans la zone est ignorée")
	check(tete.detection_zone.get_overlapping_bodies().has(ennemi),
		"l'ennemi est bien DANS la zone de détection")

	# La morsure rate (proie partie) → la tête redevient disponible, avec
	# l'ennemi toujours dans la zone. Elle doit le cibler immédiatement.
	# La « proie partie » est simulée par une cible intouchable (classe
	# fantôme avec is_untouchable() → true) : un objet libéré ne passe pas
	# les paramètres typés de GDScript.
	var fuyard := Node2D.new()
	var script_fuyard := GDScript.new()
	script_fuyard.source_code = "extends Node2D\nfunc is_untouchable() -> bool:\n\treturn true\n"
	script_fuyard.reload()
	fuyard.set_script(script_fuyard)
	fuyard.add_to_group("player_group")
	fuyard.position = Vector2(5000, 5000)
	add_child(fuyard)
	tete.target_enemy = fuyard
	tete.head.frame_changed.connect(tete._on_bite_frame_changed)
	tete.head.animation = &"atk_p1_bite"
	tete.head.frame = tete.bite_kill_frame
	tete.bite_triggered = false
	tete._on_bite_frame_changed()
	check(not tete.is_eating, "morsure ratée : décrochage normal")
	# Laisser tourner la ré-acquisition (différée) puis vérifier.
	await get_tree().process_frame
	check(tete.target_enemy == ennemi,
		"tête redevenue libre → elle cible l'ennemi déjà dans sa zone")

	ennemi.queue_free()
	graine.queue_free()
	await get_tree().process_frame
