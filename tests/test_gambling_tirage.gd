extends Node2D

## Test du tirage optimisé de la machine à sous (à lancer avec
## tests/test_gambling_tirage.tscn). Complète test_gambling_machine.gd :
##  1. Tirage optimisé : l'objet livré n'est jamais possédé par le sorcier
##     tiré ; un sorcier avec le sac complet est écarté du tirage quand un
##     autre a un tube vide ;
##  2. Priorité globale : l'objet tiré n'est possédé par personne quand
##     c'est possible (c'est le cas dès qu'un sorcier a un tube vide) ;
##  3. Repli : quand tout est possédé (4×3=12), l'objet tiré n'est jamais
##     possédé par le sorcier ciblé ;
##  4. Forçage des rouleaux : chaque rouleau forcé se cale exactement sur
##     sa cible (symbole au centre), même lancé après les autres.

const SCENE := "res://scenes/niveaux/magasin/magasin_casino/gambling_machin.tscn"

var _failures := 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("OK: " + label)
	else:
		print("FAIL: " + label)
		_failures += 1


func _machine() -> GamblingMachine:
	return load(SCENE).instantiate() as GamblingMachine


func _configurer_rouleaux(machine: GamblingMachine) -> void:
	# La machine n'est pas dans l'arbre : _ready n'a pas tourné, on
	# construit les rouleaux à la main (3 tubes, 12 objets est inutile
	# ici — les tirages ne lisent que les listes de la machine)
	machine._rouleaux = [
		machine.get_node("SlotGauche/Vitrine/Rouleau") as GamblingReel,
		machine.get_node("SlotCentre/Vitrine/Rouleau") as GamblingReel,
		machine.get_node("SlotDroite/Vitrine/Rouleau") as GamblingReel,
	]
	var entrees_tuyaux: Array[Dictionary] = machine._entrees_tuyaux()
	for i in machine._rouleaux.size():
		# Même source de vérité que la machine : les entrées tuyaux
		# construites par _entrees_tuyaux (frame 1 des anims pleines)
		machine._rouleaux[i].configurer(entrees_tuyaux.duplicate(true))
	machine._couleurs_rouleau = [GlobalEnum.SorcererColor.Red, GlobalEnum.SorcererColor.Green]


func _ready() -> void:
	await _test_tirage_optimise()
	await _test_repli()
	await _test_forcage()
	if _failures == 0:
		print("RESULT: PASS")
		get_tree().quit(0)
	else:
		print("RESULT: FAIL (%d)" % _failures)
		get_tree().quit(1)


# --- 1+2. Tirage optimisé : s1 a un sort (F1), s2 a le sac vide -------
func _test_tirage_optimise() -> void:
	var machine := _machine()
	_configurer_rouleaux(machine)
	# s1 a le sac complet (3 tubes) : il est écarté du tirage tant que
	# s2 (sac vide) existe ; s2 reçoit toujours un objet « neuf »
	var s1 := Sorcerer.new()
	s1.sorcerer_color = GlobalEnum.SorcererColor.Red
	s1.spells = {0: {"attack_type": GlobalEnum.AttackType.F1, "attack_tier": 0},
		1: {"attack_type": GlobalEnum.AttackType.G1, "attack_tier": 0},
		2: {"attack_type": GlobalEnum.AttackType.L1, "attack_tier": 0}}
	var s2 := Sorcerer.new()
	s2.sorcerer_color = GlobalEnum.SorcererColor.Green
	s2.spells = {}
	var sorciers: Array[Sorcerer] = [s1, s2]
	var tirages_s2 := 0
	var objets_nouveaux := 0
	var echecs := 0
	for i in 1000:
		var sorcier := machine._tirer_sorcier(sorciers)
		var _tube := machine._tirer_tube(sorcier)
		var type = machine.TYPES_OBJETS[machine._tirer_type_index(sorcier, sorciers)]
		if machine._types_possedes(sorcier).has(type):
			echecs += 1
			print("FAIL: objet possédé par le sorcier tiré")
		if sorcier == s2:
			tirages_s2 += 1
		var possedes_tous := {}
		for s in sorciers:
			for t in machine._types_possedes(s):
				possedes_tous[t] = true
		if not possedes_tous.has(type):
			objets_nouveaux += 1
	print("INFO: s2 (sac vide) tiré %d/1000" % tirages_s2)
	print("INFO: objet que personne ne possède : %d/1000" % objets_nouveaux)
	_check(tirages_s2 == 1000, "tirage : priorité au sorcier avec tube vide")
	_check(objets_nouveaux == 1000, "tirage : objet que personne ne possède")
	_check(echecs == 0, "tirage : objet jamais possédé par le sorcier tiré")
	machine.free()


