class_name CorridorLayoutGenerator
extends RefCounted

## Génération procédurale d'un layout d'obstacles pour les couloirs des
## magasins à 2 joueurs (courses). Le layout fait LARGEUR×HAUTEUR tuiles en
## coordonnées locales au couloir, et est appliqué à l'IDENTIQUE dans les
## deux couloirs pour que les 2 joueurs aient exactement le même parcours.
##
## HYPOTHÈSES DE JEU (données du gameplay) :
## - le sorcier tient dans 1 tuile (collider ≈ 42 px affichés ≤ 1 tuile) ;
## - il peut monter n'importe quelle hauteur (sut tenu, le saut monte très
##   haut) → aucun pilier ne le bloque par la hauteur ;
## - il peut se faufiler dans les passages de 1 tuile de haut.
##
## GARANTIE DU CHEMIN GAUCHE → DROITE :
## chaque layout est validé par un BFS sur les cases libres du couloir
## (4-connexité) : s'il existe un chemin de cases vides reliant le bord
## gauche au bord droit, le sorcier peut le suivre (il saute/escalade
## n'importe quelle hauteur). Sinon le layout est régénéré (MAX_ESSAIS) et,
## en dernier recours, un layout vide (toujours praticable) est rendu.
##
## LE PIÈGE À MARCHE ARRIÈRE (toujours présent, 1 par couloir) :
## un tunnel de 1 tuile de haut creusé au niveau du sol sous un couvercle de
## tuiles pleines, bouché à son extrémité droite par un mur de 2 tuiles.
## Le sorcier qui court le long du sol s'y engouffre, se retrouve face au
## mur → il est OBLIGÉ de revenir vers la gauche pour ressortir du tunnel,
## puis de sauter PAR-DESSUS le couvercle (il peut monter n'importe quelle
## hauteur) pour continuer vers la droite. D'où le trajet droite → gauche
## voulu. Comme le couvercle est plein (pas one-way), impossible de le
## traverser autrement.

## Dimensions par défaut (magasin course 2 joueurs : couloirs 17×4).
## Les variantes (magasin course 4 joueurs : zones 6×5) passent leurs
## dimensions en paramètre de generer().
const LARGEUR := 17
const HAUTEUR := 4
const MAX_ESSAIS := 100

## Terrain "Purple Brick" du TileSet : index du terrain set et du terrain.
## L'autotiling choisit lui-même les tuiles de l'atlas (dont la tuile
## centrale 1:1) selon les voisines de chaque cellule posée.
const TERRAIN_SET := 0
const TERRAIN := 0


## Génère un layout : Array de HAUTEUR lignes de LARGEUR booléens
## (true = tuile d'obstacle).
static func generer(rng: RandomNumberGenerator, largeur: int = LARGEUR, hauteur: int = HAUTEUR) -> Array:
	for essai in MAX_ESSAIS:
		var layout := _generer_aleatoire(rng, largeur, hauteur)
		if _chemin_existe(layout, largeur, hauteur):
			return layout
	# Sécurité : après MAX_ESSAIS, layout vide (toujours praticable)
	var vide: Array = []
	for y in hauteur:
		var ligne: Array = []
		for x in largeur:
			ligne.append(false)
		vide.append(ligne)
	return vide


