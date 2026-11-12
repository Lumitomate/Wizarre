extends Node

## Test headless de l'explosion d'impact (cf. ImpactExplosion) :
## - rampes par famille (feu = référence, glace, plante, lumière, inconnu)
## - couleur déduite de l'origine (recherche inverse dans REGISTRE) ou
##   passée explicitement (cas des lames G3)
## - spawn : 3 à 7 particules + un halo chacune, anim lancée, matériau de
##   rampe correct, sprites jamais tournés (pixel art)
## - directions réparties de façon homogène
## - étincelles blanches à la frame 5, rendu additif, blanches au départ
## - auto-suppression en fin d'explosion
## - intégration : EnemyFlying.hit() qui blesse → une explosion ; coup
##   sans dégâts (cooldown — ex : contact de graine) → aucune explosion
## Lancé comme scène : godot --headless res://tests/test_impact_explosion.tscn

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK: " + msg)
	else:
		print("FAIL: " + msg)
		failures += 1


func _ready() -> void:
	_test_rampes()
	await _test_couleur_impact()
	await _test_spawn_et_timeline()
	await _test_integration_hit()
	await _test_p1_mange()
	if failures == 0:
		print("RESULT: PASS")
		get_tree().quit(0)
	else:
		print("RESULT: FAIL (%d)" % failures)
		get_tree().quit(1)


# --- 1. Rampes par famille ----------------------------------------------
func _test_rampes() -> void:
	var feu := ImpactExplosion.rampe_pour_type(GlobalEnum.AttackType.F0)
	check(feu.size() == 4, "rampe feu : 4 couleurs")
	check(feu[0] == Color("ff0000") and feu[3] == Color("ffba00"),
		"rampe feu : du sombre (#ff0000) au clair (#ffba00)")
	check(ImpactExplosion.rampe_pour_type(GlobalEnum.AttackType.G1)[0] == Color("00a8e0"),
		"rampe glace : sombre #00a8e0")
	check(ImpactExplosion.rampe_pour_type(GlobalEnum.AttackType.P3)[1] == Color("00ce00"),
		"rampe plante : #00ce00")
	check(ImpactExplosion.rampe_pour_type(GlobalEnum.AttackType.L2)[2] == Color("fbf236"),
		"rampe lumière : #fbf236")
	check(ImpactExplosion.rampe_pour_type(-1)[0] == Color("ff0000"),
		"type inconnu (-1) → rampe de référence (feu)")
	check(ImpactExplosion.rampe_pour_type(999)[0] == Color("ff0000"),
		"type hors enum (999) → rampe de référence")


# --- 2. Couleur déduite de l'origine du coup -----------------------------
func _test_couleur_impact() -> void:
	# Une vraie attaque (F0) non ajoutée à l'arbre : son script suffit à
	# la recherche inverse dans AttackSpawner.REGISTRE.
	var noeuds := AttackSpawner.spawn_attack(GlobalEnum.AttackType.F0,
		GlobalEnum.AttackTier.I, Vector2(3000, 3000), Vector2.RIGHT,
		Vector2(1280, 720), Vector2.ONE, null)
	check(noeuds.size() > 0, "spawn_attack(F0) produit un nœud")
	if noeuds.is_empty():
		return
	check(ImpactExplosion.couleur_impact(noeuds[0])[0] == Color("ff0000"),
		"origine F0 → rampe feu (recherche inverse REGISTRE)")
	check(ImpactExplosion.couleur_impact(null, GlobalEnum.AttackType.G3)[0] == Color("00a8e0"),
		"type explicite G3 → rampe glace")
	check(ImpactExplosion.couleur_impact(null)[0] == Color("ff0000"),
		"sans origine ni type → rampe de référence")
	# Un nœud dont le script n'est pas une attaque (ex : un joueur passé
	# comme origine, comme le fait G3 avant correction) → référence.
	var sans_script := Node2D.new()
	check(ImpactExplosion.couleur_impact(sans_script)[0] == Color("ff0000"),
		"origine sans script d'attaque → rampe de référence")
	sans_script.free()
	for n in noeuds:
		n.free()


