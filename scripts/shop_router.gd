extends Node
## Routage des magasins : pour chaque nombre de joueurs (1 à 4), liste des
## magasins possibles et leur poids de tirage. Tout se règle dans
## l'inspecteur (autoload ShopRouter) — plus aucun branchement en dur dans
## global.gd.
##
## Comment lire les poids : un poids est un multiplicateur, pas un
## pourcentage. Avec 3 magasins de poids 1, chacun sort 1 fois sur 3.
## Avec des poids 1 / 1 / 2, le troisième sort 1 fois sur 2. Un poids à 0
## désactive un magasin sans le retirer de la liste.
##
## Magasins disponibles (GlobalEnum.Location) :
##  - SHOP                : magasin classique (tubes à échanger, bulles)
##  - SHOP_2PLAYERS_REFLEX: épreuve de réflexe (2 joueurs)
##  - SHOP_2PLAYERS_RACE  : épreuve de course (2 joueurs, 2 couloirs)
##  - SHOP_4PLAYERS_RACE  : épreuve de course (3-4 joueurs, 1 couloir/joueur)
##  - SHOP_HANDS          : Shophands (3-4 joueurs, don d'un objet par le
##                          décideur, cf. docs/adr/0001-shophands.md)

@export_group("Magasin à 1 joueur")
## Magasins possibles quand la partie compte 1 joueur.
@export var magasins_1_joueur: Array[GlobalEnum.Location] = [
	GlobalEnum.Location.SHOP,
]
## Poids de tirage correspondants (même ordre que la liste ci-dessus).
@export var poids_1_joueur: Array[float] = [1.0]

@export_group("Magasin à 2 joueurs")
@export var magasins_2_joueurs: Array[GlobalEnum.Location] = [
	GlobalEnum.Location.SHOP,
	GlobalEnum.Location.SHOP_2PLAYERS_REFLEX,
	GlobalEnum.Location.SHOP_2PLAYERS_RACE,
]
@export var poids_2_joueurs: Array[float] = [1.0, 1.0, 1.0]

@export_group("Magasin à 3 joueurs")
@export var magasins_3_joueurs: Array[GlobalEnum.Location] = [
	GlobalEnum.Location.SHOP_HANDS,
]
@export var poids_3_joueurs: Array[float] = [1.0]

@export_group("Magasin à 4 joueurs")
@export var magasins_4_joueurs: Array[GlobalEnum.Location] = [
	GlobalEnum.Location.SHOP_HANDS,
]
@export var poids_4_joueurs: Array[float] = [1.0]


## Tire au hasard le magasin d'un passage, selon le nombre de joueurs de la
## partie et les poids réglés dans l'inspecteur.
func tirer_magasin(nb_joueurs: int) -> GlobalEnum.Location:
	var magasins: Array = []
	var poids: Array = []
	match nb_joueurs:
		1:
			magasins = magasins_1_joueur
			poids = poids_1_joueur
		2:
			magasins = magasins_2_joueurs
			poids = poids_2_joueurs
		3:
			magasins = magasins_3_joueurs
			poids = poids_3_joueurs
		_:
			# 4 joueurs et plus (garde-fou : MAX_PLAYERS vaut 4) et 0 joueur
			magasins = magasins_4_joueurs
			poids = poids_4_joueurs
	if magasins.is_empty():
		push_error("ShopRouter : aucun magasin configuré pour %d joueur(s), magasin classique" % nb_joueurs)
		return GlobalEnum.Location.SHOP
	var total := _somme_poids(poids, magasins.size())
	if total <= 0.0:
		push_error("ShopRouter : tous les poids sont nuls ou négatifs pour %d joueur(s), premier magasin de la liste" % nb_joueurs)
		return magasins[0]
	# Tirage pondéré : on tombe dans l'intervalle cumulé du magasin tiré.
	# Le reliquat d'arrondi (total fractionnaire) est attribué au DERNIER
	# magasin de la liste : 3 poids de 1/3 donnent exactement 1/3 chacun
	# (sinon le dernier sortirait un peu moins souvent que les autres).
	var roue := randf() * total
	for i in magasins.size():
		roue -= _poids_i(poids, i)
		if roue < 0.0:
			return magasins[i]
	return magasins[magasins.size() - 1]


## Poids de l'entrée i : hors liste (ou négatif) = 0. Le poids peut être
## un int ou un float dans l'inspecteur.
func _poids_i(poids: Array, i: int) -> float:
	if i >= poids.size():
		return 0.0
	return maxf(float(poids[i]), 0.0)


## Somme des poids des `nb_magasins` premières entrées.
func _somme_poids(poids: Array, nb_magasins: int) -> float:
	var total := 0.0
	for i in nb_magasins:
		total += _poids_i(poids, i)
	return total
