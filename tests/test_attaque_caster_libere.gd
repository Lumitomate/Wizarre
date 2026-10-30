extends Node2D

## Test du fix du crash « hit » (à lancer avec
## tests/test_attaque_caster_libere.tscn). Une attaque dont le caster
## (sorcier) est mort pendant son vol ne doit PAS faire planter la
## machine au contact d'un ennemi — l'instance freed passée au paramètre
## Node2D `attacker` produisait « The object-derived class of argument 2
## is not a subclass of the expected argument class ».
##  1. EntityFinder.attaquant_valide : null → null ; instance vivante →
##     elle-même ; instance FREED → null (le cas du crash) ;
##  2. Boule de glace (G1) : caster mort pendant le vol → pas de crash,
##     l'ennemi perd bien sa vie ;
##  3. Projectile générique (F0 fireball, sous-classe d'AttackProjectile) ;
##  4. Boule de plante (P2) ;
##  5. Tête carnivore (P1) : proie tuée via die() avec caster freed.

var _failures := 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("OK: " + label)
	else:
		print("FAIL: " + label)
		_failures += 1


func _ready() -> void:
	await _test_helper()
	await _test_attaques_caster_libere()
	if _failures == 0:
		print("RESULT: PASS")
		get_tree().quit(0)
	else:
		print("RESULT: FAIL (%d)" % _failures)
		get_tree().quit(1)


## Ennemi prêt à prendre un coup (le parent Node2D de ce test lui sert
## de parent pour le label de dégâts). Position loin des attaques (0, 0)
## pour qu'aucun signal de contact automatique ne le touche : seuls les
## appels manuels de _on_body_entered comptent.
func _ennemi() -> EnemyFlying:
	var ennemi: EnemyFlying = load("res://scenes/entities/ennemies/enemy_flying.tscn").instantiate()
	ennemi.position = Vector2(3000, 0)
	add_child(ennemi)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return ennemi


## Sorcier « en jeu » (pas la scène complète : pas besoin de sac ni de
## sorts ici — le crash vient de l'instance freed, pas de son contenu).
func _sorcer() -> Sorcerer:
	return Sorcerer.new()


# --- 1. Le helper seul -------------------------------------------------
func _test_helper() -> void:
	_check(EntityFinder.attaquant_valide(null) == null, "helper : null → null")
	var vivant: Node2D = Node2D.new()
	_check(EntityFinder.attaquant_valide(vivant) == vivant, "helper : vivant → lui-même")
	# Cas du crash : instance freed passée au helper (paramètre Variant,
	# sinon le contrôle de type du paramètre plantait AVANT le helper)
	var freed: Sorcerer = _sorcer()
	freed.free()
	_check(EntityFinder.attaquant_valide(freed) == null,
		"helper : instance FREED → null (le cas du crash)")
	vivant.free()


# --- 2/3/4/5. Attaques dont le caster meurt pendant leur vol -----------
func _test_attaques_caster_libere() -> void:
	# 2. Boule de glace (G1) : caster assigné puis libéré (comme en jeu :
	# le sorcier meurt pendant que la boule vole encore)
	var caster := _sorcer()
	var glace: AttackIceBall = load("res://scenes/atk/atk_g1_ice_ball.tscn").instantiate()
	glace.caster = caster
	add_child(glace)
	caster.free()
	var ennemi := await _ennemi()
	var vies_avant := ennemi.lives
	glace._on_body_entered(ennemi)
	# Le volant peut être tué net (libéré) : dans les deux cas il a été
	# touché — et surtout : PAS de crash « Invalid type in function hit »
	_check(not is_instance_valid(ennemi) or ennemi.lives == vies_avant - 1,
		"boule de glace (caster freed) : ennemi touché, pas de crash")
	glace.free()

	# 3. Projectile générique (F0 fireball : sous-classe d'AttackProjectile)
	caster = _sorcer()
	var projectile: AttackProjectile = load("res://scenes/atk/atk_f0_fireball.tscn").instantiate()
	projectile.caster = caster
	add_child(projectile)
	caster.free()
	ennemi = await _ennemi()
	vies_avant = ennemi.lives
	projectile._on_body_entered(ennemi)
	_check(not is_instance_valid(ennemi) or ennemi.lives == vies_avant - 1,
		"projectile générique (caster freed) : ennemi touché, pas de crash")
	projectile.free()

	# 4. Boule de plante (P2)
	caster = _sorcer()
	var plante: AttackPlantBall = load("res://scenes/atk/atk_p2_explo.tscn").instantiate()
	plante.caster = caster
	add_child(plante)
	caster.free()
	ennemi = await _ennemi()
	vies_avant = ennemi.lives
	plante._on_explosion_body_entered(ennemi)
	_check(not is_instance_valid(ennemi) or ennemi.lives == vies_avant - 1,
		"boule de plante (caster freed) : ennemi touché, pas de crash")
	plante.free()

	# 5. Tête carnivore (P1) : proie tuée via die() avec caster freed
	caster = _sorcer()
	var tete: CarnivorousHead = load("res://scenes/atk/atk_p1_carnivorous_head.tscn").instantiate()
	tete.caster = caster
	add_child(tete)
	ennemi = await _ennemi()
	tete.target_enemy = ennemi
	tete._start_eating()
	caster.free()
	# La morsure part : on attend le frame fatal (bite_triggered)
	var t := 0.0
	while not tete.bite_triggered and t < 3.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	_check(tete.bite_triggered, "tête carnivore (caster freed) : morsure déclenchée")
	_check(not is_instance_valid(ennemi) or ennemi.lives <= 0,
		"tête carnivore (caster freed) : proie tuée, pas de crash")
	tete.free()