## Tirage d'un couloir : le piège à marche arrière (toujours présent) puis
## piliers, stalactites et blocs volants sur le reste du couloir.
static func _generer_aleatoire(rng: RandomNumberGenerator, largeur: int, hauteur: int) -> Array:
	var layout: Array = []
	for y in hauteur:
		var ligne: Array = []
		for x in largeur:
			ligne.append(false)
		layout.append(ligne)

	# --- LE PIÈGE : tunnel de 1 tuile bouché à droite ---
	# Colonnes j..j+2 : couvercle plein (rangée HAUTEUR-2), tunnel libre en
	# dessous (rangée HAUTEUR-1, juste au-dessus du sol) ; colonne j+3 : mur
	# de 2 tuiles qui bouche le tunnel. Le sorcier entre dans le tunnel, se
	# retrouve face au mur, et doit revenir vers la gauche ; il passe ensuite
	# PAR-DESSUS le couvercle (montée possible : n'importe quelle hauteur)
	# et continue par le dessus.
	# En couloir court (6 colonnes), la plage largeur-6 est vide : le piège
	# se colle alors à gauche (j = 1, couvre 1-3, mur 4, col 5 libre).
	var j_max := largeur - 6
	var j: int = rng.randi_range(1, j_max) if j_max >= 1 else 1
	for x in range(j, j + 3):
		layout[hauteur - 2][x] = true
	layout[hauteur - 2][j + 3] = true
	layout[hauteur - 1][j + 3] = true

	# --- Piliers et éléments suspendus sur le reste du couloir ---
	var hauteur_precedente := 0
	for x in largeur:
		if x >= j - 1 and x <= j + 3:
			# colonnes du piège (et son entrée) : déjà gérées ci-dessus ;
			# l'entrée du tunnel (j-1) doit rester au niveau du sol
			hauteur_precedente = hauteur - 2 if x == j + 3 else 0
			continue

		# Pilier : hauteur 0..3 (le sorcier monte tout, donc pas de
		# contrainte de dénivelé entre colonnes)
		var h: int = [0, 0, 1, 1, 2, 3][rng.randi() % 6]
		for k in h:
			layout[hauteur - 1 - k][x] = true
		hauteur_precedente = h

		# --- Élément suspendu : stalactite ou bloc volant ---
		# Valide seulement si ≥ 1 tuile de passage reste entre l'élément
		# suspendu et le dessus du pilier (le sorcier fait 1 tuile).
		# Ligne du dessus du pilier : hauteur-h (h ≥ 1) ou hauteur (sol, h = 0).
		var sommet: int = hauteur - h
		var options: Array = ["rien", "rien"]
		if sommet >= 2:
			options.append("stalactite1")     # occupe la ligne 0
		if sommet >= 3:
			options.append("stalactite2")     # occupe les lignes 0 et 1
		if sommet >= 2:
			options.append("volant_haut")     # bloc sur la ligne 0
		if sommet >= 3:
			options.append("volant_bas")      # bloc sur la ligne 1
		var choix: String = options[rng.randi() % options.size()]
		match choix:
			"stalactite1":
				layout[0][x] = true
			"stalactite2":
				layout[0][x] = true
				layout[1][x] = true
			"volant_haut":
				layout[0][x] = true
			"volant_bas":
				layout[1][x] = true
	return layout


## Vérification : existe-t-il un chemin praticable gauche → droite ?
## Avec un sorcier de 1 tuile de haut qui grimpe partout, toute case libre
## est praticable ; les arêtes sont les déplacements 4-directionnels
## (monter = saut, descendre = chute libre). BFS simple.
static func _chemin_existe(layout: Array, largeur: int, hauteur: int) -> bool:
	var file: Array = []
	var vus: Array = []
	for y in hauteur:
		var ligne: Array = []
		for x in largeur:
			ligne.append(false)
		vus.append(ligne)
	for y in hauteur:
		if not layout[y][0]:
			file.append(Vector2i(0, y))
			vus[y][0] = true
	while not file.is_empty():
		var pos: Vector2i = file.pop_back()
		if pos.x == largeur - 1:
			return true
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var voisin: Vector2i = pos + dir
			if voisin.x < 0 or voisin.x >= largeur or voisin.y < 0 or voisin.y >= hauteur:
				continue
			if not vus[voisin.y][voisin.x] and not layout[voisin.y][voisin.x]:
				vus[voisin.y][voisin.x] = true
				file.append(voisin)
	return false


## Vide la zone du couloir (au cas où des tuiles traîneraient) puis applique
## le layout : origin = coin haut-gauche du couloir en coords de TileMap.
## Les obstacles sont posés via l'autotiling du terrain "Purple Brick"
## (set_cells_terrain_connect) pour que chaque brique ait les raccords
## visuels (bords, coins) selon ses voisines. Un appel unique pour tout le
## couloir : set_cells_terrain_connect est coûteuse.
static func appliquer(tilemap: TileMapLayer, origin: Vector2i, layout: Array) -> void:
	var cellules_obstacles: Array[Vector2i] = []
	for y in layout.size():
		for x in layout[y].size():
			var cellule := Vector2i(origin.x + x, origin.y + y)
			tilemap.erase_cell(cellule)
			if layout[y][x]:
				cellules_obstacles.append(cellule)
	if not cellules_obstacles.is_empty():
		tilemap.set_cells_terrain_connect(cellules_obstacles, TERRAIN_SET, TERRAIN)