extends Node2D

# Smoke test headless P3 : cycle complet — graine lancée → plantation
# (mêmes conditions que la graine P1) → croissance 8 tronçons (tier I,
# le 8e = bulbe) → gel 2 s → décomposition en cascade depuis le bout.

var _frames := 0
var _bramble: AttackPlantBramble = null
var _failures := 0
var _planted_frame := -1


## Tier I = UNE seule tige : les tronçons de la ronce sont ceux de cette
## tige, et son bulbe de tête est le seul. La ronce est multi-tiges depuis
## la refonte (`_tiges`, chaque tige portant sa chaîne + son bulbe) :
## `_segments` et `_tip_bulb` n'existent plus.
func _troncons() -> Array[AttackPlantBrambleSegment]:
	return _bramble._tiges[0].segments


func _bulbe() -> Sprite2D:
	return _bramble._tiges[0].bulb


func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: " + label)
	else:
		print("FAIL: " + label)
		_failures += 1


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
	_check(attacks.size() == 1, "spawn_attack(P3) produit 1 attaque")
	_bramble = attacks[0]
	add_child(_bramble)
	# Déterminisme : graine posée au sol (surface y=352, capsule mi-hauteur
	# 24 px à l'échelle du test) et immobile → plantation immédiate
	_bramble.global_position = Vector2(460, 326)
	_bramble.linear_velocity = Vector2.ZERO


func _physics_process(_delta: float) -> void:
	_frames += 1
	# La graine plante quand sa vitesse est nulle et sa place libre
	if _planted_frame == -1 and _bramble.phase != AttackPlantBramble.Phase.FLYING:
		_planted_frame = _frames
		print("OK: graine plantée (frame %d, y=%.0f)" % [_frames, _bramble.global_position.y])
	if _planted_frame == -1:
		if _frames > 300:
			print("FAIL: la graine ne plante jamais")
			print("RESULT: FAIL")
			get_tree().quit(1)
		return
	var t := _frames - _planted_frame
	match t:
		5:
			_check(_bramble.is_growing(), "phase GROWING après plantation")
			_check(abs(_bramble.global_position.y - 352.0) < 2.0, "base collée au sol (y=%.0f)" % _bramble.global_position.y)
			var bb: AnimatedSprite2D = _bramble.get_node("BaseBack")
			_check(bb.visible and bb.is_playing(), "base visible, anim en lecture")
			var bf: AnimatedSprite2D = _bramble.get_node("BaseFront")
			_check(bf.visible and bf.is_playing()
				and "Base_Front_" in bf.sprite_frames.get_frame_texture(bf.animation, 0).resource_path,
				"BaseFront visible avec ses propres frames")
			_check(bb.scale.length() > 0.5, "base scale > 0 (apparition tween)")
			_check(not _bramble.get_node("SeedSprite").visible, "graine cachée après plantation")
		20:
			# Croissance ENCORE en cours (5 tronçons × 0,1 s = 0,5 s) : c'est ici
			# qu'on peut voir le bulbe animer. À 35, la pousse est déjà finie
			# (SEGMENT_INTERVAL a été divisé par 2 : le test avait gardé le
			# découpage d'avant et regardait un bulbe déjà figé sur Bite21).
			_check(_troncons().size() >= 2, "2e tronçon à ~0,2 s")
			var bulb: Sprite2D = _bulbe()
			_check(bulb != null and is_instance_valid(bulb) and bulb.get_parent() == _bramble,
				"bulbe enfant du conteneur (glisse, pas de téléportation)")
			var frame_idx: int = AttackPlantBramble.TIP_BULB_FRAMES.find(bulb.texture)
			_check(frame_idx > 0 and frame_idx < 20,
				"bulbe en cours d'anim Bite (frame %d)" % frame_idx)
		35:
			_check(_troncons().size() >= 3, "3e tronçon à ~0,6 s")
		95:
			_check(_troncons().size() >= 6, "6 tronçons à ~1,5 s")
		120:
			_check(_troncons().size() == 6, "tier I = 5 tiges + 1 tronçon de liaison")
			_check(not _bramble.is_growing(), "fin de croissance → WAITING")
			var bulb: Sprite2D = _bulbe()
			_check(bulb != null and is_instance_valid(bulb) and bulb.get_parent() == _bramble,
				"bulbe sur le dernier tronçon")
			# Constantes LUES sur la classe : ce chiffre était recopié en dur
			# (32 - 8) × 4, et le test s'est désynchronisé quand TIP_BULB_SCALE
			# est passé de 4 à 1.
			var expected_y := -(_bramble._segment_spacing() * 6.0
				+ (AttackPlantBramble.TIP_BULB_CANVAS_BOTTOM - AttackPlantBramble.TIP_BULB_SINK)
					* AttackPlantBramble.TIP_BULB_SCALE)
			_check(abs(bulb.position.y - expected_y) < 1.0,
				"bulbe calé en haut du dernier sprite (y=%.0f, attendu %.0f)" % [bulb.position.y, expected_y])
			_check(bulb.texture == AttackPlantBramble.TIP_BULB_FRAMES[20],
				"bulbe figé sur Bite21 en fin de pousse")
		240:
			_check(_bramble.phase == AttackPlantBramble.Phase.DECOMPOSING,
				"decomposition apres gel de 2 s")
			_check(not is_instance_valid(_bulbe()),
				"cascade depuis le bout : bulbe libéré avec son tronçon")
		260:
			var seg0: AttackPlantBrambleSegment = _troncons()[0]
			_check((is_instance_valid(seg0) and seg0._decomposing)
				or not _bramble.get_node("BaseBack").visible,
				"cascade atteint la base")
			_check(not _bramble.get_node("BaseBack").visible, "base disparue")
		300:
			if _failures == 0:
				print("RESULT: PASS")
				get_tree().quit(0)
			else:
				print("RESULT: FAIL (%d)" % _failures)
				get_tree().quit(1)