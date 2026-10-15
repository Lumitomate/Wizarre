extends Node
## Régression de l'exploit « tuyaux soulevés par spam sur la homepage » :
## la fenêtre de cooldown après un tir (can_fire=false pendant 0,4 s)
## ouvrait la branche tubes_selectable de _process et un spam des
## boutons X/Y/B soulevait les tuyaux. Correctif : la config de spawn
## de la homepage ne définit PLUS tubes_selectable — les appuis ne
## font que tirer. Lancé comme scène :
## godot --headless res://tests/test_homepage_tubes.tscn

var step := 0
var page: Node2D


func _ready() -> void:
	# Simule une manette connectée AVANT le spawn (la homepage spawn ses
	# joueurs dans son _ready, déclenché par add_child ci-dessous)
	PlayerManager.known_controllers.assign([0])
	var scene: PackedScene = load("res://scenes/niveaux/terrain1/homepage.tscn")
	page = scene.instantiate()
	add_child(page)


func _physics_process(_delta: float) -> void:
	step += 1
	if step == 5:
		var ok := true
		var compte := 0
		for id in PlayerManager.active_player_ids():
			var player = PlayerManager.players.get(id)
			if player == null or not is_instance_valid(player):
				continue
			compte += 1
			if player.tubes_selectable:
				ok = false
			# Les autres règles de l'écran restent en place
			if not player.can_fire or not player.in_homepage:
				ok = false
		print("joueurs spawnés: ", compte, " (1 attendu)")
		print("tubes_selectable=false sur la homepage (exploit fermé): ", ok, " (true attendu)")
		print("can_fire et in_homepage intacts: ", ok, " (true attendu)")
		print("=== TEST TERMINÉ ===")
		get_tree().quit()