# --- 3. Spawn, structure, timeline ---------------------------------------
func _test_spawn_et_timeline() -> void:
	var rampe := ImpactExplosion.rampe_pour_type(GlobalEnum.AttackType.P2)
	ImpactExplosion.spawn(self, Vector2(400, 300), rampe)
	await get_tree().process_frame
	var fx := _derniere_explosion(self)
	check(fx != null, "explosion ajoutée à l'arbre")
	if fx == null:
		return
	check(fx.position == Vector2(400, 300), "explosion au centre demandé")

	var particules: Array[AnimatedSprite2D] = []
	var halos: Array[Sprite2D] = []
	for enfant in fx.get_children():
		if enfant is AnimatedSprite2D:
			particules.append(enfant)
		elif enfant is Sprite2D and enfant.name.begins_with("Halo"):
			halos.append(enfant)
	check(particules.size() >= ImpactExplosion.NB_PARTICULES_MIN
		and particules.size() <= ImpactExplosion.NB_PARTICULES_MAX,
		"3 à 7 particules (obtenu %d)" % particules.size())
	check(halos.size() == particules.size(), "un halo par particule")

	var ok_anim := true
	var ok_filtre := true
	var ok_rampe := true
	var ok_orientation := true
	var ok_portee := true
	for p in particules:
		ok_anim = ok_anim and p.is_playing() and p.frame < ImpactExplosion.NB_FRAMES
		ok_filtre = ok_filtre and p.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		ok_rampe = ok_rampe and p.material.get_shader_parameter("ramp_color_0") == rampe[0]
		# Le haut du sprite (local -Y) doit pointer vers l'extérieur :
		# rotation = angle du rayon + PI/2. Et jamais de flip vertical,
		# qui échangerait bas et haut.
		var attendu := p.position.angle() + PI / 2.0
		ok_orientation = ok_orientation \
			and absf(angle_difference(p.rotation, attendu)) < 0.25 \
			and not p.flip_v
		ok_portee = ok_portee and p.position.length() >= ImpactExplosion.RAYON_LARGE_MIN - 1.0 \
			and p.position.length() <= ImpactExplosion.RAYON_FINE_MAX + 1.0
	check(ok_anim, "anim des particules lancée, frame < 7")
	check(ok_filtre, "sprites en filtrage NEAREST (pixel art)")
	check(ok_rampe, "matériau de rampe : couleurs de l'élément")
	check(ok_orientation, "haut des sprites vers l'extérieur, bas vers le centre")
	check(ok_portee, "particules dans la fourchette de rayon")

	# Directions homogènes : plus grand écart angulaire voisin ≤ 2π/n + jitter
	var angles: Array[float] = []
	for p in particules:
		angles.append(p.position.angle())
	angles.sort()
	var ecart_max := 0.0
	for i in angles.size():
		var ecart: float = angles[(i + 1) % angles.size()] - angles[i]
		if i == angles.size() - 1:
			ecart += TAU
		ecart_max = maxf(ecart_max, ecart)
	check(ecart_max <= TAU / particules.size() + 2.0 * ImpactExplosion.JITTER_PARTICULE + 0.01,
		"directions homogènes (écart max %.2f rad)" % ecart_max)

	var ok_halo := true
	for h in halos:
		ok_halo = ok_halo \
			and h.material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD \
			and h.modulate == Color(rampe[3], ImpactExplosion.HALO_ALPHA_BASE) \
			and h.scale == Vector2(ImpactExplosion.HALO_ECHELLE, ImpactExplosion.HALO_ECHELLE)
	check(ok_halo, "halos additifs, teinte = nuance la plus claire, large")

	# Les étincelles partent à la frame 5 (5/24 s ≈ 12,5 frames physiques)
	while is_instance_valid(fx) and fx._age < ImpactExplosion.T_ETINCELLES + 0.01:
		await get_tree().process_frame
	var etincelles: Array[Sprite2D] = []
	if is_instance_valid(fx):
		for enfant in fx.get_children():
			if enfant is Sprite2D and enfant.name.begins_with("Etincelle"):
				etincelles.append(enfant)
	check(etincelles.size() >= ImpactExplosion.NB_ETINCELLES_MIN
		and etincelles.size() <= ImpactExplosion.NB_ETINCELLES_MAX,
		"10 à 16 étincelles à la frame 5 (obtenu %d)" % etincelles.size())
	var ok_etincelle := true
	for e in etincelles:
		ok_etincelle = ok_etincelle \
			and e.material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD \
			and e.texture.get_width() == 2 \
			and e.texture.get_height() == 2 \
			and e.modulate.r > 0.6 and e.modulate.a > 0.5
	check(ok_etincelle, "étincelles : 2×2 px, additives, quasi blanches au départ")

	# Fin d'anim (7 frames ≈ 0,29 s) : les particules ont disparu, seuls
	# les halos continuent de s'éteindre.
	while is_instance_valid(fx) and fx._age < 8.0 / ImpactExplosion.FPS:
		await get_tree().process_frame
	if is_instance_valid(fx):
		var ok_disparition := true
		for enfant in fx.get_children():
			if enfant is AnimatedSprite2D:
				ok_disparition = ok_disparition and not enfant.visible
				ok_disparition = ok_disparition and not enfant.is_playing()
		check(ok_disparition, "sprites cachés dès la fin de leur anim (pas de dernière frame figée)")

	# Auto-suppression en fin d'explosion (~0,8 s ≈ 48 frames)
	for i in 200:
		if not is_instance_valid(fx):
			break
		await get_tree().process_frame
	check(not is_instance_valid(fx), "explosion auto-supprimée en fin de vie")


