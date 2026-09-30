extends Node2D

## Test headless du magasin Shophands (lancer : godot --headless
## res://tests/test_shophands.tscn) :
##  1. Décideur : plaque → main se ferme ; quitter la plaque → la main se
##     rouvre ; dernière frame → décision gravée UNE seule fois, main
##     gagnante tendue, plaques inertes ;
##  2. Scène complète à 4 joueurs : décideur à la porte d'entrée, 3
##     receveurs posés sur les marqueurs (gelés pendant la cinématique),
##     objet au centre du cadre, hitbox désactivée, porte de sortie fermée ;
##  3. Décision vers la droite : l'objet glisse puis émerge du bloc 5/0 de
##     l'espace de droite, hitbox activée en cours de montée ; porte de
##     sortie ouverte à l'attrapage ;
##  4. Variante 3 joueurs : main du bas retirée, espace du bas scellé
##     (blocs 4/2 en (7..19, 9), blocs 1/1 dessous), marqueurs gauche et
##     droite seulement.

const SCENE_SHOP := "res://scenes/niveaux/magasin/magasin_don/shop_hands.tscn"
const SCENE_DECIDER := "res://scenes/niveaux/magasin/magasin_don/shop_hands_decider.tscn"

var _failures := 0
var _directions_recues: Array[Vector2] = []


func _check(ok: bool, label: String) -> void:
	if ok:
		print("OK: " + label)
	else:
		print("FAIL: " + label)
		_failures += 1


func _ready() -> void:
	Engine.time_scale = 4.0
	await _frames(2)
	await _test_decider()
	await _test_shop(4)
	await _test_shop(3)
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


func _reset_player_manager(nb: int) -> void:
	PlayerManager.end_game()
	for id in PlayerManager.known_controllers.duplicate():
		PlayerManager.players.erase(id)
	PlayerManager.known_controllers.clear()
	PlayerManager.player_slots.clear()
	for i in nb:
		PlayerManager._add_controller(100 + i)
	PlayerManager.start_game()


