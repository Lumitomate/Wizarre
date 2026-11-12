extends Node2D

## Outil d'inspection manuel (la CI ne le lance pas) : reproduit UN VRAI
## KILL — une attaque de glace (G2) tue un ennemi 2 vies. Capture des
## screenshots à des instants réels pour voir ce qui est affiché à l'écran
## : l'explosion d'impact (remappée en bleu) ET l'éclatement de mort
## (EnemyDeathBurst : morceaux + gouttes de sang rose/rouge). Permet de
## distinguer ce qui est réellement rouge à l'écran.
## Lancer FENÊTRÉ : godot res://tests/_check_kill_render.tscn

const CAPTURES := [0.1, 0.3, 0.6, 0.9]


func _ready() -> void:
	var fond := ColorRect.new()
	fond.color = Color(0.1, 0.1, 0.15)
	fond.size = Vector2(1280, 720)
	add_child(fond)

	var holder := Node2D.new()
	add_child(holder)

	# Vrai ennemi 2 vies au centre
	var ennemi: EnemyFlying = (load("res://scenes/entities/ennemies/enemy_2lifes.tscn") as PackedScene).instantiate()
	ennemi.position = Vector2(640, 360)
	holder.add_child(ennemi)
	await get_tree().process_frame

	# Vraie attaque G2 (nœud origine, pas besoin de l'ajouter à l'arbre)
	var noeuds := AttackSpawner.spawn_attack(GlobalEnum.AttackType.G2,
		GlobalEnum.AttackTier.I, Vector2(600, 360), Vector2.RIGHT,
		Vector2(1280, 720), Vector2(2, 2), null)
	var origin: Node2D = noeuds[0] if noeuds.size() > 0 else null

	# Coup fatal
	ennemi.hit(2, null, origin)
	print("coup fatal porté")

	var debut_ms := Time.get_ticks_msec()
	for instant: float in CAPTURES:
		while Time.get_ticks_msec() - debut_ms < instant * 1000.0:
			await get_tree().process_frame
		await get_tree().process_frame
		var chemin := "res://tests/_capture_kill_%.1f.png" % instant
		get_viewport().get_texture().get_image().save_png(chemin)
		print("capture %s (t réel %.2f s)" % [chemin,
			float(Time.get_ticks_msec() - debut_ms) / 1000.0])

	get_tree().quit(0)