# --- 3. Repli : 4 sorciers × 3 tubes = 12 objets, tous possédés --------
func _test_repli() -> void:
	var machine := _machine()
	_configurer_rouleaux(machine)
	var s1 := Sorcerer.new()
	s1.sorcerer_color = GlobalEnum.SorcererColor.Red
	s1.spells = {0: {"attack_type": GlobalEnum.AttackType.P1, "attack_tier": 0},
		1: {"attack_type": GlobalEnum.AttackType.P2, "attack_tier": 0},
		2: {"attack_type": GlobalEnum.AttackType.P3, "attack_tier": 0}}
	var s2 := Sorcerer.new()
	s2.sorcerer_color = GlobalEnum.SorcererColor.Green
	s2.spells = {0: {"attack_type": GlobalEnum.AttackType.G3, "attack_tier": 0},
		1: {"attack_type": GlobalEnum.AttackType.L3, "attack_tier": 0},
		2: {"attack_type": GlobalEnum.AttackType.F1, "attack_tier": 0}}
	var s3 := Sorcerer.new()
	s3.sorcerer_color = GlobalEnum.SorcererColor.Blue
	s3.spells = {0: {"attack_type": GlobalEnum.AttackType.F2, "attack_tier": 0},
		1: {"attack_type": GlobalEnum.AttackType.G1, "attack_tier": 0},
		2: {"attack_type": GlobalEnum.AttackType.L1, "attack_tier": 0}}
	var s4 := Sorcerer.new()
	s4.sorcerer_color = GlobalEnum.SorcererColor.Yellow
	s4.spells = {0: {"attack_type": GlobalEnum.AttackType.F3, "attack_tier": 0},
		1: {"attack_type": GlobalEnum.AttackType.G2, "attack_tier": 0},
		2: {"attack_type": GlobalEnum.AttackType.L2, "attack_tier": 0}}
	var tous: Array[Sorcerer] = [s1, s2, s3, s4]
	var echecs := 0
	for i in 500:
		var sorcier := machine._tirer_sorcier(tous)
		var _tube := machine._tirer_tube(sorcier)
		var type = machine.TYPES_OBJETS[machine._tirer_type_index(sorcier, tous)]
		if machine._types_possedes(sorcier).has(type):
			echecs += 1
			print("FAIL: repli — objet possédé par le sorcier tiré")
	_check(echecs == 0, "repli : objet jamais possédé par le sorcier tiré")
	# Tous les sacs sont pleins : aucun tube vide n'est choisi
	var vide := false
	for i in 100:
		if machine._tube_est_vide(s1, machine._tirer_tube(s1)):
			vide = true
			break
	_check(not vide, "repli : sac plein → tube occupé (remplacement pur)")
	machine.free()


# --- 4. Forçage des rouleaux : cible exactement au centre --------------
func _test_forcage() -> void:
	var machine := _machine()
	# Dans l'arbre cette fois : le _ready tourne, puis _construire_rouleaux
	# (call_deferred) construit les VRAIS rouleaux (12 objets, 3 tubes,
	# couleurs sans joueurs) — on attend le différé
	add_child(machine)
	await get_tree().process_frame
	await get_tree().process_frame
	var echecs := 0
	for idx in 3:
		var r := machine._rouleaux[idx]
		var cible := (idx + 1) % r._symboles.size()
		r.forcer_cible(cible)
		r.lancer_calage()
		while r.etat != GamblingReel.Etat.ARRETE:
			await r.get_tree().process_frame
		if absf(r._symboles[cible].position.y) > 0.01:
			echecs += 1
			print("FAIL: rouleau forcé %d pas au centre (y=%.4f)" % [idx, r._symboles[cible].position.y])
	_check(echecs == 0, "forçage : les 3 rouleaux se calent sur leur cible")
	machine.free()