# ---------------------------------------------------------------------------
# 1. La mécanique du décideur seule (plaques → mains → verrouillage)
func _test_decider() -> void:
	var decider: ShophandsDecider = load(
		"res://scenes/niveaux/magasin/magasin_don/shop_hands_decider.tscn"
	).instantiate()
	add_child(decider)
	await _frames(2)
	var main_d: AnimatedSprite2D = decider.get_node("MainD")
	var main_g: AnimatedSprite2D = decider.get_node("MainG")
	var plaque_d: PressurePlate = decider.get_node("PressurePlate3")
	var plaque_g: PressurePlate = decider.get_node("PressurePlate")
	var recues: Array[Vector2] = []
	decider.direction_choisie.connect(
		func(d: Vector2) -> void: recues.append(d)
	)
	var derniere := main_d.sprite_frames.get_frame_count("FermetureD") - 1

	# Pose de repos : toutes les mains FERMÉES (dernière frame) ; frame 0 =
	# main ouverte, c'est la pose finale « tendue »
	_check(main_d.frame == derniere, "décideur : main droite en pose de repos (fermée, dernière frame)")
	_check(main_g.frame == derniere, "décideur : main gauche en pose de repos (fermée, dernière frame)")

	# Tenir la plaque → la main S'OUVRE (anim à l'envers) ; quitter → elle
	# se referme (anim en avant)
	plaque_d.activated.emit()
	await _frames(6)
	var frame_ouverte := main_d.frame
	_check(frame_ouverte < derniere, "décideur : la main s'ouvre quand le sorcier tient la plaque")
	plaque_d.deactivated.emit()
	await _frames(6)
	_check(main_d.frame > frame_ouverte, "décideur : la main se referme quand il quitte la plaque")
	_check(not decider._verrouille, "décideur : décision non gravée si la main n'est pas entièrement ouverte")

	# On revient sur la plaque et on tient jusqu'à l'ouverture complète
	plaque_d.activated.emit()
	var grave := await _attendre(func(): return decider._verrouille, 6.0)
	_check(grave, "décideur : décision gravée quand la main est entièrement ouverte (frame 0)")
	_check(recues.size() == 1 and recues[0] == Vector2.RIGHT, "décideur : direction DROITE émise une seule fois")
	_check(main_d.frame == 0, "décideur : main gagnante reste tendue (ouverte, frame 0)")

	# Verrouillé : les plaques ne répondent plus
	plaque_d.deactivated.emit()
	plaque_d.activated.emit()
	plaque_g.activated.emit()
	await _frames(10)
	_check(main_d.frame == 0, "décideur : main droite figée ouverte après verrouillage")
	_check(main_g.frame == derniere, "décideur : la plaque de gauche reste inerte après verrouillage")

	# Nouvelle instance pour tester le frôlage (la précédente est verrouillée)
	decider.free()
	decider = load(SCENE_DECIDER).instantiate()
	add_child(decider)
	await _frames(2)
	main_d = decider.get_node("MainD")
	plaque_d = decider.get_node("PressurePlate3")

	# Frôlage : la sortie est signalée avant que l'anim n'ait avancé d'une
	# seule frame (même frame) — la main ne doit PAS s'ouvrir toute seule
	# ni graver la décision
	var recues_frolage: Array[Vector2] = []
	decider.direction_choisie.connect(
		func(d: Vector2) -> void: recues_frolage.append(d)
	)
	plaque_d.activated.emit()
	plaque_d.deactivated.emit()
	await _frames(30)
	_check(main_d.frame == derniere, "décideur : frôler la plaque ne déclenche pas l'ouverture")
	_check(recues_frolage.is_empty(), "décideur : le frôlage ne grave pas la décision")
	_check(not decider._verrouille, "décideur : le frôlage ne verrouille pas")

	# Et la main reste utilisable ensuite
	plaque_d.activated.emit()
	await _frames(6)
	_check(main_d.frame < derniere, "décideur : la main fonctionne normalement après un frôlage")
	decider.free()
	await _frames(2)


