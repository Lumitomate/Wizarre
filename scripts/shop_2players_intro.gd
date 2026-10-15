extends ShopIntroBase
## Magasin intro (1 ou 2 joueurs) : première salle de la partie, atteinte
## directement depuis la homepage (routage dans teleport_zone.gd).
## Toute la mécanique commune est héritée de ShopIntroBase ; ce script ne
## définit que la disposition à 2 couloirs (haut / bas) :
##  - Couloir haut = joueur 1, couloir bas = joueur 2 (tri par y des
##    portes, puis x — cf. sorcerer.gd).
##  - À 1 joueur : les cases (0,9)→(15,15) de la tilemap sont remplies de
##    blocs 1:1 (scellement du couloir bas : entrée, bulle 2, porte dieu 2
##    enterrées) ; l'objet de la bulle 2 n'existe pas ; le joueur seul
##    contourne le scellement par la droite et atteint la ShopDoor.

## Couloirs de la salle : 0 = haut, 1 = bas (disposition fixe des portes).
const COULOIR_HAUT := 0
const COULOIR_BAS := 1
## Zone scellée à 1 joueur : cases (0,9) → (15,15) de la tilemap.
const SCELLEMENT_DEBUT := Vector2i(0, 9)
const SCELLEMENT_FIN := Vector2i(15, 15)

## Remplacement anti-doublon en cours : le prochain objet sous la bulle 2
## est l'ancien (type doublon), il sera éliminé et respawné.
var _remplacement_bas_en_cours := false


func _ready() -> void:
	super._ready()


func _configurer_couloirs(nb_joueurs: int) -> void:
	# À 1 joueur (ou 0, garde-fou des tests headless) : seul le couloir
	# haut est actif, le couloir bas est scellé.
	if nb_joueurs >= 2:
		_couloirs_actifs = [COULOIR_HAUT, COULOIR_BAS]
	else:
		_couloirs_actifs = [COULOIR_HAUT]
		_sceller_zone(SCELLEMENT_DEBUT, SCELLEMENT_FIN)
		# L'objet de la bulle 2 a déjà été demandé (spawner exécuté avant
		# ce _ready, ajout différé) : il est éliminé dès son entrée dans
		# l'arbre — il resterait sinon prisonnier sous les blocs.
		$Bubble2.child_entered_tree.connect(_eliminer_objet_bulle2)


## À 1 joueur, tout objet qui entre sous la bulle 2 est éliminé : la salle
## scellée ne propose rien (règle validée : salle repliée, pas d'objet perdu).
func _eliminer_objet_bulle2(child: Node) -> void:
	if child is AttackObject:
		child.queue_free()


## Force la règle « pas de doublon » entre les 2 bulles : les spawners ont
## déjà choisi et mis en file leurs objets (leur _ready précède celui de
## la racine, et le spawner du bas ne voit pas le haut : parents
## différents). Si les deux types coïncident : le type du bas est re-tiré,
## l'objet en file (déjà instancié avec l'ANCIEN type et son sprite) est
## éliminé à son entrée dans l'arbre, et un objet neuf est respawné avec
## le bon type (spawn_object relit chosen_object_type).
func _coordonner_types_objets() -> void:
	var spawner_haut: Node = $Bubble/SpawnerObjet
	var spawner_bas: Node = $Bubble2/SpawnerObjet
	if "chosen_object_type" not in spawner_haut or "chosen_object_type" not in spawner_bas:
		return
	if spawner_haut.chosen_object_type != spawner_bas.chosen_object_type:
		return
	# Re-tirage du bas parmi les types restants (le haut garde le sien).
	var autres: Array = spawner_bas.PROPOSABLE_TYPES.filter(
		func(t: int) -> bool: return t != spawner_haut.chosen_object_type
	)
	spawner_bas.chosen_object_type = autres[randi() % autres.size()]
	# Premier objet entrant sous la bulle 2 = l'ancien : éliminé, remplacé.
	_remplacement_bas_en_cours = true
	if not spawner_bas.child_entered_tree.is_connected(_on_objet_bas_remplacement):
		spawner_bas.child_entered_tree.connect(_on_objet_bas_remplacement.bind(spawner_bas))


## Le premier objet entrant sous la bulle 2 pendant un remplacement est
## l'ancien (type doublon, déjà instancié avec son mauvais sprite) :
## éliminé, et un objet neuf est respawné avec le type re-tiré.
func _on_objet_bas_remplacement(child: Node, spawner_bas: Node) -> void:
	if not _remplacement_bas_en_cours or not (child is AttackObject):
		return
	_remplacement_bas_en_cours = false
	spawner_bas.child_entered_tree.disconnect(_on_objet_bas_remplacement)
	child.queue_free()
	spawner_bas.spawn_object()


## Bulle d'un couloir (0 = haut, 1 = bas).
func _bulle(couloir: int) -> Node2D:
	match couloir:
		COULOIR_HAUT:
			return $Bubble
		_:
			return $Bubble2


## Porte dieu d'un couloir (0 = haut, 1 = bas).
func _porte_dieu(couloir: int) -> Node:
	match couloir:
		COULOIR_HAUT:
			return $PorteMagasinEpreuve
		_:
			return $PorteMagasinEpreuve2
