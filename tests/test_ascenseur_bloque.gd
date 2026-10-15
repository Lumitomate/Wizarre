extends Node
## Test headless du blocage de l'ascenseur à la remontée : un joueur
## plaqué par le toit (détecté par la vraie requête physique de la zone
## d'écrasement) → arrêt, micro-pause, descente à l'envers → cycle
## complet (AU_BAS + grâce) ; et remontée sereine quand personne ne
## bloque. Lancé comme scène : godot --headless res://tests/test_ascenseur_bloque.tscn

var step := 0
var ascenseur: Node2D
var sorcier: Sorcerer
var anim_player: AnimationPlayer


func _ready() -> void:
	var scene: PackedScene = load("res://scenes/niveaux/terrain1/map1_elevator.tscn")
	ascenseur = scene.instantiate()
	add_child(ascenseur)
	anim_player = ascenseur.get_node("AnimatableBody2D/AnimationPlayer")
	var sorc_scene: PackedScene = load("res://scenes/entities/players/sorcerer.tscn")
	sorcier = sorc_scene.instantiate()
	sorcier.controller_id = 0
	sorcier.load_data()
	add_child(sorcier)
	sorcier.global_position = Vector2(400, 400)
	# Simule une manette connectée (cf. test_ascenseur)
	PlayerManager.known_controllers.assign([0])


func avancer_jusqu_a_fin_anim() -> void:
	# Simule la fin réelle de l'anim de mouvement (le vrai signal
	# animation_finished n'arrive qu'à la fin des 3 s de l'anim)
	anim_player.pause()
	anim_player.seek(anim_player.get_animation(&"ascenseur_mouv_descente").length, true)


func _physics_process(_delta: float) -> void:
	step += 1
	if step == 3:
		ascenseur._on_area_2d_body_entered(sorcier)
	if step == 5:
		ascenseur.animated_sprite_2D.frame = ascenseur.NUMBER_OF_FRAME_ELEVATOR
		ascenseur._on_animated_sprite_2d_frame_changed()
		print("descente lancée: ", str(ascenseur._etat) == "1", " (DESCENTE attendu)")
	if step == 7:
		avancer_jusqu_a_fin_anim()
		ascenseur._on_mouvement_termine(&"ascenseur_mouv_descente")
		print("en bas: ", str(ascenseur._etat) == "2", " (AU_BAS attendu)")
	if step == 9:
		ascenseur._on_delai_grace_timeout()
		print("remontée lancée: ", str(ascenseur._etat) == "3", " (REMONTEE attendu)")
	if step == 11:
		# Joueur plaqué : positionné dans la zone d'écrasement (juste
		# au-dessus du toit, qui suit la cabine remontante)
		sorcier.global_position = ascenseur.get_node("AnimatableBody2D").global_position \
			+ Vector2(0, -98)
	if step == 20:
		print("blocage détecté: ", ascenseur._remontee_bloquee, " (true attendu)")
		print("animations en pause: ", not anim_player.is_playing(), " (true attendu)")
	if step == 45:
		# Après la micro-pause de 0,25 s : lecture EN AVANT reprise
		# (descente de secours depuis la position courante). NB : s'il
		# restait très peu d'anim avant la fin réelle, elle peut déjà
		# être achevée ici — le cycle complet à l'étape 60 en fait foi.
		print("descente de secours relancée (fin réelle atteinte): ",
			str(ascenseur._etat) == "2" or anim_player.is_playing(), " (true attendu)")
	if step == 60:
		# L'anim de mouvement s'est achevée pour de vrai EN BAS (signal
		# réel) → cycle complet : AU_BAS + délai de grâce
		print("cycle complet après blocage: ", str(ascenseur._etat) == "2",
			" (AU_BAS attendu) | grâce: ",
			not ascenseur.get_node("AnimatableBody2D/Timer").is_stopped())
		print("marqueur bloqué réarmé: ", not ascenseur._remontee_bloquee, " (true attendu)")
	if step == 100:
		# Nouvelle tentative, cette fois sans personne dans la cage
		# (avant que le timer de grâce ne tire pour de vrai)
		sorcier.global_position = Vector2(600, 600)
	if step == 140:
		print("remontée relancée (grâce tirée pour de vrai): ", str(ascenseur._etat) == "3",
			" (REMONTEE attendu)")
	if step == 200:
		print("remontée sereine (pas de faux blocage): ", str(ascenseur._etat) == "3"
			and not ascenseur._remontee_bloquee, " (true attendu)")
		print("=== TEST TERMINÉ ===")
		get_tree().quit()
