class_name AmmoSpawnDirector extends Node2D

## Chef d'orchestre des spawners d'ammo : à chaque cycle (laps de temps),
## il choisit N spawners AU HASARD parmi ceux visibles à l'écran et leur
## fait projeter une munition. Les spawners ne se débrouillent plus seuls :
## ils attendent l'ordre du directeur (voir spawn_now dans spawner_ammo.gd).

## Nombre de spawners qui tirent à chaque cycle
@export var spawners_per_cycle: int = 2
## Temps (en secondes) entre deux cycles de tir
@export var cycle_duration: float = 5.0


func _ready() -> void:
	$Cycle.wait_time = cycle_duration
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

	# Tire au hasard N spawners parmi ceux visibles (2 par défaut)
	on_screen.shuffle()
	for i in range(min(spawners_per_cycle, on_screen.size())):
		on_screen[i].spawn_now()


# Un spawner est-il dans ce que voit le joueur à l'écran ?
func _is_on_screen(spawner: Node2D) -> bool:
	var viewport := get_viewport()
	var screen_pos: Vector2 = viewport.canvas_transform * spawner.global_position
	var screen_size := viewport.get_visible_rect().size
	return screen_pos.x >= 0 and screen_pos.x <= screen_size.x \
			and screen_pos.y >= 0 and screen_pos.y <= screen_size.y
