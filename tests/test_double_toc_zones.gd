extends Node
## Régression « double-coup dans la colonne de feu / le rayon de lumière »
## (règle validée : être dans une zone du type protège d'un nouveau coup
## du même type ; sortir de toutes les zones lève la protection ;
## isolation par type d'attaque). Les coups sont observés via les VIES du
## sorcier (le vrai contrat). Lancé comme scène :
## godot --headless res://tests/test_double_toc_zones.tscn
##
## Scénario de régression inclu (le bug d'origine) : un projectile détruit
## ALORS QUE le corps est encore dans une AUTRE zone du même type ne doit
## PAS lever la protection de cette autre zone (sinon double-coup).

var step := 0
var echecs := 0
var sorcier: Sorcerer
var colonne1: AttackFireColumn
var colonne2: AttackFireColumn
var rayon1: AttackLightRay
var rayon2: AttackLightRay


func verifie(nom: String, ok: bool) -> void:
	if ok:
		print("OK: ", nom)
	else:
		echecs += 1
		print("ÉCHEC: ", nom)


func _ready() -> void:
	var sorc_scene: PackedScene = load("res://scenes/entities/players/sorcerer.tscn")
	sorcier = sorc_scene.instantiate()
	sorcier.controller_id = 0
	sorcier.load_data()
	add_child(sorcier)
	sorcier.global_position = Vector2(300, 300)
	var colonne_scene: PackedScene = load("res://scenes/atk/atk_f1_fire_column.tscn")
	colonne1 = colonne_scene.instantiate()
	colonne2 = colonne_scene.instantiate()
	add_child(colonne1)
	add_child(colonne2)
	colonne1.global_position = Vector2(300, 300)  # sur le joueur
	colonne2.global_position = Vector2(364, 300)  # 64 px plus loin (chaîne)
	var ray_scene: PackedScene = load("res://scenes/atk/atk_l1_light_ray.tscn")
	rayon1 = ray_scene.instantiate()
	rayon2 = ray_scene.instantiate()
	add_child(rayon1)
	add_child(rayon2)
	rayon1.global_position = Vector2(300, 300)
	rayon2.global_position = Vector2(364, 300)


func _physics_process(_delta: float) -> void:
	step += 1
	if step == 3:
		# Premier contact : le toc passe (lives 3 -> 2)
		verifie("1er contact autorisé (vies 3)",
			colonne1.can_damage(sorcier) and sorcier.lives == 3)
		colonne1._on_body_entered(sorcier)
		verifie("vies après 1er contact = 2", sorcier.lives == 2)
	if step == 5:
		# La 2e colonne de la chaîne chevauche le joueur : TOC BLOQUÉ
		verifie("2e colonne chevauchante : toc bloqué",
			not colonne2.can_damage(sorcier))
		colonne2._on_body_entered(sorcier)
		verifie("vies inchangées (pas de 2e toc)", sorcier.lives == 2)
	if step == 7:
		# Quitter la colonne 1 en restant dans la 2 : toujours protégé
		colonne1._on_body_exited(sorcier)
		verifie("sortie colonne1, toujours dans colonne2 : toc bloqué",
			not colonne2.can_damage(sorcier))
	if step == 8:
		# RÉGRESSION du double décompte : la colonne 1 meurt ALORS QUE le
		# sorcier est encore dans la colonne 2. Le nettoyage à la
		# destruction de la colonne 1 ne doit PAS décrémenter le compteur
		# de la colonne 2 (sinon protection levée trop tôt → double-coup).
		colonne1.queue_free()
	if step == 10:
		verifie("colonne1 détruite : protection de la colonne2 INTACTE",
			not colonne2.can_damage(sorcier))
	if step == 12:
		# Quitter la dernière colonne : protection levée, re-toc possible
		colonne2._on_body_exited(sorcier)
		verifie("sortie de tout le feu : toc de nouveau autorisé",
			colonne2.can_damage(sorcier))
	if step == 14:
		# Isolation par type : un rayon L1 n'est pas bloqué par le feu.
		# (Pas de vérification de vies ici : le sorcier est encore dans son
		# cooldown de dégâts depuis le 1er toc, la règle testée est celle de
		# la GARDE anti double-coup, pas celle du cooldown.)
		verifie("rayon L1 touche malgré le feu", rayon1.can_damage(sorcier))
		rayon1._on_body_entered(sorcier)
	if step == 16:
		# 2e rayon L1 chevauchant : bloqué (règle propre à la lumière)
		verifie("2e rayon L1 : toc bloqué", not rayon2.can_damage(sorcier))
		rayon2._on_body_entered(sorcier)
	if step == 18:
		# Sortie des deux rayons : protection lumière levée
		rayon1._on_body_exited(sorcier)
		rayon2._on_body_exited(sorcier)
		verifie("sortie de la lumière : toc de nouveau autorisé",
			rayon1.can_damage(sorcier))
		if echecs == 0:
			print("RESULT: PASS")
		else:
			print("RESULT: FAIL (%d)" % echecs)
		get_tree().quit(0 if echecs == 0 else 1)
