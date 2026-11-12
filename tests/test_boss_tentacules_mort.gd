extends Node2D

## Test headless de la mort du boss — régression de l'erreur
## « BossHalf.tentacules_de_mort: Trying to assign invalid previously
## freed instance » : une tentacule de combat qui RENTRE dans son trou
## fait queue_free() (cf. tentacule_boss.gd _retracter) pendant que
## _tentacules_par_marker garde la référence morte. À la mort du boss,
## l'assignation typée plantait AVANT le garde-fou is_instance_valid →
## la séquence de mort s'interrompait (pas de câbles sur les marqueurs).
## Lancé comme scène : godot --headless res://tests/test_boss_tentacules_mort.tscn

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK: " + msg)
	else:
		print("FAIL: " + msg)
		failures += 1


func _ready() -> void:
	var holder := Node2D.new()
	add_child(holder)
	var moitie: BossHalf = (load("res://scenes/entities/ennemies/Boss/boss_tentacles.tscn") as PackedScene).instantiate()
	holder.add_child(moitie)
	await get_tree().process_frame

	var markers := moitie.markers_spawn()
	check(markers.size() >= 2, "la moitié expose ses marqueurs (obtenu %d)" % markers.size())

	# Scénario réel : une tentacule de combat est sortie puis RENTRÉE
	# (libérée), le dictionnaire garde la référence morte. Pas besoin de
	# la mettre dans l'arbre : une instance libérée suffit au scénario.
	var tentacule: TentaculeBoss = (load("res://scenes/entities/ennemies/Boss/tentacule_boss.tscn") as PackedScene).instantiate()
	tentacule.free()
	moitie._tentacules_par_marker[markers[0]] = tentacule
	check(not is_instance_valid(tentacule), "la 1re tentacule est libérée (référence morte dans le dictionnaire)")

	# Mort du boss : chaque marqueur doit produire UN câble de mort, y
	# compris celui dont la référence est morte.
	var avant := _compter_tentacules(holder)
	moitie.tentacules_de_mort(3)
	await get_tree().process_frame
	var apres := _compter_tentacules(holder)
	check(apres - avant == markers.size(),
		"un câble de mort par marqueur, même sur référence libérée (+%d, attendu +%d)"
			% [apres - avant, markers.size()])

	# Hygiène : la référence morte a été retirée du dictionnaire.
	check(not moitie._tentacules_par_marker.has(markers[0])
		or is_instance_valid(moitie._tentacules_par_marker[markers[0]]),
		"référence morte nettoyée du dictionnaire")

	if failures == 0:
		print("RESULT: PASS")
		get_tree().quit(0)
	else:
		print("RESULT: FAIL (%d)" % failures)
		get_tree().quit(1)


func _compter_tentacules(parent: Node) -> int:
	var n := 0
	for enfant in parent.get_children():
		if enfant is TentaculeBoss:
			n += 1
	return n
