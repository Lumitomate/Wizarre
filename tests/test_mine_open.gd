extends SceneTree

# Test headless : mine lâchée par un sorcier sous un bloc, puis déclenchée.
# Vérifie que la mine visible se pose sur le sol sous le bloc, que la chute
# touche le SOL (et non le dessus du bloc), et que le plafond est détecté
# pour le clip du feu.

var mine: AttackFireMine
var floor_y := 1000.0
var block_underside_y := 932.0  # face du bloc tournée vers le sol
var player_y := 980.0           # centre du sorcier (~20 px au-dessus du sol)
var step := 0
var exploded_checked := false
var landed_step := -1

func fail(msg: String) -> bool:
	print("TEST ÉCHOUÉ: " + msg)
	quit(1)
	return true

func ok(msg: String) -> void:
	print("TEST: " + msg)

func _initialize() -> void:
	# Sol : StaticBody2D sur la couche 3 (mask valeur 4 = GROUND_MASK)
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(400, 100)
	floor_shape.shape = floor_rect
	floor_body.add_child(floor_shape)
	floor_body.position = Vector2(0, floor_y + 50)
	floor_body.collision_layer = 4
	root.add_child(floor_body)

	var block_underside_y := INF  # pas de bloc

	# Mine réelle, spawn IDENTIQUE au jeu (spawner_attack) : sorcier sous le
	# bloc, mine au-dessus de sa tête
	var mine_scene: PackedScene = load("res://scenes/atk/atk_f3_mine.tscn")
	mine = mine_scene.instantiate()
	mine.position = Vector2(0, player_y - 12 - AttackFireMine.IDLE_CONTENT_DROP)
	root.add_child(mine)
	mine.setup_tier(3)


func _process(_delta: float) -> bool:
	step += 1
	if mine._levitate_landed and landed_step < 0:
		landed_step = step
		ok("mine posée après %d frames (centre=%.1f)" % [step, mine.global_position.y])
		# La mine visible doit être SOUS le bloc et POSÉE sur le sol
		var content_bottom := mine.global_position.y + mine._mine_base_offset()
		var content_top := content_bottom - 40.0
		ok("contenu visible: %.1f -> %.1f (sol=%.1f)"
				% [content_top, content_bottom, floor_y])
		if abs(content_bottom - (floor_y - AttackFireMine.IDLE_HOVER)) > 3.0:
			return fail("bas visible %.1f devrait flotter à %.1f (sol - 8 px)"
					% [content_bottom, floor_y - AttackFireMine.IDLE_HOVER])
		# Déclenchement (2e appui) : après resnap, la base visible doit
		# rester sur le sol (le raycast de chute part de là désormais)
		mine.explode()
		var base_after := mine.global_position.y + mine._mine_base_offset()
		if abs(base_after - floor_y) > 8.0:
			return fail("après explode(), la base visible (%.1f) doit être sur le sol (%.1f)"
					% [base_after, floor_y])
		ok("après explode(): base visible=%.1f (sur le sol)" % base_after)
	if landed_step > 0 and not exploded_checked:
		if mine.phase != 2:  # Phase.EXPLODE
			if step > landed_step + 120:
				return fail("la mine n'a jamais explosé (phase=%d)" % mine.phase)
			return false
		exploded_checked = true
		ok("explosion: ground_y=%.1f" % mine._ground_y)
		if abs(mine._ground_y - floor_y) > 1.0:
			return fail("ground_y doit être le SOL (%.1f), pas le dessus du bloc — reçu %.1f"
					% [floor_y, mine._ground_y])
		# La base du canvas de l'explosion (feu) doit être au niveau du sol
		var fire_base := mine.global_position.y + 76.0 * mine.tier_scale
		ok("base du feu: %.1f (sol=%.1f)" % [fire_base, floor_y])
		if abs(fire_base - floor_y) > 2.0:
			return fail("le feu doit partir du sol sous le bloc, base=%.1f" % fire_base)
		print("TEST: TOUS LES TESTS PASSENT")
		quit(0)
	if step > 600:
		return fail("TIMEOUT")
	return false
