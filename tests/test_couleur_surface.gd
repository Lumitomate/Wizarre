extends Node
## Test headless de l'échantillonnage de la couleur de surface par la
## fumée : mini-tileset fabriqué par code (tuile verte, tuile rouge),
## vérification que la couleur de fumée = moyenne de la tuile mélangée
## au blanc (POUSSIERE_TEINTE_MIX), repli blanc hors tuile, et que les
## particules spawnées portent bien la teinte. Lancé comme scène :
## godot --headless res://tests/test_couleur_surface.tscn

var sorcier: Sorcerer
var tilemap: TileMapLayer


func _ready() -> void:
	# Mini-tileset par code : texture 64×32, deux tuiles 32×32 unies
	# (verte à gauche, rouge à droite)
	var img := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0, 0, 32, 32), Color(0, 1, 0))
	img.fill_rect(Rect2i(32, 0, 32, 32), Color(1, 0, 0))
	var texture := ImageTexture.create_from_image(img)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(32, 32)
	source.create_tile(Vector2i(0, 0))
	source.create_tile(Vector2i(1, 0))
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(32, 32)
	tileset.add_source(source, 0)
	tilemap = TileMapLayer.new()
	tilemap.tile_set = tileset
	add_child(tilemap)
	tilemap.set_cell(Vector2i(0, 0), 0, Vector2i(0, 0))  # verte
	tilemap.set_cell(Vector2i(1, 0), 0, Vector2i(1, 0))  # rouge

	var scene: PackedScene = load("res://scenes/entities/players/sorcerer.tscn")
	sorcier = scene.instantiate()
	sorcier.controller_id = 0
	sorcier.load_data()
	add_child(sorcier)

	# Centre de la tuile verte (cellule (0,0) → local 16,16, tilemap à l'origine)
	var centre_vert := tilemap.to_global(Vector2(16, 16))
	# Centre de la tuile rouge
	var centre_rouge := tilemap.to_global(Vector2(48, 16))
	# Point sans aucune tuile
	var centre_vide := Vector2(5000, 5000)

	var attendu_vert := Color(0, 1, 0).lerp(Color.WHITE, Sorcerer.POUSSIERE_TEINTE_MIX)
	var attendu_rouge := Color(1, 0, 0).lerp(Color.WHITE, Sorcerer.POUSSIERE_TEINTE_MIX)
	var c := sorcier._couleur_surface(centre_vert)
	print("surface verte → teinte: ", c, " (~", attendu_vert, " attendu): ",
		c.is_equal_approx(attendu_vert), " (true attendu)")
	c = sorcier._couleur_surface(centre_rouge)
	print("surface rouge → teinte: ", c, " (~", attendu_rouge, " attendu): ",
		c.is_equal_approx(attendu_rouge), " (true attendu)")
	c = sorcier._couleur_surface(centre_vide)
	print("hors tuile → repli blanc: ", c == Color.WHITE, " (true attendu)")

	# Les particules spawnées sur la tuile verte portent la teinte : le
	# vert domine toujours rouge et bleu, quelle que soit la nuance tirée
	sorcier.spawn_poussiere(centre_vert, Vector2.UP, Sorcerer.POUSSIERE_VITESSE_MAX)
	var teintee := false
	for enfant in sorcier.get_parent().get_children():
		if enfant is Sprite2D and enfant.has_meta("poussiere"):
			var m: Color = enfant.modulate
			teintee = m.g > m.r and m.g > m.b
	print("particules teintées par le sol (vert dominant): ", teintee, " (true attendu)")
	print("=== TEST TERMINÉ ===")
	get_tree().quit()