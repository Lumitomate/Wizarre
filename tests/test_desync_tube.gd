extends Node
## Test headless de la synchronisation selected_tube sorcier ↔ sac :
## un tube RABAISSÉ (ré-appui, ou fermeture après échange) doit remettre
## selected_tube du sorcier à -1 — sinon un objet serait attrapable dans
## un tube descendu (la règle d'attrapage en boutique teste le tube du
## sorcier). Lancé comme scène :
## godot --headless res://tests/test_desync_tube.tscn

var step := 0
var sorcier: Sorcerer
var sac: SorcererSac


func _ready() -> void:
	var sorc_scene: PackedScene = load("res://scenes/entities/players/sorcerer.tscn")
	sorcier = sorc_scene.instantiate()
	sorcier.controller_id = 0
	sorcier.load_data()
	add_child(sorcier)
	sac = sorcier.get_node("SorcererSac")


func _physics_process(_delta: float) -> void:
	step += 1
	if step == 2:
		# Soulève le tube 0 : les deux variables sont à 0
		sorcier.select_tube(0)
		print("tube 0 soulevé : sorcier=", sorcier.selected_tube, " sac=",
			sac.selected_tube, " (0 / 0 attendu)")
	if step == 4:
		# Ré-appui : le tube se RABAIT (anim reverse) — le sorcier doit
		# suivre (bug d'origine : sorcier.selected_tube restait à 0)
		sorcier.select_tube(0)
		print("tube 0 rabattu (ré-appui) : sorcier=", sorcier.selected_tube,
			" sac=", sac.selected_tube, " (-1 / -1 attendu)")
	if step == 6:
		# Changement de tube : le nouveau est à 0
		sorcier.select_tube(2)
		print("tube 2 soulevé : sorcier=", sorcier.selected_tube, " (2 attendu)")
	if step == 8:
		# Fermeture après échange (le sac rabaisse seul, après un délai
		# en jeu) : le sorcier doit suivre
		sac._close_tube_after_swap(2)
		print("tube 2 fermé après échange : sorcier=", sorcier.selected_tube,
			" sac=", sac.selected_tube, " (-1 / -1 attendu)")
	if step == 9:
		print("=== TEST TERMINÉ ===")
		get_tree().quit()