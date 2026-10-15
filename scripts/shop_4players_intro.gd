extends ShopIntroBase
## Magasin intro (3 ou 4 joueurs) : première salle de la partie pour les
## groupes de 3+, atteinte depuis la homepage (routage dans
## teleport_zone.gd). Toute la mécanique commune est héritée de
## ShopIntroBase ; ce script ne définit que la disposition à 4 couloirs :
##  - Couloirs : haut-gauche, haut-droite, bas-gauche, bas-droite — le
##    rang du joueur place le couloir via le tri (y, puis x) des portes
##    d'entrée (cf. sorcerer.gd), couloir inactif = toujours le dernier.
##  - À 3 joueurs (et tout < 4 : garde-fou des tests headless) : le
##    couloir bas-droite est SCELLÉ de blocs 1:1 — cases (18,10) →
##    (27,15) : porte d'entrée, bulle 4 et porte dieu 4 enterrées ;
##    l'objet de la bulle 4 n'existe pas (éliminé dès son entrée dans
##    l'arbre, règle « salle repliée, pas d'objet perdu »).

## Couloirs, dans l'ordre du tri (y, puis x) des portes d'entrée.
const COULOIR_HAUT_GAUCHE := 0
const COULOIR_HAUT_DROITE := 1
const COULOIR_BAS_GAUCHE := 2
const COULOIR_BAS_DROITE := 3
const TOUS_COULOIRS: Array[int] = [
	COULOIR_HAUT_GAUCHE, COULOIR_HAUT_DROITE, COULOIR_BAS_GAUCHE, COULOIR_BAS_DROITE,
]
## Zone scellée à 3 joueurs : cases (18,10) → (27,15) — couloir
## bas-droite (zone validée avec le propriétaire).
const SCELLEMENT_DEBUT := Vector2i(18, 10)
const SCELLEMENT_FIN := Vector2i(27, 15)

## {couloir: Callable} remplacements anti-doublon en cours : le prochain
## objet entrant sous la bulle du couloir est l'ancien (type modifié),
## à éliminer et respawné. Le Callable stocké est celui à déconnecter.
var _remplacements_en_cours: Dictionary = {}


func _ready() -> void:
	super._ready()


func _configurer_couloirs(nb_joueurs: int) -> void:
	# Garde-fou (règle validée) : 4 joueurs ou plus → 4 couloirs actifs ;
	# moins de 4 (3 en jeu, 0-2 en tests headless) → 3 couloirs actifs,
	# le couloir bas-droite (toujours le dernier au tri (y, x)) est
	# scellé et muet.
	if nb_joueurs >= 4:
		_couloirs_actifs = TOUS_COULOIRS.duplicate()
	else:
		_couloirs_actifs = [
			COULOIR_HAUT_GAUCHE, COULOIR_HAUT_DROITE, COULOIR_BAS_GAUCHE,
		]
		_sceller_zone(SCELLEMENT_DEBUT, SCELLEMENT_FIN)
		# L'objet de la bulle 4 a déjà été demandé (spawner exécuté avant
		# ce _ready, ajout différé) : il est éliminé dès son entrée dans
		# l'arbre — il resterait sinon prisonnier sous les blocs.
		$Bubble4.child_entered_tree.connect(_eliminer_objet_bulle4)


## À 3 joueurs, tout objet qui entre sous la bulle 4 est éliminé : la
## salle scellée ne propose rien (règle validée : salle repliée, pas
## d'objet perdu).
func _eliminer_objet_bulle4(child: Node) -> void:
	if child is AttackObject:
		child.queue_free()


## Règle « jamais deux fois le même type » à 3-4 bulles : l'hôte tire
## d'un coup autant de types DISTINCTS qu'il y a de couloirs actifs
## (12 types proposables, marge large) et les assigne aux spawners. Un
## spawner dont le type change voit son objet déjà instancié (avec
## l'ANCIEN type et son sprite) éliminé à son entrée dans l'arbre, et
## un objet neuf respawné (spawn_object relit chosen_object_type).
func _coordonner_types_objets() -> void:
	if _couloirs_actifs.is_empty():
		return
	var premier_spawner: Node = _spawner(_couloirs_actifs[0])
	if "PROPOSABLE_TYPES" not in premier_spawner \
			or "chosen_object_type" not in premier_spawner:
		return
	var pool: Array = premier_spawner.PROPOSABLE_TYPES.duplicate()
	pool.shuffle()
	for i in _couloirs_actifs.size():
		var couloir: int = _couloirs_actifs[i]
		var spawner: Node = _spawner(couloir)
		var type_cible = pool[i]
		if spawner.chosen_object_type == type_cible:
			continue
		spawner.chosen_object_type = type_cible
		# Premier objet entrant sous cette bulle = l'ancien : éliminé,
		# remplacé. Le Callable est stocké pour être déconnecté proprement
		# (connect() avec un callable bindé, disconnect() avec le même).
		var callable: Callable = _on_objet_remplace.bind(spawner, couloir)
		_remplacements_en_cours[couloir] = callable
		spawner.child_entered_tree.connect(callable)


## Le premier objet entrant sous une bulle en remplacement est l'ancien
## (type doublon, déjà instancié avec son mauvais sprite) : éliminé, et
## un objet neuf est respawné avec le type re-assigné.
func _on_objet_remplace(child: Node, spawner: Node, couloir: int) -> void:
	if not _remplacements_en_cours.has(couloir) or not (child is AttackObject):
		return
	var callable: Callable = _remplacements_en_cours[couloir]
	_remplacements_en_cours.erase(couloir)
	spawner.child_entered_tree.disconnect(callable)
	child.queue_free()
	spawner.spawn_object()


## Porte dieu d'un couloir (0 = haut-gauche, 1 = haut-droite,
## 2 = bas-gauche, 3 = bas-droite).
func _porte_dieu(couloir: int) -> Node:
	match couloir:
		COULOIR_HAUT_GAUCHE:
			return $PorteMagasinEpreuve
		COULOIR_HAUT_DROITE:
			return $PorteMagasinEpreuve3
		COULOIR_BAS_GAUCHE:
			return $PorteMagasinEpreuve2
		_:
			return $PorteMagasinEpreuve4


## Bulle d'un couloir (même ordre que _porte_dieu).
func _bulle(couloir: int) -> Node2D:
	match couloir:
		COULOIR_HAUT_GAUCHE:
			return $Bubble
		COULOIR_HAUT_DROITE:
			return $Bubble3
		COULOIR_BAS_GAUCHE:
			return $Bubble2
		_:
			return $Bubble4


## Spawner d'une bulle (même ordre que _porte_dieu).
func _spawner(couloir: int) -> Node:
	return _bulle(couloir).get_node("SpawnerObjet")
