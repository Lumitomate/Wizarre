extends Node
## Test headless de la ronce P3 multi-tiges : le budget TOTAL de tronçons
## est conservé (5 / 9 / 13) et réparti entre les tiges ; toutes les tiges
## partent de la même base, écartées par leurs PREMIERS tronçons ; au
## tier III les départs sont décalés (gauche → centre → droite) ; un
## contact ennemi ne décompose que la tige touchée. Lancé comme scène :
## godot --headless res://tests/test_ronces_tier.tscn

var step := 0
var ronce1: AttackPlantBramble  # tier I
var ronce2: AttackPlantBramble  # tier II
var ronce3: AttackPlantBramble  # tier III
var ronce_vola: AttackPlantBramble  # graine en vol (jamais plantée)


func _creer_ronce(tier: int, x: float) -> AttackPlantBramble:
	var scene: PackedScene = load("res://scenes/atk/atk_p3_plant_bramble.tscn")
	var bramble: AttackPlantBramble = scene.instantiate()
	bramble.attack_tier = tier
	add_child(bramble)
	bramble.global_position = Vector2(x, 418)
	bramble._plant()  # plantation directe (on saute le vol de la graine)
	return bramble


func _nb_segments(ronce: AttackPlantBramble) -> int:
	var total := 0
	for tige in ronce._tiges:
		total += tige.segments.size()
	return total


func _budgets(ronce: AttackPlantBramble) -> Array:
	var resultats: Array = []
	for tige in ronce._tiges:
		resultats.append(tige.budget)
	return resultats


func _delais(ronce: AttackPlantBramble) -> Array:
	var resultats: Array = []
	for tige in ronce._tiges:
		resultats.append(tige.start_delay)
	return resultats


func _angle_premier_troncon(tige) -> float:
	# Rotation du sprite du premier tronçon : angle + PI/2 (sprites verticaux)
	return tige.segments[0].rotation - PI / 2.0


func _ready() -> void:
	ronce1 = _creer_ronce(1, 100)
	ronce2 = _creer_ronce(2, 300)
	ronce3 = _creer_ronce(3, 500)
	# Graine en vol, jamais plantée : elle doit rester vivante (le bug
	# initial était un nettoyage armé pendant la phase FLYING)
	ronce_vola = _creer_ronce(1, 700)

	print("tier I : tiges = ", ronce1._tiges.size(), " (1 attendu), budgets = ",
		_budgets(ronce1), " ([5] attendu), délais = ", _delais(ronce1), " ([0] attendu)")
	print("tier II : tiges = ", ronce2._tiges.size(), " (2 attendu), budgets = ",
		_budgets(ronce2), " ([5, 4] attendu), délais = ", _delais(ronce2), " ([0, 0] attendu)")
	print("tier III : tiges = ", ronce3._tiges.size(), " (3 attendu), budgets = ",
		_budgets(ronce3), " ([4, 5, 4] attendu), délais = ", _delais(ronce3),
		" ([0, 0.15, 0.3] attendu)")


func _physics_process(_delta: float) -> void:
	step += 1
	if step == 39:
		# Éventail initial (vérifié AVANT le contact : les tronçons touchés
		# seront libérés après leur anim de décomposition)
		var ecart := deg_to_rad(25.0)
		var ok_ecart := true
		for tige_i in range(3):
			var angle := _angle_premier_troncon(ronce3._tiges[tige_i])
			var attendu: float = -PI / 2.0 + [-ecart, 0.0, ecart][tige_i]
			if not is_equal_approx(angle, attendu):
				ok_ecart = false
		print("éventail initial (−25°/0°/+25°) : ", ok_ecart, " (true attendu)")
	if step == 40:
		# ~0,66 s : le décalage du tier III est visible dans les comptes
		var g := ronce3._tiges[0].segments.size()
		var c := ronce3._tiges[1].segments.size()
		var d := ronce3._tiges[2].segments.size()
		print("tier III en croissance — gauche/centre/droite tronçons : ", g, "/", c, "/", d,
			" (droite < centre attendu : départ décalé)")
		print("décalage visible (droite < centre): ", d < c, " (true attendu)")
		# Contact ennemi sur le premier tronçon de la tige centrale (tier III)
		ronce3._on_enemy_touched(ronce3._tiges[1].segments[0])
		print(">>> contact ennemi sur la tige centrale")
	if step == 130:
		# La graine en vol a survécu au-delà du délai de nettoyage (1,5 s)
		print("graine en vol non libérée: ", is_instance_valid(ronce_vola), " (true attendu)")
		# ~2,2 s : les ronces sont complètes (tronçons de liaison inclus).
		# La tige centrale, touchée avant sa fin, reste à 4 tronçons sans
		# liaison : tier III = 5 + 4 + 5 = 14
		print("tier I complet : ", _nb_segments(ronce1), " tronçons (6 = 5 + liaison attendu)")
		print("tier II complet : ", _nb_segments(ronce2), " tronçons (11 = 9 + 2 liaisons attendu)")
		print("tier III complet : ", _nb_segments(ronce3), " tronçons (14 = 5 + 4 + 5, liaison supprimée sur la tige touchée)")
		# Contact ennemi : SEULE la tige centrale se décompose
		var centre := ronce3._tiges[1]
		var seg0_centre: AttackPlantBrambleSegment = centre.segments[0]
		var en_decomposition: bool = (not is_instance_valid(seg0_centre)) or seg0_centre._decomposing
		print("tige centrale en décomposition: ", en_decomposition, " (true attendu)")
		print("tige gauche vivante (Idle, pas décomposée): ",
			ronce3._tiges[0].segments[0].sprite.animation == &"Idle", " (true attendu)")
		print("tige droite vivante (Idle, pas décomposée): ",
			ronce3._tiges[2].segments[0].sprite.animation == &"Idle", " (true attendu)")
		print("tige centrale stoppée (pas de tronçon de liaison): ",
			not centre.connector_spawned, " (true attendu)")
		print("=== TEST TERMINÉ ===")
		get_tree().quit()