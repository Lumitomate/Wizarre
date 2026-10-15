extends Node
## Test headless du flash de sélection des tubes : rayon créé au
##moment de la sortie d'un tube, couleur selon la famille du sort
## (feu → rouge, vide → blanc), pas de flash pour le sorcier d'affichage
## du pause, re-flash sur changement de tube. Lancé comme scène :
## godot --headless res://tests/test_flash_tube.tscn

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


func _flash_color() -> Color:
	return sac._flash.modulate if sac._flash != null else Color(-1, -1, -1, -1)


func _physics_process(_delta: float) -> void:
	step += 1
	if step == 3:
		# Tube 0 = feu (F1) → flash rouge attendu
		sorcier.spells[0] = {"attack_type": GlobalEnum.AttackType.F1, "attack_tier": 0}
		sac.select_tube(0)
		var c := _flash_color()
		print("flash tube feu: ", c, " (rouge ~#ff5544 attendu)")
	if step == 5:
		# Changement de tube : tube 1 VIDÉ explicitement (load_data le remplit
		# avec les sorts par défaut) → flash blanc, et le rayon est réutilisé
		sorcier.spells[1] = {}
		sac.select_tube(1)
		print("flash tube vide: ", _flash_color(), " (blanc 1,1,1,1 attendu)")
		print("rayon unique (réutilisé): ", sac._flash != null, " (true attendu)")
	if step == 7:
		# Refermeture (ré-appui sur le tube sorti) : PAS de nouveau flash —
		# vérifié structurellement : le tween du flash n'est PAS recréé
		var tween_avant: Tween = sac._flash_tween
		sac.select_tube(1)  # ré-appui → refermeture
		print("refermeture sans re-flash (tween inchangé): ",
			sac._flash_tween == tween_avant, " (true attendu)")
	if step == 9:
		# Sorcier d'affichage du pause (frozen) : aucun flash
		sorcier.frozen = true
		var avant := _flash_color().a
		sac.select_tube(2)
		print("flash en pause (frozen) bloqué: ", _flash_color().a == avant, " (true attendu)")
	if step == 11:
		# Table de couleurs : les 4 familles + vide
		var wp := WizardPalette
		print("F1→", wp.get_attack_family_color(GlobalEnum.AttackType.F1),
			" G3→", wp.get_attack_family_color(GlobalEnum.AttackType.G3),
			" L1→", wp.get_attack_family_color(GlobalEnum.AttackType.L1),
			" P2→", wp.get_attack_family_color(GlobalEnum.AttackType.P2),
			" vide→", wp.get_attack_family_color(-1))
		print("=== TEST TERMINÉ ===")
		get_tree().quit()