# ---------------------------------------------------------------------------
# 2-4. Scène complète : 4 joueurs puis variante 3 joueurs
func _test_shop(nb_joueurs: int) -> void:
	# Réinitialisation propre de l'état joueurs entre les deux passes
	PlayerManager.end_game()
	PlayerManager.known_controllers.clear()
	PlayerManager.players.clear()
	PlayerManager.player_slots.clear()
	for i in nb_joueurs:
		PlayerManager._add_controller(100 + i)
	PlayerManager.start_game()

	var shop: Node2D = load("res://scenes/niveaux/magasin/magasin_don/shop_hands.tscn").instantiate()
	add_child(shop)
	await _frames(5)

	var porte: Node2D = shop.get_node("Terrain1PortesEntree")
	var marqueurs: Array[Marker2D] = [
		shop.get_node("Marker2D_spawnerSorcier_2"),
		shop.get_node("Marker2D_spawnerSorcier_3"),
	]
	if nb_joueurs >= 4:
		marqueurs.append(shop.get_node("Marker2D_spawnerSorcier_4"))

	_check(shop._decideur != null, "%d joueurs : décideur désigné" % nb_joueurs)
	_check(shop._receveurs.size() == nb_joueurs - 1,
		"%d joueurs : %d receveurs" % [nb_joueurs, nb_joueurs - 1])

	# Receveurs posés sur les marqueurs, gelés, solides (dé-fantômés)
	for receveur in shop._receveurs:
		_check(receveur.frozen, "receveur gelé pendant la cinématique d'arrivée")
		_check(receveur.collision_layer == receveur._collision_layer_origin,
			"receveur solide (désinscription de la porte propre)")
	var poses := {}
	for m in marqueurs:
		poses[m.position.round()] = false
	for receveur in shop._receveurs:
		poses[receveur.position.round()] = true
	var tous_poses := true
	for cle in poses:
		if poses[cle] != true:
			tous_poses = false
	_check(tous_poses, "chaque marqueur d'espace est occupé par un receveur")

	# Décideur : seul à la porte d'entrée
	_check(shop._decideur.position == shop.get_node("Terrain1PortesEntree").position + Vector2(0, 32),
		"décideur au centre de la porte d'entrée")

	# Objet au centre du cadre, hitbox désactivée
	if shop._objet != null:
		_check(not shop._objet.monitoring, "objet : hitbox désactivée au centre (le décideur ne peut pas le voler)")
		_check(shop._objet.z_index == -1, "objet derrière le cadre et les tuiles")
		_check(shop._objet.position.distance_to(Vector2(875, 481)) < 1.0,
			"objet flottant au centre du cadre")
	else:
		_check(false, "objet spawné au centre")
	_check(not shop.get_node("ShopDoor").is_playing(), "porte de sortie fermée tant que l'objet n'est pas attrapé")

	# Variante 3 joueurs : main du bas retirée et espace scellé
	if nb_joueurs == 3:
		var tm: TileMapLayer = shop.get_node("TileMapLayer")
		_check(not shop.get_node("ShophandsDecider/MainB").visible, "3 joueurs : main du bas masquée")
		_check(shop.get_node("ShophandsDecider/PressurePlate2/StaticBody2D/CollisionShape2D").disabled,
			"3 joueurs : plaque centrale désactivée")
		_check(tm.get_cell_atlas_coords(Vector2i(7, 9)) == Vector2i(4, 2), "3 joueurs : rangée (7,9) scellée en 4/2")
		_check(tm.get_cell_atlas_coords(Vector2i(19, 9)) == Vector2i(4, 2), "3 joueurs : rangée (19,9) scellée en 4/2")
		_check(tm.get_cell_atlas_coords(Vector2i(7, 10)) == Vector2i(1, 1), "3 joueurs : blocs 1/1 sous la rangée")
		_check(tm.get_cell_atlas_coords(Vector2i(19, 15)) == Vector2i(1, 1),
			"3 joueurs : plancher sous l'ancien espace du bas en 1/1")
		_check(not shop._bloc_par_direction.has(Vector2.DOWN), "3 joueurs : plus de bloc pour le bas")
		_check(shop._bloc_par_direction.has(Vector2.LEFT) and shop._bloc_par_direction.has(Vector2.RIGHT),
			"3 joueurs : blocs gauche et droite cartographiés")

	# Fin de la cinématique d'arrivée : tout le monde est dégelé
	var degel := await _attendre(func() -> bool:
		for r in shop._receveurs:
			if r.frozen:
				return false
		return true, 10.0)
	_check(degel, "receveurs dégelés après la refermeture de la porte")

	# Décision forcée : plaque de droite → l'objet part à droite
	shop.get_node("ShophandsDecider/PressurePlate3").activated.emit()
	var envoye := await _attendre(func(): return shop._objet_envoye, 6.0)
	_check(envoye, "décision gravée après fermeture complète de la main (4 joueurs)")
	if envoye:
		var arrivee: Vector2 = shop._bloc_par_direction[Vector2.RIGHT] + Vector2(0, -99)
		var arrive := await _attendre(func() -> bool:
			return is_instance_valid(shop._objet) \
				and shop._objet.position.distance_to(arrivee) < 4.0, 6.0)
		_check(arrive, "objet réapparu au bloc 5/0 de l'espace de droite, flottant")
		_check(is_instance_valid(shop._objet) and shop._objet.monitoring,
			"hitbox de l'objet active après émergence")
		# Attrapé → la porte de sortie s'ouvre
		shop._on_objet_attrape(null)
		await _frames(3)
		_check(shop.get_node("ShopDoor").is_playing(),
			"porte de sortie ouverte dès que l'objet est attrapé")

	shop.queue_free()
	await _frames(2)
	PlayerManager.end_game()
	for id in PlayerManager.known_controllers.duplicate():
		PlayerManager.players.erase(id)
	PlayerManager.known_controllers.clear()
	PlayerManager.player_slots.clear()
