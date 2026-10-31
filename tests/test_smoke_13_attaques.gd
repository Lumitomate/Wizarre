extends Node2D

## Test de fumée des 13 attaques (cf. AttackSpawner.REGISTRE).
## Pour chaque type × chaque tier (I/II/III) :
##  1. spawn_attack(...) retourne au moins un nœud, non nul, avec un script ;
##  2. les nœuds ajoutés à l'arbre (loin de tout) survivent à 2 frames
##     physiques sans crash ni libération spontanée ;
##  3. le registre couvre bien les 13 valeurs de GlobalEnum.AttackType.
## Lancer avec tests/test_smoke_13_attaques.tscn.

var _failures := 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("OK: " + label)
	else:
		print("FAIL: " + label)
		_failures += 1


func _ready() -> void:
	await _test_registre_complet()
	await _test_spawn_13_attaques()
	if _failures == 0:
		print("RESULT: PASS")
		get_tree().quit(0)
	else:
		print("RESULT: FAIL (%d)" % _failures)
		get_tree().quit(1)


# --- 1. Le registre couvre les 13 types --------------------------------
func _test_registre_complet() -> void:
	_check(AttackSpawner.REGISTRE.size() == 13,
		"registre : 13 entrées (obtenu %d)" % AttackSpawner.REGISTRE.size())
	for type in GlobalEnum.AttackType.values():
		_check(AttackSpawner.REGISTRE.has(type),
			"registre : type %d présent" % type)
	_check(AttackSpawner.spawn_attack(999, GlobalEnum.AttackTier.I, Vector2.ZERO,
		Vector2.RIGHT, Vector2(1152, 648), Vector2.ONE, null).is_empty(),
		"spawn_attack : type inconnu → tableau vide (pas de crash)")


# --- 2. Spawn réel des 13 attaques × 3 tiers ---------------------------
## Sorcier factice : Node2D avec AnimatedSprite2D (l'anti-vertical du
## spawner regarde flip_h si la visée est pile verticale — jamais le cas
## ici, mais on fournit le nœud pour être fidèle au jeu).
func _sorcer_factice() -> Node2D:
	var sorcer := Node2D.new()
	sorcer.name = "Factice"
	sorcer.position = Vector2(3000, 3000)
	sorcer.add_child(AnimatedSprite2D.new())
	return sorcer


func _test_spawn_13_attaques() -> void:
	var sorcer := _sorcer_factice()
	add_child(sorcer)
	await get_tree().physics_frame

	var position: Vector2 = Vector2(576, 324)  # centre écran (F1 borne ses colonnes à l'écran)
	var direction: Vector2 = Vector2.RIGHT
	var screen_size: Vector2 = Vector2(1152, 648)
	var level_scale: Vector2 = Vector2.ONE

	for type in GlobalEnum.AttackType.values():
		var nom: String = GlobalEnum.AttackType.keys()[type]
		for tier in GlobalEnum.AttackTier.values():
			var nom_tier: String = GlobalEnum.AttackTier.keys()[tier]
			var etiqueta: String = "%s tier %s" % [nom, nom_tier]

			var noeuds: Array[Node] = AttackSpawner.spawn_attack(
				type, tier, position, direction, screen_size, level_scale, sorcer)

			_check(noeuds.size() > 0, "%s : au moins un nœud" % etiqueta)
			for i in noeuds.size():
				var n: Node = noeuds[i]
				_check(n != null, "%s : nœud %d non nul" % [etiqueta, i])
				if n == null:
					continue
				_check(n.get_script() != null, "%s : nœud %d a un script" % [etiqueta, i])
				# Ajout à l'arbre puis 2 frames : déclenche _ready() et
				# la physique — le vrai test de fumée.
				add_child(n)
			await get_tree().physics_frame
			await get_tree().physics_frame
			for i in noeuds.size():
				var n: Node = noeuds[i]
				if n == null:
					continue
				_check(is_instance_valid(n),
					"%s : nœud %d survit à 2 frames" % [etiqueta, i])
				if is_instance_valid(n):
					n.queue_free()
			await get_tree().physics_frame

	sorcer.queue_free()
	await get_tree().physics_frame
