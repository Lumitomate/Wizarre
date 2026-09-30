extends Node

var current_scene = null

var scenes = {
	GlobalEnum.Location.HOMEPAGE: "res://scenes/niveaux/terrain1/homepage.tscn",
	GlobalEnum.Location.LEVEL: "res://scenes/niveaux/terrain1/level.tscn",
	GlobalEnum.Location.SHOP: "res://scenes/niveaux/magasin/shop.tscn",
	GlobalEnum.Location.SHOP_2PLAYERS_REFLEX: "res://scenes/niveaux/magasin/magasin_reflex/shop_2players_reflex.tscn",
	GlobalEnum.Location.SHOP_2PLAYERS_RACE: "res://scenes/niveaux/magasin/magasin_course/shop_2players_race.tscn",
	GlobalEnum.Location.SHOP_4PLAYERS_RACE: "res://scenes/niveaux/magasin/magasin_course/shop_4players_race.tscn",
	GlobalEnum.Location.SHOP_HANDS: "res://scenes/niveaux/magasin/magasin_don/shop_hands.tscn"
}

func _ready() -> void:
	var root = get_tree().root
	current_scene = root.get_child(-1)

func goto_scene(scene: GlobalEnum.Location) -> void:
	# Le magasin est tiré au sort selon le nombre de joueurs et les poids
	# réglés dans l'autoload ShopRouter (inspecteur) : magasin classique,
	# réflexe, course ou Shophands — cf. scripts/shop_router.gd
	if scene == GlobalEnum.Location.SHOP:
		scene = ShopRouter.tirer_magasin(PlayerManager.game_players.size())
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

func _deferred_goto_scene(path: String) -> void:
	current_scene.free()
	
	var s = ResourceLoader.load(path)
	
	current_scene = s.instantiate()
	
	get_tree().root.add_child(current_scene)
	
	get_tree().current_scene = current_scene
