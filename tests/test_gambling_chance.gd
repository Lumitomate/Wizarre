extends Node2D

## Test de la chance dynamique de tirage aléatoire de la machine à sous
## (à lancer avec : godot --headless res://tests/test_gambling_chance.tscn).
## La fonction _chance_aleatoire_dynamique(sorciers) suit une courbe
## exponentielle (x²) selon le nombre de tubes occupés de tous les
## sorciers en jeu :
##  - sacs tous vides → chance de base (3 %) ;
##  - 1 tube libre sur tous les sacs → plafond (80 %) ;
##  - au-delà (tous les tubes occupés) → plafonnée au même 80 %.
## Les valeurs attendues sont calculées sur la formule exacte :
##   x = occupés / (total − 1), chance = 0.03 + 0.77 × x²
## Un mock Sorcerer (classe héritée) suffit : la machine ne lit que
## sorcier.spells (dictionnaire tube → sort).

const MACHINE := "res://scenes/niveaux/magasin/magasin_casino/gambling_machin.tscn"

var _failures := 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("OK: " + label)
	else:
		print("FAIL: " + label)
		_failures += 1


func _sorcier(occupes: int) -> Sorcerer:
	# Sorcerer.new() sans scène : aucune logique en _init, la machine ne
	# lit que spells (dictionnaire tube → sort, {} = tube vide)
	var s := Sorcerer.new()
	for i in range(3):
		if i < occupes:
			s.spells[i] = {"attack_type": 0, "attack_tier": 0}
		else:
			s.spells[i] = {}
	return s


func _sorciers(nb: int, occupes_chacun: int) -> Array[Sorcerer]:
	var liste: Array[Sorcerer] = []
	for i in range(nb):
		liste.append(_sorcier(occupes_chacun))
	return liste


func _machine() -> GamblingMachine:
	return load(MACHINE).instantiate() as GamblingMachine


func _test_courbe() -> void:
	var machine := _machine()

	# 4 joueurs, sacs tous vides (12 tubes, 0 occupé) → chance de base
	var chance := machine._chance_aleatoire_dynamique(_sorciers(4, 0))
	_check(absf(chance - 0.03) < 0.001,
		"sacs vides → chance de base: %.4f (0.03 attendu)" % chance)

	# 4 joueurs, 1 tube occupé (11 libres) → x = 1/11, x² ≈ 0.00826
	chance = machine._chance_aleatoire_dynamique(_sorciers_occupes(4, 1))
	_check(absf(chance - 0.0364) < 0.001,
		"1 tube occupé / 12 → début de courbe: %.4f (0.0364 attendu)" % chance)

	# 4 joueurs, 6 tubes occupés → x = 6/11, x² ≈ 0.2975
	chance = machine._chance_aleatoire_dynamique(_sorciers_occupes(4, 6))
	_check(absf(chance - 0.2591) < 0.001,
		"6 tubes occupés / 12 → mi-parcours: %.4f (0.2591 attendu)" % chance)

	# 4 joueurs, 11 tubes occupés (1 libre sur TOUS les sacs) → x = 1 → MAX
	chance = machine._chance_aleatoire_dynamique(_sorciers_occupes(4, 11))
	_check(absf(chance - 0.80) < 0.001,
		"1 tube libre / tous les sacs → plafond: %.4f (0.80 attendu)" % chance)

	# 4 joueurs, tous les tubes occupés (12/12) → plafonnée au même MAX
	chance = machine._chance_aleatoire_dynamique(_sorciers_occupes(4, 12))
	_check(absf(chance - 0.80) < 0.001,
		"sacs tous pleins → plafond inchangé: %.4f (0.80 attendu)" % chance)

	# 1 joueur, 2 tubes occupés (1 tube libre) → x = 2/2 → MAX
	chance = machine._chance_aleatoire_dynamique(_sorciers_occupes(1, 2))
	_check(absf(chance - 0.80) < 0.001,
		"1 joueur, 1 tube libre → plafond: %.4f (0.80 attendu)" % chance)

	# 1 joueur, 1 tube occupé (2 libres) → x = 0.5, x² = 0.25
	chance = machine._chance_aleatoire_dynamique(_sorciers_occupes(1, 1))
	_check(absf(chance - 0.2225) < 0.001,
		"1 joueur, 1 tube occupé → courbe douce: %.4f (0.2225 attendu)" % chance)


## Construit des sorciers avec exactement `occupes_totaux` tubes occupés,
## répartis au plus justement (les premiers sacs se remplissent d'abord).
func _sorciers_occupes(nb: int, occupes_totaux: int) -> Array[Sorcerer]:
	var liste: Array[Sorcerer] = []
	var restant := occupes_totaux
	for i in range(nb):
		var ici := clampi(restant, 0, 3)
		liste.append(_sorcier(ici))
		restant -= ici
	return liste


func _test_monotonie() -> void:
	var machine := _machine()
	# La chance ne doit JAMAIS diminuer quand l'occupation augmente
	var precedent := 0.0
	var croissante := true
	for occupes in range(0, 13):
		var chance := machine._chance_aleatoire_dynamique(_sorciers_occupes(4, occupes))
		if chance < precedent - 0.0001:
			croissante = false
			print("  ↓ régression à occupes=%d: %.4f < %.4f" % [occupes, chance, precedent])
		precedent = chance
	_check(croissante, "courbe monotone croissante sur les 13 valeurs d'occupation")


func _ready() -> void:
	_test_courbe()
	_test_monotonie()
	if _failures == 0:
		print("RESULT: PASS")
		get_tree().quit(0)
	else:
		print("RESULT: FAIL (%d)" % _failures)
		get_tree().quit(1)
