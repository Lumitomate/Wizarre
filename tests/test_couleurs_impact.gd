extends Node2D

## Test headless de la couleur d'impact par ÉLÉMENT pour chaque attaque
## (régression : « l'explosion verte est toujours rouge, la bleue
## fonctionne »). Pour chaque famille, on obtient un nœud d'attaque RÉEL
## et on vérifie que ImpactExplosion.couleur_impact rend la bonne rampe :
## un sous-nœud peut porter le coup à la place de son attaque (ex :
## AttackPlantBrambleSegment, enfant de AttackPlantBramble, absent du
## REGISTRE) — la couleur doit remonter à l'attaque parente.
## Lancé comme scène : godot --headless res://tests/test_couleurs_impact.tscn

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK: " + msg)
	else:
		print("FAIL: " + msg)
		failures += 1


func _ready() -> void:
	# Glace G1 : le projectile lui-même porte le coup (script dans REGISTRE)
	await _coul(GlobalEnum.AttackType.G1, Color("00a8e0"),
		"glace G1 → rampe bleue", true)
	# Plante P3 : le coup est porté par un TRONÇON (AttackPlantBrambleSegment),
	# PAS par l'attaque inscrite au REGISTRE (AttackPlantBramble) — la
	# recherche doit remonter au parent pour trouver la rampe verte.
	await _coul_p3()

	if failures == 0:
		print("RESULT: PASS")
		get_tree().quit(0)
	else:
		print("RESULT: FAIL (%d)" % failures)
		get_tree().quit(1)


## Spawn une attaque réelle et vérifie la rampe déduite d'un de ses nœuds.
func _coul(type: GlobalEnum.AttackType, couleur_sombre: Color, msg: String,
		noeud_attaque_direct: bool) -> void:
	var noeuds := AttackSpawner.spawn_attack(type, GlobalEnum.AttackTier.I,
		Vector2(3000, 3000), Vector2.RIGHT, Vector2(1280, 720), Vector2.ONE, null)
	check(noeuds.size() > 0, "spawn %s produit un nœud" % GlobalEnum.AttackType.keys()[type])
	if noeuds.is_empty():
		return
	var cible: Node = noeuds[0] if noeud_attaque_direct else noeuds[noeuds.size() - 1]
	var rampe := ImpactExplosion.couleur_impact(cible)
	check(rampe[0] == couleur_sombre, msg)
	for n in noeuds:
		n.free()


## P3 : graine plantée sur un sol factice, puis un tronçon réel.
func _coul_p3() -> void:
	var sol := StaticBody2D.new()
	sol.collision_layer = 8
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 40)
	cs.shape = rect
	sol.add_child(cs)
	sol.position = Vector2(300, 400)
	add_child(sol)

	var noeuds := AttackSpawner.spawn_attack(GlobalEnum.AttackType.P3,
		GlobalEnum.AttackTier.I, Vector2(300, 300), Vector2.RIGHT,
		Vector2(1280, 720), Vector2.ONE, null)
	if noeuds.is_empty():
		check(false, "spawn P3 produit un nœud")
		return
	var ronce := noeuds[0]
	add_child(ronce)

	# Attendre la plantation + au moins un tronçon poussé
	var troncon: Node = null
	for i in 180:
		await get_tree().physics_frame
		if ronce.get("phase") != null and ronce.phase != 0 and ronce._tiges.size() > 0 \
				and ronce._tiges[0].segments.size() > 0:
			troncon = ronce._tiges[0].segments[0]
			break
	check(troncon != null, "P3 : un tronçon réel est disponible")
	if troncon == null:
		ronce.queue_free()
		return

	# LE point du test : le script du tronçon n'est PAS dans le REGISTRE —
	# la couleur doit remonter à AttackPlantBramble → rampe verte.
	var rampe := ImpactExplosion.couleur_impact(troncon)
	check(rampe[0] == Color("008400"),
		"plante P3 (coup porté par un tronçon) → rampe verte (008400)")
	# Le tronçon lui-même (script hors REGISTRE) ne suffit pas sans remontée :
	# on vérifie aussi que l'attaque parente est bien verte.
	var rampe_parent := ImpactExplosion.couleur_impact(ronce)
	check(rampe_parent[0] == Color("008400"), "plante P3 (attaque parente) → rampe verte")

	ronce.queue_free()
	await get_tree().physics_frame
