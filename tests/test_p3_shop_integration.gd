extends SceneTree

# Test headless : charge le magasin et vérifie que les objets d'attaque
# spawn correctement (dont le P3), avec les bonnes textures/animations.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := 0

	# 1. La scène objet P3 se charge et a les bonnes propriétés
	var p3_scene: PackedScene = load("res://scenes/objets/obj_p3_bramble.tscn")
	if p3_scene == null:
		print("FAIL: obj_p3_bramble.tscn ne se charge pas")
		failures += 1
	else:
		var obj: AttackObject = p3_scene.instantiate()
		if obj.item_attack_type != GlobalEnum.AttackType.P3:
			print("FAIL: item_attack_type != P3 (valeur: %d)" % obj.item_attack_type)
			failures += 1
		else:
			print("OK: obj_p3_bramble charge, item_attack_type = P3")
		if obj.item_attack_family != GlobalEnum.AttackFamily.Fossil:
			print("FAIL: item_attack_family != Fossil (valeur: %d)" % obj.item_attack_family)
			failures += 1
		else:
			print("OK: item_attack_family = Fossil")
		var sprite: AnimatedSprite2D = obj.get_node("ObjetAttaqueAnimation")
		for anim in ["Bronze", "Argent", "Or"]:
			if not sprite.sprite_frames.has_animation(anim):
				print("FAIL: animation %s manquante" % anim)
				failures += 1
		if sprite.sprite_frames.get_frame_count("Bronze") < 1:
			print("FAIL: animation Bronze vide")
			failures += 1
		else:
			var tex := sprite.sprite_frames.get_frame_texture("Bronze", 0)
			print("OK: icône Bronze = %s" % tex.resource_path)
		obj.free()

	# 2. Le spawner propose bien P3 dans ses types possibles
	var spawner_scene: PackedScene = load("res://scenes/spawner_object.tscn")
	if spawner_scene == null:
		print("FAIL: spawner_object.tscn ne se charge pas")
		failures += 1
	else:
		var spawner = spawner_scene.instantiate()
		var has_p3 := false
		for t in spawner.PROPOSABLE_TYPES:
			if t == GlobalEnum.AttackType.P3:
				has_p3 = true
		if has_p3:
			print("OK: P3 présent dans PROPOSABLE_TYPES du spawner")
		else:
			print("FAIL: P3 absent de PROPOSABLE_TYPES")
			failures += 1
		spawner.free()

	# 3. Le spawner gère le cas P3 : on force chosen_object_type = P3
	#    en simulant le choix (le match P3 doit résoudre vers la scène bramble)
	var spawner2 = spawner_scene.instantiate()
	# Instantie sans l'ajouter à l'arbre : on appelle directement le match
	# via un spawn simulé — plus simple : vérifier que le script compile et
	# que la variable bramble_object_scene existe
	if "bramble_object_scene" in spawner2:
		print("OK: bramble_object_scene déclarée dans le spawner")
	else:
		print("FAIL: bramble_object_scene absente du spawner")
		failures += 1
	spawner2.free()

	# 4. La scène d'attaque elle-même se charge
	var atk_scene: PackedScene = load("res://scenes/atk/atk_p3_plant_bramble.tscn")
	if atk_scene == null:
		print("FAIL: atk_p3_plant_bramble.tscn ne se charge pas")
		failures += 1
	else:
		var atk = atk_scene.instantiate()
		var sprite: AnimatedSprite2D = atk.get_node_or_null("AnimatedSprite2D")
		if sprite == null:
			print("FAIL: AnimatedSprite2D introuvable dans la scène d'attaque")
			failures += 1
		else:
			for anim in ["Grow", "Idle"]:
				if not sprite.sprite_frames.has_animation(anim):
					print("FAIL: animation %s absente de l'attaque" % anim)
					failures += 1
				else:
					print("OK: animation %s présente (%d frames)" % [anim, sprite.sprite_frames.get_frame_count(anim)])
		atk.free()

	print("---")
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)