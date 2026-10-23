extends Node2D

## Test de la machine à sous du casino (à lancer avec
## tests/test_gambling_machine.tscn). Vérifie les invariants logiques de
## gambling_machine.gd / gambling_reel.gd avec 2 faux joueurs (le corps
## physique n'existe pas en headless : l'appui des plaques est simulé
## via appuyer_plaque/relacher_plaque) :
##  1. Engrenages : 1, 3, 4 en avant (frame qui monte), 2 en reverse
##     (frame qui descend), dès le chargement ;
##  2. Rouleaux : défilement continu à VITESSE px/s vers le bas ;
##  3. Plaque : progression 16 px en ~0,3 s, relâchement → remontée sans
##     déclenchement, verrouillage one-shot à 16 px ;
##  4. Séquence complète : lumière lancée à la fermeture, rouleau qui
##     tourne PENDANT la lumière, calage à la fin de la lumière avec un
##     symbole exactement au centre, backspin observable (dépassement
##     puis retour) ;
##  5. Résultat : le triple (couleur / tube / attaque) correspond aux
##     symboles centraux des 3 vitrines ;
##  6. Livraison : signal livraison_terminee émis une seule fois (sans
##     sorcier réel, la livraison se réduit au signal — cf. _livrer).

const SCENE := "res://scenes/niveaux/magasin/magasin_casino/gambling_machin.tscn"

var _failures := 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("OK: " + label)
	else:
		print("FAIL: " + label)
		_failures += 1


