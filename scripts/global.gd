extends Node

var current_scene = null
# Garde anti double-appel : deux signaux qui déclencheraient un
# changement de scène dans la même fenêtre (ex : fondu de sortie fini
# juste avant le free de la scène) ne doivent déclencher qu'un seul
# changement. Réarmé une fois la nouvelle scène en place.
var _scene_change_in_progress: bool = false

var scenes = {
	GlobalEnum.Location.HOMEPAGE: "res://scenes/niveaux/terrain1/homepage.tscn",
	GlobalEnum.Location.LEVEL: "res://scenes/niveaux/terrain1/level.tscn",
	GlobalEnum.Location.SHOP: "res://scenes/niveaux/magasin/magasin_classique/shop.tscn",
	GlobalEnum.Location.SHOP_2PLAYERS_REFLEX: "res://scenes/niveaux/magasin/magasin_reflex/shop_2players_reflex.tscn",
	GlobalEnum.Location.SHOP_2PLAYERS_RACE: "res://scenes/niveaux/magasin/magasin_course/shop_2players_race.tscn",
	GlobalEnum.Location.SHOP_4PLAYERS_RACE: "res://scenes/niveaux/magasin/magasin_course/shop_4players_race.tscn",
	GlobalEnum.Location.SHOP_HANDS: "res://scenes/niveaux/magasin/magasin_don/shop_hands.tscn",
	GlobalEnum.Location.SHOP_2PLAYERS_INTRO: "res://scenes/niveaux/magasin/magasin_intro/shop_2players_intro.tscn",
	GlobalEnum.Location.SHOP_4PLAYERS_INTRO: "res://scenes/niveaux/magasin/magasin_intro/shop_4players_intro.tscn",
	GlobalEnum.Location.SHOP_GAMBLING: "res://scenes/niveaux/magasin/magasin_casino/shop_gambling.tscn",
	GlobalEnum.Location.BOSS_FIGHT: "res://scenes/niveaux/terrain1/boss_fight.tscn",
	GlobalEnum.Location.SHOP_4PLAYERS_REFLEX: "res://scenes/niveaux/magasin/magasin_reflex/shop_4players_reflex.tscn",
}

func _ready() -> void:
	var root = get_tree().root
	current_scene = root.get_child(-1)

func goto_scene(scene: GlobalEnum.Location) -> void:
	if _scene_change_in_progress:
		return
	_scene_change_in_progress = true
	# Le magasin est tiré au sort selon le nombre de joueurs et les poids
	# réglés dans l'autoload ShopRouter (inspecteur) : magasin classique,
	# réflexe, course ou Shophands — cf. scripts/shop_router.gd
	if scene == GlobalEnum.Location.SHOP:
		scene = ShopRouter.tirer_magasin(PlayerManager.game_players.size())
	scene = _redirection_boss(scene)
	if scene == GlobalEnum.Location.HOMEPAGE:
		# Retour sur Home : la partie précédente est terminée. Toutes les
		# manettes connectées pourront créer des joueurs à la prochaine partie
		PlayerManager.end_game()
		PauseManager.force_resume()
	elif not PlayerManager.game_active:
		# Départ de Home : le nombre de joueurs est figé à ce moment
		PlayerManager.start_game()
	PlayerManager.save_players_data()
	_deferred_goto_scene.call_deferred(scenes[scene])

## Redirection de fin de magasin : la salle du boss suit le magasin qui
## vient après la 4e vague affichée à l'écran ("IV" — vague 3 en
## numérotation interne, d'où level_number == 4 ici : l'incrément de fin
## de niveau a déjà eu lieu). L'incrément supplémentaire (4 → 5) empêche
## de retomber sur le boss au magasin suivant : la vague d'après
## redevient un niveau classique (elle affiche VI).
## Fonction pure isolée pour être testable headless — cf.
## tests/test_parcours.tscn.
func _redirection_boss(scene: GlobalEnum.Location) -> GlobalEnum.Location:
	if scene != GlobalEnum.Location.LEVEL:
		return scene
	if Run.wave_number() != 4:
		return scene
	Run.consume_boss_slot()
	return GlobalEnum.Location.BOSS_FIGHT


func _deferred_goto_scene(path: String) -> void:
	current_scene.free()
	
	var s = ResourceLoader.load(path)
	
	current_scene = s.instantiate()
	
	get_tree().root.add_child(current_scene)
	
	get_tree().current_scene = current_scene
	_scene_change_in_progress = false
