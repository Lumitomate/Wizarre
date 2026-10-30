class_name AmmoSpawnDirector extends Node2D

## Chef d'orchestre des spawners d'ammo : à chaque cycle (laps de temps),
## il choisit N spawners AU HASARD parmi ceux visibles à l'écran et leur
## fait projeter une munition. Les spawners ne se débrouillent plus seuls :
## ils attendent l'ordre du directeur (voir spawn_now dans spawner_ammo.gd).
##
## Le directeur décide aussi QUOI tirer (grillé : tirage pondéré par le
## manque) : à chaque cycle, il calcule les 3 poids — un type dont les
## tubes de l'équipe sont vides sort plus souvent — et les passe aux
## spawners qu'il ordonne de tirer. Tous les spawners d'un même cycle
## utilisent exactement les mêmes poids. Sans sorcier actif (homepage,
## tests headless) : poids uniformes 1/1/1.

## Nombre de spawners qui tirent à chaque cycle
@export var spawners_per_cycle: int = 2
## Temps (en secondes) entre deux cycles de tir
@export var cycle_duration: float = 5.0

@export_group("Biais de manque")
## Poids de tirage d'un type de munition dont les tubes sont VIDES chez
## les sorciers (grillé : les munitions dont l'équipe manque sortent plus
## souvent). Interpolé linéairement avec le taux de remplissage moyen.
@export var poids_tube_vide: float = 5.0
## Poids d'un type dont les tubes sont PLEINS chez les sorciers — jamais
## zéro : un type plein garde toujours une petite chance de sortir.
@export var poids_tube_plein: float = 1.0

# Progression par vague : la durée du cycle est multipliée par ce facteur
# à chaque nouvelle vague (> 1 = ralentissement très léger)
const SPAWN_TIME_FACTOR_PER_WAVE := 1.03


func _ready() -> void:
	add_to_group("ammo_spawn_director_group")
	# Vague 0 (première vague) = vitesse de base, puis léger ralentissement
	$Cycle.wait_time = cycle_duration * pow(SPAWN_TIME_FACTOR_PER_WAVE, GlobalInfo.run_info["level_number"])
	$Cycle.start()


func _on_cycle_timeout() -> void:
	var spawners := get_tree().get_nodes_in_group("ammo_spawner_group")
	if spawners.is_empty():
		return

	# Ne garde que les spawners visibles à l'écran
	var on_screen: Array = []
	for spawner in spawners:
		if _is_on_screen(spawner):
			on_screen.append(spawner)
	if on_screen.is_empty():
		return

	# Tire au hasard N spawners parmi ceux visibles (2 par défaut), puis
	# calcule les poids du cycle UNE SEULE FOIS : tous les spawners tirés
	# utilisent les mêmes poids (cohérence du tirage pondéré).
	on_screen.shuffle()
	var poids := _poids_du_cycle()
	for i in range(min(spawners_per_cycle, on_screen.size())):
		on_screen[i].spawn_now(poids)


# Un spawner est-il dans ce que voit le joueur à l'écran ?
func _is_on_screen(spawner: Node2D) -> bool:
	var viewport := get_viewport()
	var screen_pos: Vector2 = viewport.canvas_transform * spawner.global_position
	var screen_size := viewport.get_visible_rect().size
	return screen_pos.x >= 0 and screen_pos.x <= screen_size.x \
			and screen_pos.y >= 0 and screen_pos.y <= screen_size.y


## Poids du tirage des types pour ce cycle (grillé : tirage pondéré par
## le manque). Pour chaque type : taux de remplissage moyen = moyenne sur
## les sorciers actifs de energy_counts[type] / MAX_ENERGY ; poids = lerp
## (poids_tube_plein, poids_tube_vide, 1 - taux) — 0/4 → poids max,
## 2/4 → milieu, 4/4 → poids min (jamais zéro). Sans sorcier actif
## (homepage, tests headless) : poids uniformes 1/1/1.
func _poids_du_cycle() -> Array[float]:
	var sorciers := _sorciers_actifs()
	if sorciers.is_empty():
		return [1.0, 1.0, 1.0]
	var poids: Array[float] = []
	for type in 3:
		var taux := 0.0
		for sorcier in sorciers:
			taux += float(sorcier.energy_counts[type]) / float(sorcier.MAX_ENERGY)
		taux /= float(sorciers.size())
		poids.append(lerpf(poids_tube_plein, poids_tube_vide, 1.0 - taux))
	return poids


## Sorciers en jeu, valides (lecture non typée : cf. gambling_machine.gd).
func _sorciers_actifs() -> Array[Sorcerer]:
	var sorciers: Array[Sorcerer] = []
	for controller_id in PlayerManager.active_player_ids():
		var player = PlayerManager.players.get(controller_id)
		if player != null and is_instance_valid(player):
			sorciers.append(player)
	return sorciers
