extends Node
## Test headless du magasin réflexe à 2 joueurs : cabine fermée de base
## déverrouillée par l'épreuve des plaques, et porte de sortie qui suit
## l'occupation de la cabine :
##  - la cabine est VERROUILLÉE à l'arrivée (porte fermée) ;
##  - la porte de sortie est FERMÉE à l'arrivée (épreuve pas faite) ;
##  - une fois l'épreuve réussie (2 plaques maintenues jusqu'au bout des
##    animations d'énergie), la cabine s'ouvre et la porte de sortie avec ;
##  - tant qu'un sorcier occupe la cabine, la porte de sortie SE REFERME ;
##  - quand le rituel est terminé et le sorcier sorti, elle se rouvre.
## Lancé : godot --headless res://tests/test_shop_2players_reflex.tscn
##
## Le rituel d'achat DANS la cabine est déjà couvert par
## test_cabine.tscn : ici on simule seulement sa fin (etat = INERT),
## ce que le test du magasin course fait aussi.

const SCENE := "res://scenes/niveaux/magasin/magasin_reflex/shop_2players_reflex.tscn"
const SORCIER := "res://scenes/entities/players/sorcerer.tscn"

var inst: Node
var cabine: Cabin
var sorcier: Sorcerer
var _failures := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: " + label)
	else:
		print("FAIL: " + label)
		_failures += 1


## Attend que `cond` devienne vrai (ou écoulement de max_frames) ; renvoie
## l'état final de la condition.
func _attendre(cond: Callable, max_frames: int) -> bool:
	var t := 0
	while t < max_frames and not cond.call():
		await get_tree().physics_frame
		t += 1
	return cond.call()


func _zone_active() -> bool:
	return not (inst.get_node("ShopDoor/CollisionShape2D") as CollisionShape2D).disabled


func _pret() -> void:
	inst = load(SCENE).instantiate()
	add_child(inst)
	cabine = inst.get_node("Pressureplate2Players/Cabine") as Cabin
	sorcier = load(SORCIER).instantiate()
	sorcier.controller_id = 0
	sorcier.position = Vector2(4000, 20)
	add_child(sorcier)
	sorcier.load_data()


func _scenar() -> void:
	# --- Mise en place ---
	for i in 3:
		await get_tree().physics_frame
	_check(cabine != null and cabine.verrouillee,
		"la cabine est verrouillée à l'arrivée")
	_check(cabine.etat == Cabin.Etat.ACTIVE, "la cabine démarre libre (ACTIVE)")
	var porte: Area2D = inst.get_node("ShopDoor")
	_check(not porte.is_playing() and not _zone_active(),
		"la porte de sortie est FERMÉE à l'arrivée (épreuve pas faite)")

	# --- Épreuve : les 2 plaques maintenues jusqu'au bout ---
	var s1: Sorcerer = load(SORCIER).instantiate()
	s1.controller_id = 0
	s1.position = Vector2(4000, 20)
	add_child(s1)
	var s2: Sorcerer = load(SORCIER).instantiate()
	s2.controller_id = 1
	s2.position = Vector2(4000, 20)
	add_child(s2)
	var plaques: Node2D = inst.get_node("Pressureplate2Players")
	plaques._on_plate_body_entered(s1, "left")
	plaques._on_plate_body_entered(s2, "right")

	var reussi := await _attendre(func() -> bool: return not cabine.verrouillee, 1800)
	_check(reussi, "l'épreuve réussie déverrouille la cabine")
	_check(cabine.verrouillee == false and not cabine.est_occupee(),
		"la cabine est ouverte et libre après l'épreuve")

	# --- La porte de sortie suit : ouverte (cabine libre) ---
	var ouverte := await _attendre(_zone_active, 600)
	_check(ouverte, "la porte de sortie s'ouvre une fois l'épreuve réussie")

	# --- Un sorcier entre dans la cabine : la porte se referme ---
	cabine.entrer(sorcier)
	_check(cabine.est_occupee(), "le sorcier occupe la cabine")
	for i in 3:
		await get_tree().physics_frame
	_check(not _zone_active() and porte.frame == 0,
		"la porte de sortie SE REFERME tant que la cabine est occupée")
	# ... et reste refermée tant que ça dure.
	for i in 30:
		await get_tree().physics_frame
	_check(not _zone_active(), "la porte reste fermée pendant le rituel")

	# --- Fin du rituel : le sorcier sort, la porte se rouvre ---
	sorcier.global_position = Vector2(4000, 20)
	cabine.etat = Cabin.Etat.INERT
	_check(not cabine.est_occupee(), "la cabine est libérée à la fin du rituel")
	var rouverte := await _attendre(_zone_active, 600)
	_check(rouverte, "la porte de sortie se rouvre à la fin du rituel")

	s1.queue_free()
	s2.queue_free()
	if _failures == 0:
		print("RESULT: PASS")
		get_tree().quit(0)
	else:
		print("RESULT: FAIL (%d)" % _failures)
		get_tree().quit(1)


func _ready() -> void:
	_pret()
	_scenar()