# --- 5. Mise à mort directe par la tête carnivore (P1) --------------------
func _test_p1_mange() -> void:
	# La tête P1 mange sa proie d'un coup : die() court-circuite hit()
	# (cf. atk_p1_carnivorous_head.gd). L'explosion d'impact doit quand
	# même naître, verte (famille Plante), à l'endroit de la proie.
	var holder := Node2D.new()
	add_child(holder)
	var tete: CarnivorousHead = (load("res://scenes/atk/atk_p1_carnivorous_head.tscn") as PackedScene).instantiate()
	holder.add_child(tete)
	await get_tree().process_frame
	var ennemi: EnemyFlying = (load("res://scenes/entities/ennemies/enemy_2lifes.tscn") as PackedScene).instantiate()
	ennemi.position = Vector2(300, 200)
	holder.add_child(ennemi)
	await get_tree().process_frame

	# On place la morsure exactement à la frame fatale, puis on déclenche
	# le même callback que l'animation de morsure réelle.
	tete.target_enemy = ennemi
	tete.bite_triggered = false
	tete.head.animation = &"atk_p1_bite"
	tete.head.frame = tete.bite_kill_frame
	var avant := _compter_explosions(holder)
	tete._on_bite_frame_changed()
	var apres := _compter_explosions(holder)
	check(apres == avant + 1, "P1 mange sa proie → une explosion d'impact")
	var fx := _derniere_explosion(holder)
	if fx != null:
		check(fx._rampe[0] == Color("008400"), "P1 → explosion verte (famille Plante)")
		check(fx.position.distance_to(ennemi.position) < 1.0,
			"explosion à l'endroit de la proie")


# --- 4. Intégration EnemyFlying.hit ---------------------------------------
func _test_integration_hit() -> void:
	var scene: PackedScene = load("res://scenes/entities/ennemies/enemy_flying.tscn")
	var holder := Node2D.new()
	add_child(holder)
	var ennemi: EnemyFlying = scene.instantiate()
	ennemi.position = Vector2(220, 160)
	ennemi.lives = 3
	holder.add_child(ennemi)
	await get_tree().process_frame

	var avant := _compter_explosions(holder)
	ennemi.hit(1, null, null, GlobalEnum.AttackType.G3)
	var apres := _compter_explosions(holder)
	check(apres == avant + 1, "hit qui blesse → une explosion d'impact")
	var fx := _derniere_explosion(holder)
	if fx != null:
		check(fx._rampe[0] == Color("00a8e0"), "type explicite G3 → explosion bleue")
		check(fx.position.distance_to(ennemi.position) < 1.0,
			"explosion au point d'impact (position de l'ennemi)")

	# Deuxième coup pendant le cooldown : aucun dégât → AUCUNE explosion
	# (c'est ce qui garantit « graine au contact sans dégâts → rien »).
	ennemi.hit(1, null, null, GlobalEnum.AttackType.G3)
	check(_compter_explosions(holder) == apres,
		"hit sans dégâts (cooldown) → pas d'explosion")


func _derniere_explosion(parent: Node) -> ImpactExplosion:
	for i in range(parent.get_child_count() - 1, -1, -1):
		var enfant := parent.get_child(i)
		if enfant is ImpactExplosion:
			return enfant
	return null


func _compter_explosions(parent: Node) -> int:
	var n := 0
	for enfant in parent.get_children():
		if enfant is ImpactExplosion:
			n += 1
	return n
