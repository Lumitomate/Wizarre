extends Node2D

# Smoke test headless P3 - contact : graine plantée (mêmes conditions que
# la P1), puis un ennemi touche le tronçon 1 en pleine croissance → 1 dégât
# + décomposition depuis le tronçon touché, propagation dans les deux sens.
# Un sorcier sur le tronçon 0 prend aussi 1 dégât.

var _frames := 0
var _bramble: AttackPlantBramble = null
var _enemy: Node2D = null
var _player: Node2D = null
var _failures := 0
var _planted_frame := -1


## Tier I = UNE seule tige : les tronçons de la ronce sont ceux de cette
## tige. La ronce est multi-tiges depuis la refonte (`_tiges`, chaque tige
## portant sa propre chaîne + son bulbe) : `_segments` n'existe plus.
func _troncons() -> Array[AttackPlantBrambleSegment]:
	return _bramble._tiges[0].segments


func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: " + label)
	else:
		print("FAIL: " + label)
		_failures += 1


func _make_entity(group: String, pos: Vector2) -> Node2D:
	var body := StaticBody2D.new()
	body.add_to_group(group)
	var script := GDScript.new()
	# Même signature que le VRAI hit() des ennemis (enemy_flying.gd) :
	# (damage, attacker, origin). Avec 2 paramètres, le tronçon de ronce
	# qui appelle body.hit(damage, caster, self) échouait — le mock était
	# resté en arrière quand l'origine du coup a été ajoutée.
	script.source_code = """
extends StaticBody2D
var lives := 3
func hit(damage: int, _attacker: Node2D = null, _origin: Node2D = null) -> void:
	lives -= damage
"""
	script.reload()
	body.set_script(script)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 20)
	cs.shape = rect
	body.add_child(cs)
	body.position = pos
	add_child(body)
	return body


func _ready() -> void:
	# Sol (couche 4 = collision_mask 8 de la graine)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 8
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 40)
	cs.shape = rect
	floor_body.add_child(cs)
	floor_body.position = Vector2(576, 372)  # surface à y = 352
	add_child(floor_body)

	var attacks := AttackSpawner.spawn_attack(
		GlobalEnum.AttackType.P3,
		GlobalEnum.AttackTier.I,
		Vector2(400, 300),
		Vector2.RIGHT,
		Vector2(1152, 648),
		Vector2(2, 2),
		self
	)
	_bramble = attacks[0]
	add_child(_bramble)
	# Déterminisme : graine posée au sol (surface y=352, capsule mi-hauteur
	# 24 px à l'échelle du test) et immobile → plantation immédiate
	_bramble.global_position = Vector2(460, 326)
	_bramble.linear_velocity = Vector2.ZERO


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _planted_frame == -1 and _bramble.phase != AttackPlantBramble.Phase.FLYING:
		_planted_frame = _frames
		print("OK: graine plantée (frame %d, y=%.0f)" % [_frames, _bramble.global_position.y])
		# Géométrie (échelle effective 4, espacement 64 px), base à (460, 352) :
		# hitbox tronçon 0 = y [288 ; 352], tronçon 1 (origine 288) = [224 ; 288].
		# L'ennemi ne chevauche que le tronçon 1, le joueur que le tronçon 0 ;
		# ajoutés APRÈS la plantation pour ne pas bloquer l'éclosion.
		_enemy = _make_entity("enemy_group", Vector2(460, 256))
		_player = _make_entity("player_group", Vector2(460, 320))
	if _planted_frame == -1:
		if _frames > 300:
			print("FAIL: la graine ne plante jamais")
			print("RESULT: FAIL")
			get_tree().quit(1)
		return
	var t := _frames - _planted_frame
	match t:
		45:
			_check(_troncons().size() >= 2, "tronçon 1 poussé")
			# L'ennemi chevauche la hitbox du tronçon 1 (active dès le Grow)
			_check(_enemy.lives == 2, "contact tronçon 1 → 1 dégât (vies: %d)" % _enemy.lives)
			_check(_player.lives == 2, "contact sorcier tronçon 0 → 1 dégât (vies: %d)" % _player.lives)
			# La ronce est MULTI-TIGES depuis la refonte : un contact ennemi ne
			# met plus la ronce entière en DECOMPOSING — SEULE la tige touchée
			# se décompose, les autres continuent de pousser (cf. l'en-tête de
			# atk_p3_plant_bramble.gd). Ce qui doit être vrai ici, c'est que la
			# tige touchée a lancé sa cascade et ne pousse plus.
			_check(_bramble._tiges[0].cascade_started,
				"contact → la tige touchée cesse de pousser (cascade lancée)")
			_check(_troncons()[1]._decomposing, "cascade démarre au tronçon touché")
		70:
			_check(_troncons()[0]._decomposing, "propagation vers la base")
			_check(not _bramble.get_node("BaseBack").visible, "base disparue")
		110:
			if _failures == 0:
				print("RESULT: PASS")
				get_tree().quit(0)
			else:
				print("RESULT: FAIL (%d)" % _failures)
				get_tree().quit(1)