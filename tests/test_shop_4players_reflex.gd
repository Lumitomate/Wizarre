extends Node
## Test headless du magasin réflexe à 3-4 joueurs (2 dispositifs) :
##  - les 2 cabines sont VERROUILLÉES à l'arrivée (porte fermée) ;
##  - la porte de sortie est FERMÉE à l'arrivée ;
##  - UNE épreuve réussie ne suffit PAS : la porte reste fermée tant que
##    l'autre dispositif n'a pas réussi ;
##  - les 2 épreuves réussies ouvrent la porte de sortie ;
##  - tant qu'UNE cabine est occupée, la porte se referme ;
##  - à la fin du rituel, elle se rouvre.
## Lancé : godot --headless res://tests/test_shop_4players_reflex.tscn
##
## Le rituel d'achat DANS la cabine est déjà couvert par test_cabine.tscn
## ; ici on simule seulement sa fin (etat = INERT), comme le fait le test
## du magasin course.

const SCENE := "res://scenes/niveaux/magasin/magasin_reflex/shop_4players_reflex.tscn"
const SORCIER := "res://scenes/entities/players/sorcerer.tscn"

var inst: Node
var cabine1: Cabin
var cabine2: Cabin
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
	cabine1 = inst.get_node("Pressureplate2Players/Cabine") as Cabin
	cabine2 = inst.get_node("Pressureplate2Players2/Cabine") as Cabin
	sorcier = load(SORCIER).instantiate()
	sorcier.controller_id = 0
	sorcier.position = Vector2(4000, 20)
	add_child(sorcier)
	sorcier.load_data()


## Pousse une paire de « plaqueurs » sur les 2 plaques d'un dispositif :
## les compteurs et les animations d'énergie font le reste (comme en jeu,
## cf. pressureplate_2players.gd). Les plaqueurs ne quittent jamais les
## plaques : l'épreuve réussit obligatoirement (one-shot ensuite).
func _faire_epreuve(dispositif: Node2D, plaqueur1: Sorcerer, plaqueur2: Sorcerer) -> void:
	dispositif._on_plate_body_entered(plaqueur1, "left")
	dispositif._on_plate_body_entered(plaqueur2, "right")


func _scenar() -> void:
	# --- Mise en place ---
	for i in 3:
		await get_tree().physics_frame
	_check(cabine1 != null and cabine1.verrouillee,
		"la 1re cabine est verrouillée à l'arrivée")
	_check(cabine2 != null and cabine2.verrouillee,
		"la 2e cabine est verrouillée à l'arrivée")
	var porte: Area2D = inst.get_node("ShopDoor")
	_check(not porte.is_playing() and not _zone_active(),
		"la porte de sortie est FERMÉE à l'arrivée")

	# --- 1re épreuve seule : la porte ne doit PAS s'ouvrir ---
	var s1: Sorcerer = load(SORCIER).instantiate()
	s1.controller_id = 0
	s1.position = Vector2(4000, 20)
	add_child(s1)
	var s2: Sorcerer = load(SORCIER).instantiate()
	s2.controller_id = 1
	s2.position = Vector2(4000, 20)
	add_child(s2)
	_faire_epreuve(inst.get_node("Pressureplate2Players"), s1, s2)

	var reussi1 := await _attendre(func() -> bool: return not cabine1.verrouillee, 1800)
	_check(reussi1, "l'épreuve du 1er dispositif déverrouille SA cabine")
	_check(cabine2.verrouillee,
		"la 2e cabine reste verrouillée (épreuve indépendante)")
	# La porte reste fermée : une épreuve manque.
	var pas_ouverte := await _attendre(_zone_active, 90)
	_check(not pas_ouverte, "UNE épreuve réussie ne suffit pas à ouvrir la porte de sortie")

	# --- 2e épreuve : les 2 dispositifs ont réussi → la porte s'ouvre ---
	_faire_epreuve(inst.get_node("Pressureplate2Players2"), s1, s2)
	var reussi2 := await _attendre(func() -> bool: return not cabine2.verrouillee, 1800)
	_check(reussi2, "l'épreuve du 2e dispositif déverrouille SA cabine")
	var ouverte := await _attendre(_zone_active, 600)
	_check(ouverte, "les 2 épreuves réussies ouvrent la porte de sortie")

	# --- Un rituel d'achat referme la porte, où qu'il ait lieu ---
	cabine2.entrer(sorcier)
	_check(cabine2.est_occupee(), "le sorcier occupe la 2e cabine")
	for i in 3:
		await get_tree().physics_frame
	_check(not _zone_active() and porte.frame == 0,
		"la porte de sortie SE REFERME tant qu'une cabine est occupée")
	for i in 30:
		await get_tree().physics_frame
	_check(not _zone_active(), "la porte reste fermée pendant le rituel")

	# --- Fin du rituel : la porte se rouvre ---
	sorcier.global_position = Vector2(4000, 20)
	cabine2.etat = Cabin.Etat.INERT
	_check(not cabine2.est_occupee(), "la cabine est libérée à la fin du rituel")
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