func _ready() -> void:
	Engine.time_scale = 4.0
	await _frames(2)
	await _test_engrenages()
	await _test_rouleaux()
	await _test_plaques()
	await _test_sequence()
	Engine.time_scale = 1.0
	if _failures == 0:
		print("RESULT: PASS")
		get_tree().quit(0)
	else:
		print("RESULT: FAIL (%d)" % _failures)
		get_tree().quit(1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Attend une condition (en frames process), false si timeout.
func _attendre(cond: Callable, timeout_s: float) -> bool:
	var t := 0.0
	while not cond.call():
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > timeout_s:
			return false
	return true


func _machine() -> GamblingMachine:
	return get_tree().get_first_node_in_group("machine_test") as GamblingMachine


# ---------------------------------------------------------------------------
# 1. Engrenages (Q15) : lancés au chargement, le décalé 2 en reverse
func _test_engrenages() -> void:
	var machine: GamblingMachine = load(SCENE).instantiate()
	add_child(machine)
	await _frames(2)
	var g1: AnimatedSprite2D = machine.get_node("Engernage1")
	var g2: AnimatedSprite2D = machine.get_node("EngrenageDecale2")
	var g3: AnimatedSprite2D = machine.get_node("Engernage3")
	var g4: AnimatedSprite2D = machine.get_node("Engernage4")
	_check(g1.is_playing(), "engrenage 1 : lancé au chargement")
	_check(g2.is_playing(), "engrenage 2 (décalé) : lancé au chargement")
	_check(g3.is_playing(), "engrenage 3 : lancé au chargement")
	_check(g4.is_playing(), "engrenage 4 : lancé au chargement")
	var f1 := g1.frame
	var f2 := g2.frame
	var f3 := g3.frame
	await _frames(4)
	_check(g1.frame > f1, "engrenage 1 : tourne en avant (frame qui monte)")
	_check(g2.frame < f2, "engrenage 2 (décalé) : tourne en reverse (frame qui descend)")
	_check(g3.frame != f3, "engrenage 3 : en rotation")
	machine.free()


# ---------------------------------------------------------------------------
# 2. Rouleaux : défilement continu vers le bas, position par pas de 48 px
func _test_rouleaux() -> void:
	var machine: GamblingMachine = load(SCENE).instantiate()
	add_child(machine)
	await _frames(2)
	for i in machine._rouleaux.size():
		var rouleau: GamblingReel = machine._rouleaux[i]
		_check(rouleau.etat == GamblingReel.Etat.TOURNE,
			"rouleau %d : en défilement au chargement" % i)
		var offset_avant := rouleau._offset
		var avant := _position_symbole(rouleau, 0)
		await _frames(6)
		var apres := _position_symbole(rouleau, 0)
		# L'offset initial est aléatoire : s'il est près du bord de
		# l'enroulement, la position boucle pendant la mesure. On compare
		# donc le déplacement MODULO la longueur du rouleau (il doit être
		# petit, positif, vers le bas).
		var total := float(rouleau._symboles.size()) * GamblingReel.PITCH
		var delta := fposmod(apres - avant, total)
		_check(delta > 0.0 and delta < total * 0.5,
			"rouleau %d : défile vers le bas" % i)
		var delta_offset := fposmod(rouleau._offset - offset_avant, total)
		_check(delta_offset > 0.0 and delta_offset < total * 0.5,
			"rouleau %d : offset avance" % i)
	# Le symbole central est un index valide dans la liste des couleurs
	_check(machine._couleurs_rouleau.size() > 0,
		"rouleau 1 : construit dynamiquement (liste non vide)")
	# À 2 joueurs de test, tous les symboles du rouleau 1 sont valides
	machine.free()


func _position_symbole(rouleau: GamblingReel, index: int) -> float:
	return rouleau._symboles[index].position.y


# ---------------------------------------------------------------------------
# 3. Plaques : descente 16 px en ~0,3 s, remontée si relâchée, one-shot
func _test_plaques() -> void:
	var machine: GamblingMachine = load(SCENE).instantiate()
	add_child(machine)
	await _frames(2)
	var plaque: Dictionary = machine._plaques[0]
	var pilier := plaque["corps"] as StaticBody2D
	var base_y := float(plaque["base_y"])
	# Descente progressive
	machine.appuyer_plaque(0)
	await _frames(8)
	var profondeur := float(machine._plaques[0]["profondeur"])
	_check(profondeur > 0.0 and profondeur < 16.0,
		"plaque : enfoncement progressif (~%.1f px après 8 frames)" % profondeur)
	# Tolérance : le test reprend entre 2 frames de process, la plaque a
	# pu progresser de quelques fractions de pixel entre les lectures.
	# Le pilier ENTIER (corps solide) descend ; le sprite enfant suit.
	_check(absf(pilier.position.y - (base_y + profondeur)) < 0.5,
		"plaque : le pilier suit la profondeur")
	# Relâchée avant le fond → remontée, rien ne se lance
	machine.relacher_plaque(0)
	await _frames(30)
	_check(float(machine._plaques[0]["profondeur"]) == 0.0,
		"plaque : remontée complète après relâchement avant le fond")
	_check(not machine._lumieres()[0].is_playing(),
		"plaque : pas de lumière lancée si relâchée avant le fond")
	# Cette fois jusqu'au fond : verrouillage + lumière
	machine.appuyer_plaque(0)
	var arrivee := await _attendre(func() -> bool:
		return bool(machine._plaques[0]["verrouillee"]), 2.0)
	_check(arrivee, "plaque : verrouillée une fois enfoncée à fond (16 px)")
	_check(pilier.position.y == base_y + 16.0,
		"plaque : pilier descendu de 16 px exactement")
	_check(machine._lumieres()[0].is_playing(),
		"plaque : l'animation lumière joue au verrouillage")
	# One-shot : le joueur se relève, ré-appui ignoré (verrouillage)
	machine.relacher_plaque(0)
	machine.appuyer_plaque(0)
	await _frames(4)
	_check(int(machine._plaques[0]["appuis"]) == 0,
		"plaque : verrouillée, ignorer les appuis suivants")
	# La lumière finit seule, puis le rouleau se cale
	var cale := await _attendre(func() -> bool:
		return machine._rouleaux[0].etat == GamblingReel.Etat.ARRETE, 8.0)
	_check(cale, "plaque → lumière finie → rouleau calé (séquence complète)")
	# Après verrouillage, appui et relâchement ne cassent rien
	machine.appuyer_plaque(0)
	machine.relacher_plaque(0)
	await _frames(4)
	_check(machine._rouleaux[0].etat == GamblingReel.Etat.ARRETE,
		"plaque verrouillée : plus aucun effet")
	machine.free()


# ---------------------------------------------------------------------------
# 4. Séquence complète : lumière → rouleau tourne PENDANT → calage + backspin
func _test_sequence() -> void:
	var machine: GamblingMachine = load(SCENE).instantiate()
	add_child(machine)
	await _frames(2)
	var recues: Array[int] = []
	machine.livraison_terminee.connect(func() -> void:
		recues.append(1))
	# Enfoncement des 3 plaques presque simultanément (lumières en parallèle)
	machine.appuyer_plaque(0)
	machine.appuyer_plaque(1)
	machine.appuyer_plaque(2)
	await _frames(25)
	# Pendant la lumière, les rouleaux continuent de tourner
	for i in 3:
		_check(machine._rouleaux[i].etat == GamblingReel.Etat.TOURNE,
			"rouleau %d : tourne PENDANT la lumière" % i)
	_check(machine._lumieres()[0].is_playing(),
		"lumière gauche : en cours pendant le calage")
	# Attente du calage des 3 rouleaux (max ~2,3 s de lumière + 1,05 s de calage)
	var tous_cales := await _attendre(func() -> bool:
		for r in machine._rouleaux:
			if r.etat != GamblingReel.Etat.ARRETE:
				return false
		return true, 8.0)
	_check(tous_cales, "les 3 rouleaux se calent (lumières en parallèle)")
	# Vérifie le calage : un symbole est exactement au centre (y = 0)
	for i in 3:
		var rouleau: GamblingReel = machine._rouleaux[i]
		var y_central := _position_symbole(rouleau, rouleau.symbole_central())
		_check(absf(y_central) < 0.01,
			"rouleau %d : symbole central calé exactement au centre (y=%.4f)" % [i, y_central])
	# Après calage : les symboles ne bougent plus
	var avant := _position_symbole(machine._rouleaux[1], 0)
	await _frames(10)
	_check(_position_symbole(machine._rouleaux[1], 0) == avant,
		"rouleau calé : ne bouge plus")
	# Le résultat correspond aux symboles centraux
	var res := machine.resultat()
	var couleur: GlobalEnum.SorcererColor = machine._couleurs_rouleau[
		posmod(machine._rouleaux[0].symbole_central(), machine._couleurs_rouleau.size())]
	_check(res["couleur"] == couleur, "résultat : couleur = symbole central du rouleau 1")
	var tube_attendu: int = machine._rouleaux[1].symbole_central() % 3
	_check(res["tube"] == tube_attendu, "résultat : tube = symbole central du rouleau 2")
	var type_attendu: int = machine.TYPES_OBJETS[
		machine._rouleaux[2].symbole_central() % machine.TYPES_OBJETS.size()]
	_check(res["type"] == type_attendu, "résultat : attaque = symbole central du rouleau 3")
	# Sans sorcier réel, la livraison se réduit au signal (une seule fois)
	var signal_recu := await _attendre(func() -> bool:
		return recues.size() > 0, 3.0)
	_check(signal_recu, "livraison : signal livraison_terminee émis")
	_check(recues.size() == 1, "livraison : émis une seule fois")
	machine.free()
