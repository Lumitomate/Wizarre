extends Node2D

## Test headless de la force d'éjection des débris selon le tier de
## l'attaque fatale (lancer : godot --headless
## res://tests/test_death_burst_tier.tscn) :
##   - le tier 2 reproduit exactement les forces/quantités historiques ;
##   - les vitesses d'éjection suivent TIER_FORCE_MULT (×0.7/×1.0/×1.4) ;
##   - les quantités de débris suivent TIER_COUNT_MULT (×0.75/×1.0/×1.25) ;
##   - le tier remonte bien de hit() (et die()) jusqu'au burst.
## Conventions : EnemyDeathBurst règle tout ; les constantes de vitesse
## historiques sont CHUNK/BLOOD_SPEED_MIN/MAX (tier 2 = ×1.0).

var _failures := 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("OK: " + label)
	else:
		print("FAIL: " + label)
		_failures += 1


const BURST_SCENE := preload("res://scenes/objets/enemy_death_burst.tscn")


## Crée un burst avec un tier donné et des bornes de quantité fixées
## (min = max → nombre de débris déterministe), retourne-le (déjà dans
## l'arbre : _ready a spawné morceaux et sang)
func _creer_burst(tier: int, nb_morceaux: int, nb_sang: int) -> EnemyDeathBurst:
	var burst: EnemyDeathBurst = BURST_SCENE.instantiate()
	burst.attack_tier = tier
	burst.direction = Vector2.RIGHT
	burst.chunk_count_min = nb_morceaux
	burst.chunk_count_max = nb_morceaux
	burst.blood_count_min = nb_sang
	burst.blood_count_max = nb_sang
	add_child(burst)
	return burst


## Vitesses d'éjection des morceaux (px/s) d'un burst
func _vitesses_morceaux(burst: EnemyDeathBurst) -> Array[float]:
	var vitesses: Array[float] = []
	for piece in burst._pieces:
		if piece.is_chunk:
			vitesses.append(piece.body.velocity.length())
	return vitesses


func _ready() -> void:
	# --- Force et quantités par tier (10 morceaux, 40 gouttes en base) ---
	var burst_t1 := _creer_burst(1, 10, 40)
	var burst_t2 := _creer_burst(2, 10, 40)
	var burst_t3 := _creer_burst(3, 10, 40)

	# Quantités : ×0.75 / ×1.0 / ×1.25 sur une base de 10 (arrondi)
	var morceaux_t1 := _vitesses_morceaux(burst_t1).size()
	var morceaux_t2 := _vitesses_morceaux(burst_t2).size()
	var morceaux_t3 := _vitesses_morceaux(burst_t3).size()
	_check(morceaux_t1 == 8, "tier 1 : morceaux ×0.75 → 8 (10 en base, obtenu %d)" % morceaux_t1)
	_check(morceaux_t2 == 10, "tier 2 : morceaux ×1.0 → 10 (obtenu %d)" % morceaux_t2)
	_check(morceaux_t3 == 13, "tier 3 : morceaux ×1.25 → 13 (obtenu %d)" % morceaux_t3)

	# Force : chaque morceau dans la fenêtre de SON tier [min×force,
	# max×force] (240-640 px/s en base ×0.7/×1.0/×1.4)
	var f1: float = EnemyDeathBurst.TIER_FORCE_MULT[1]
	var f2: float = EnemyDeathBurst.TIER_FORCE_MULT[2]
	var f3: float = EnemyDeathBurst.TIER_FORCE_MULT[3]
	_check(f2 == 1.0, "tier 2 = force historique (×1.0)")
	var seuil_t3 := EnemyDeathBurst.CHUNK_SPEED_MIN * f3
	for v in _vitesses_morceaux(burst_t1):
		_check(v >= EnemyDeathBurst.CHUNK_SPEED_MIN * f1 - 0.01 \
			and v <= EnemyDeathBurst.CHUNK_SPEED_MAX * f1 + 0.01,
			"tier 1 : vitesse %.0f dans [%.0f..%.0f]" % [v, EnemyDeathBurst.CHUNK_SPEED_MIN * f1, EnemyDeathBurst.CHUNK_SPEED_MAX * f1])
	var au_dela_t2 := 0
	for v in _vitesses_morceaux(burst_t3):
		_check(v >= EnemyDeathBurst.CHUNK_SPEED_MIN * f3 - 0.01 \
			and v <= EnemyDeathBurst.CHUNK_SPEED_MAX * f3 + 0.01,
			"tier 3 : vitesse %.0f dans [%.0f..%.0f]" % [v, EnemyDeathBurst.CHUNK_SPEED_MIN * f3, EnemyDeathBurst.CHUNK_SPEED_MAX * f3])
		if v > EnemyDeathBurst.CHUNK_SPEED_MAX * f2:
			au_dela_t2 += 1
	# Dépassement du max tier 2 : statistique (fenêtres recouvrantes),
	# pas déterministe — on vérifie juste qu'AU MOINS UN morceau tier 3
	# dépasse le max tier 2 (probabilité de tous ≤ 640 : quasi nulle)
	_check(au_dela_t2 >= 1,
		"tier 3 : au moins un morceau dépasse le max tier 2 (%d/%d ≥ %.0f)" % [au_dela_t2, morceaux_t3, EnemyDeathBurst.CHUNK_SPEED_MAX * f2])

	# Propagation hit() → die() → burst : l'ennemi touché à la létalité
	# transmet le tier reçu jusqu'au EnemyDeathBurst créé (différé)
	var ennemi_scene: PackedScene = load("res://scenes/entities/ennemies/enemy_flying.tscn")
	var ennemi: EnemyFlying = ennemi_scene.instantiate()
	add_child(ennemi)
	ennemi.position = Vector2(200, 200)
	await get_tree().physics_frame
	# die() n'est appelé que sur lives == 0 : dégâts = vies restantes.
	# Position capturée AVANT le hit : die() libère l'ennemi (queue_free)
	var pos_ennemi := ennemi.position
	ennemi.hit(ennemi.lives, null, null, -1, 3)
	await get_tree().process_frame
	await get_tree().process_frame
	var bursts_restants: Array[Node] = get_children().filter(
		func(n: Node) -> bool: return n is EnemyDeathBurst)
	var trouve := false
	for b in bursts_restants:
		if b.position == pos_ennemi:
			_check(b.attack_tier == 3, "hit(tier 3) propagé jusqu'au burst (obtenu tier %d)" % b.attack_tier)
			trouve = true
	_check(trouve, "un burst a été spawné par die()")

	# Défaut sans tier : les morts sans tier connu (boss, contact…) restent
	# au comportement historique
	var burst_defaut := BURST_SCENE.instantiate()
	_check(burst_defaut.attack_tier == 2, "défaut du burst sans tier = 2 (historique)")

	print("RESULT: PASS" if _failures == 0 else "RESULT: FAIL (%d)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
