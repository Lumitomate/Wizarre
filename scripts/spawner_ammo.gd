@tool
class_name SpawnerAmmo extends Node2D

# Spawner de munitions : il PROJETE une munition selon un angle (en degrés)
# et une force réglables dans l'inspecteur. Il ne décide pas QUAND tirer :
# l'AmmoSpawnDirector du niveau choisit, à chaque cycle, 2 spawners au
# hasard parmi ceux visibles à l'écran et leur ordonne de tirer (spawn_now).
# L'axe Y étant vers le bas dans Godot : 0° = vers la droite,
# -90° = vers le haut, 90° = vers le bas.
#
# Repère visuel (éditeur uniquement) : une flèche orange montre la
# direction et la force de projection (longueur proportionnelle), avec
# le cône de dispersion en transparence et la valeur de la force.

enum AmmoChoice {
	Random,
	Coal,
	Pure,
	Tainted,
}

## Type de munition projetée (Random = tiré au hasard parmi les 3)
@export var ammo_choice: AmmoChoice = AmmoChoice.Random
## Direction de la projection en degrés (0 = droite, -90 = haut)
@export var launch_angle_degrees: float = -60.0:
	set(value):
		launch_angle_degrees = value
		_update_editor_preview()
## Force de la projection (vitesse initiale de la munition)
@export var launch_force: float = 450.0:
	set(value):
		launch_force = value
		_update_editor_preview()
## Variation aléatoire (en degrés) ajoutée à l'angle de projection
@export_range(0.0, 180.0) var launch_spread_degrees: float = 10.0:
	set(value):
		launch_spread_degrees = value
		_update_editor_preview()

# Repère éditeur : nombre de pixels par point de force
const FORCE_TO_PIXELS := 0.2
const ARROW_COLOR := Color(1.0, 0.55, 0.1)

var ammo_scene: PackedScene = preload("res://scenes/Ammo.tscn")


func _ready() -> void:
	if Engine.is_editor_hint():
		return  # rien à faire tourner dans l'éditeur
	# Le directeur (AmmoSpawnDirector) choisit quels spawners tirent :
	# ce spawner se déclare et attend l'ordre via spawn_now()
	add_to_group("ammo_spawner_group")


# Redessine le repère dès qu'un réglage change dans l'inspecteur
func _update_editor_preview() -> void:
	if Engine.is_editor_hint():
		queue_redraw()


# Repère de projection, dessiné uniquement dans l'éditeur
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var angle := deg_to_rad(launch_angle_degrees)
	var dir := Vector2(cos(angle), sin(angle))
	var length := launch_force * FORCE_TO_PIXELS
	var tip := dir * length

	# Point d'origine du spawner
	draw_circle(Vector2.ZERO, 4.0, ARROW_COLOR)

	# Cône de dispersion (transparence) si la dispersion est active
	if launch_spread_degrees > 0.0:
		var faint := Color(ARROW_COLOR.r, ARROW_COLOR.g, ARROW_COLOR.b, 0.3)
		var spread := deg_to_rad(launch_spread_degrees)
		for a in [angle - spread, angle + spread]:
			var d := Vector2(cos(a), sin(a))
			draw_line(Vector2.ZERO, d * length, faint, 1.0)

	# Flèche principale
	draw_line(Vector2.ZERO, tip, ARROW_COLOR, 2.0)
	var head := dir * 10.0
	draw_line(tip, tip - head.rotated(deg_to_rad(30)), ARROW_COLOR, 2.0)
	draw_line(tip, tip - head.rotated(-deg_to_rad(30)), ARROW_COLOR, 2.0)

	# Graduations tous les 100 de force
	var perp := Vector2(-dir.y, dir.x) * 4.0
	for t in range(1, int(launch_force / 100.0) + 1):
		var p := dir * (100.0 * t * FORCE_TO_PIXELS)
		draw_line(p - perp, p + perp, ARROW_COLOR, 1.0)

	# Valeur de la force au bout de la flèche
	draw_string(ThemeDB.fallback_font, tip + Vector2(8, -4), str(int(launch_force)),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ARROW_COLOR)


# Fait apparaître et projeter une munition immédiatement.
# Appelé par l'AmmoSpawnDirector, qui choisit quels spawners tirent
# (2 au hasard parmi ceux visibles à l'écran, à chaque cycle).
func spawn_now() -> void:
	var ammo: Ammo = ammo_scene.instantiate()
	ammo.ammo_type = _pick_ammo_type()
	ammo.position = position
	get_parent().add_child(ammo)

	var angle := deg_to_rad(launch_angle_degrees + randf_range(-launch_spread_degrees, launch_spread_degrees))
	ammo.launch(Vector2(cos(angle), sin(angle)), launch_force)

	# Gerbe de fumée à chaque projection (one_shot : restart() relance
	# l'explosion de particules à chaque spawn)
	$Smoke.restart()


func _pick_ammo_type() -> GlobalEnum.EnergyType:
	match ammo_choice:
		AmmoChoice.Coal:
			return GlobalEnum.EnergyType.Fossil
		AmmoChoice.Pure:
			return GlobalEnum.EnergyType.Pure
		AmmoChoice.Tainted:
			return GlobalEnum.EnergyType.Tainted
		_:
			return [GlobalEnum.EnergyType.Fossil, GlobalEnum.EnergyType.Pure, GlobalEnum.EnergyType.Tainted][randi() % 3]
