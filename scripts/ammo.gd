@tool
class_name Ammo extends RigidBody2D

# Munition projetée par un spawner. Le joueur la ramasse en la touchant,
# ce qui ajoute 1 munition dans le tube correspondant du sorcier
# (le HUD se met à jour via le signal ammo_changed de add_energy).
#
# Le type d'ammo choisit le sprite ET le polygone de collision utilisé :
# les 3 polygones (CoalPolygon, PurePolygon, TaintedPolygon) sont présents
# dans la scène et éditables séparément dans l'éditeur.
# Grâce à @tool, changer ammo_type, une texture ou une largeur de cerne
# dans l'inspecteur met à jour le sprite en direct dans l'éditeur.
# Le cerne du shader fait partie du réglage de chaque type : il suit
# la texture choisie, ce n'est pas une règle codée en dur.

@export_group("Type")
@export var ammo_type: GlobalEnum.EnergyType = GlobalEnum.EnergyType.Fossil:
	set(value):
		ammo_type = value
		# Pendant le chargement de la scène, les enfants (Sprite2D, polygones)
		# n'existent pas encore : on ne les touche que quand le nœud est prêt.
		# _ready appliquera le type de toute façon.
		if is_node_ready():
			_apply_type()

@export_group("Coal")
@export var texture_coal: Texture2D = preload("res://assets/sprites/Munitions/Ammo/Ammo_Coal_V2.png"):
	set(value):
		texture_coal = value
		if is_node_ready():
			_apply_type()
@export var coal_inner_width: float = 1.0:
	set(value):
		coal_inner_width = value
		if is_node_ready():
			_apply_type()
@export var coal_outer_width: float = 2.0:
	set(value):
		coal_outer_width = value
		if is_node_ready():
			_apply_type()

@export_group("Pure")
@export var texture_pure: Texture2D = preload("res://assets/sprites/Munitions/Ammo/Ammo_Pure_V2.png"):
	set(value):
		texture_pure = value
		if is_node_ready():
			_apply_type()
@export var pure_inner_width: float = 1.0:
	set(value):
		pure_inner_width = value
		if is_node_ready():
			_apply_type()
@export var pure_outer_width: float = 2.0:
	set(value):
		pure_outer_width = value
		if is_node_ready():
			_apply_type()

@export_group("Tainted")
@export var texture_tainted: Texture2D = preload("res://assets/sprites/Munitions/Ammo/Ammo_Tainted_V2.png"):
	set(value):
		texture_tainted = value
		if is_node_ready():
			_apply_type()
@export var tainted_inner_width: float = 1.0:
	set(value):
		tainted_inner_width = value
		if is_node_ready():
			_apply_type()
@export var tainted_outer_width: float = 2.0:
	set(value):
		tainted_outer_width = value
		if is_node_ready():
			_apply_type()

# Garde-fou : évite un double ramassage par 2 joueurs dans la même frame
var _collected := false


func _ready() -> void:
	_apply_type()


# Applique le sprite, le polygone de collision et les réglages du shader
# de cerne du type courant. Texture et cerne viennent des exports du
# groupe correspondant : ce qui est réglé dans l'inspecteur fait foi.
func _apply_type() -> void:
	var tex: Texture2D
	var inner := 0.0
	var outer := 0.0
	match ammo_type:
		GlobalEnum.EnergyType.Fossil:
			tex = texture_coal
			inner = coal_inner_width
			outer = coal_outer_width
		GlobalEnum.EnergyType.Pure:
			tex = texture_pure
			inner = pure_inner_width
			outer = pure_outer_width
		GlobalEnum.EnergyType.Tainted:
			tex = texture_tainted
			inner = tainted_inner_width
			outer = tainted_outer_width
	$Sprite2D.texture = tex
	$CoalPolygon.disabled = ammo_type != GlobalEnum.EnergyType.Fossil
	$PurePolygon.disabled = ammo_type != GlobalEnum.EnergyType.Pure
	$TaintedPolygon.disabled = ammo_type != GlobalEnum.EnergyType.Tainted

	# Cerne du shader (resource_local_to_scene : le matériau est dupliqué
	# par instance, donc modifier les paramètres ici n'affecte que cette
	# ammo).
	var mat := $Sprite2D.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("inner_width", inner)
		mat.set_shader_parameter("outer_width", outer)


# Impulsion initiale donnée par le spawner après l'ajout dans l'arbre
func launch(direction: Vector2, force: float) -> void:
	linear_velocity = direction.normalized() * force


func _on_pickup_area_body_entered(body: Node2D) -> void:
	if _collected or not body.is_in_group("player_group"):
		return
	_collected = true
	var sorcerer: Sorcerer = body
	# L'ordre de GlobalEnum.EnergyType (Fossil, Pure, Tainted) correspond
	# exactement aux tubes du sorcier (energy_counts) : Fossil = tube 0, etc.
	sorcerer.add_energy(ammo_type, 1)
	_fly_to_hud(sorcerer)
	queue_free()


## Copie visuelle qui vole vers la gemme du HUD du ramasseur. Cosmétique :
## le compteur est déjà incrémenté ; sans HUD trouvé, on saute le vol.
## On passe la texture du sprite ramassé : le fantôme reflète la munition
## réellement ramassée (y compris une texture personnalisée par instance).
func _fly_to_hud(sorcerer: Sorcerer) -> void:
	var texture: Texture2D = $Sprite2D.texture
	for hud in get_tree().get_nodes_in_group("player_hud_group"):
		if hud.controller_id == sorcerer.controller_id:
			hud.fly_ammo_in(ammo_type, global_position, global_scale, texture)
			return
