class_name WarmupRendu
extends Node2D

## ═══════════════════════════════════════════════════════════════════════
##  ÉCHAUFFEMENT DU RENDU — anti-micro-freezes à la première utilisation
## ═══════════════════════════════════════════════════════════════════════
##  Le jeu tourne en gl_compatibility (choix web) : dans ce mode, il
##  n'existe AUCUNE précompilation de shaders — chaque matériau/shader est
##  compilé par le GPU à sa PREMIÈRE utilisation à l'écran. D'où des
##  micro-freezes en plein gameplay : première attaque de chaque type,
##  première explosion d'impact, particules des salles (torchesc, fumée
##  des spawners), textures chargées à la volée…
##
##  La seule parade en Compatibility (cf. doc Godot) : montrer chaque
##  matériau DANS LE CHAMP DE LA CAMÉRA au moins une frame pendant un
##  moment non jouable. Ici : sur l'écran-titre, derrière l'interface
##  (z_index très bas, l'écran home est opaque), toutes les attaques des
##  13 types (tier I, spawné par le vrai AttackSpawner), une explosion
##  d'impact (shader de recolorisation + halo + étincelles + les 35
##  textures de particules), la torchèche et le spawner de munitions
##  (GPUParticles2D des salles).
##
##  Tout est spawné avec process_mode DISABLED : rien ne bouge, ne
##  vieillit, ne tire — seule la PREMIÈRE FRAME DE RENDU compte. Le
##  tout est libéré après quelques frames. Inactif en headless (aucun
##  rendu, et les tests CI de la homepage ne doivent rien voir).
## ═══════════════════════════════════════════════════════════════════════

const FRAMES_AVANT_LIBERATION := 3

## Scènes à matériaux propres, présentes dans les salles (GPUParticles2D).
const SCENES_SALLES := [
	"res://scenes/decoration/torch.tscn",
	"res://scenes/spawner_ammo.tscn",
]


static func lancer(parent: Node) -> void:
	# Headless : aucun rendu → l'échauffement n'a aucun objet, et les
	# tests CI qui montent la homepage ne doivent rien voir apparaître.
	if DisplayServer.get_name() == "headless":
		return
	var warmup := WarmupRendu.new()
	warmup.z_index = -100  # derrière l'écran-titre (opaque) : invisible
	parent.add_child(warmup)


func _ready() -> void:
	_spawner_attaques()
	_spawner_effets_salles()
	_spawner_explosion_impact()
	# Les process sont coupés APRÈS l'ajout des enfants : les _ready ont
	# tourné (animations armées, matériaux en place) mais rien n'évolue —
	# seule la frame de rendu compte pour la compilation des shaders.
	process_mode = Node.PROCESS_MODE_DISABLED
	_liberer_apres_couverture()


func _liberer_apres_couverture() -> void:
	for i in FRAMES_AVANT_LIBERATION:
		await get_tree().process_frame
	queue_free()


## Les 13 attaques, spawnées par le vrai AttackSpawner (les mêmes nœuds
## qu'en jeu, mêmes matériaux), posées en grille dans le champ caméra.
func _spawner_attaques() -> void:
	var zone := get_viewport_rect().size
	var colonnes := 7
	var types := GlobalEnum.AttackType.values()
	for i in types.size():
		var position := Vector2(
			zone.x * (float(i % colonnes) + 0.5) / float(colonnes),
			zone.y - 40.0 - 90.0 * float(i / colonnes)
		)
		var noeuds := AttackSpawner.spawn_attack(
			types[i], GlobalEnum.AttackTier.I, position,
			Vector2.RIGHT, zone, Vector2.ONE, null)
		for noeud in noeuds:
			add_child(noeud)


## GPUParticles2D des salles (torchesc, fumée des spawners de munitions).
func _spawner_effets_salles() -> void:
	for chemin in SCENES_SALLES:
		var scene: PackedScene = load(chemin)
		if scene == null:
			continue
		var instance := scene.instantiate()
		instance.position = Vector2(60, 60) if instance is Node2D else Vector2.ZERO
		add_child(instance)


## Explosion d'impact : shader de recolorisation (rampe rouge → élément),
## halos additifs, étincelles, et chargement des 35 textures de particules
## (autrement payées au PREMIER coup porté en jeu).
func _spawner_explosion_impact() -> void:
	ImpactExplosion.spawn(self, get_viewport_rect().size * 0.5,
		ImpactExplosion.rampe_pour_type(GlobalEnum.AttackType.G2))
