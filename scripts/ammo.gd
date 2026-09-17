@tool
class_name Ammo extends RigidBody2D

# Munition projetée par un spawner. Le joueur la ramasse en la touchant,
# ce qui ajoute 1 munition dans le tube correspondant du sorcier
# (le HUD se met à jour via le signal ammo_changed de add_energy).
#
# Le type d'ammo choisit le sprite ET le polygone de collision utilisé :
# les 3 polygones (CoalPolygon, PurePolygon, TaintedPolygon) sont présents
# dans la scène et éditables séparément dans l'éditeur.
# Grâce à @tool, changer ammo_type dans l'inspecteur met à jour
# le sprite et les polygones en direct dans l'éditeur.

const TEXTURES := {
	GlobalEnum.EnergyType.Fossil: preload("res://assets/sprites/Munitions/Ammo/Ammo_Coal.png"),
	GlobalEnum.EnergyType.Pure: preload("res://assets/sprites/Munitions/Ammo/Ammo_Pure.png"),
	GlobalEnum.EnergyType.Tainted: preload("res://assets/sprites/Munitions/Ammo/Ammo_Tainted.png"),
}

@export var ammo_type: GlobalEnum.EnergyType = GlobalEnum.EnergyType.Fossil:
	set(value):
		ammo_type = value
		# Pendant le chargement de la scène, les enfants (Sprite2D, polygones)
		# n'existent pas encore : on ne les touche que quand le nœud est prêt.
		# _ready appliquera le type de toute façon.
		if is_node_ready():
			_apply_type()

# Garde-fou : évite un double ramassage par 2 joueurs dans la même frame
var _collected := false


func _ready() -> void:
	_apply_type()


# Applique le sprite, le polygone de collision et les réglages du shader
# de cerne du type courant
func _apply_type() -> void:
	$Sprite2D.texture = TEXTURES[ammo_type]
	$CoalPolygon.disabled = ammo_type != GlobalEnum.EnergyType.Fossil
	$PurePolygon.disabled = ammo_type != GlobalEnum.EnergyType.Pure
	$TaintedPolygon.disabled = ammo_type != GlobalEnum.EnergyType.Tainted

	# Cerne du shader (resource_local_to_scene : le matériau est dupliqué
	# par instance, donc modifier les paramètres ici n'affecte que cette
	# ammo). L'ammo Pure a en plus une cerne intérieure noire de 1 px :
	# cerne noire sur le bord du sprite, cerne blanche extérieure de 2 px.
	var mat := $Sprite2D.material as ShaderMaterial
	if mat:
		var is_pure := ammo_type == GlobalEnum.EnergyType.Pure
		mat.set_shader_parameter("inner_width", 1.0 if is_pure else 0.0)
		mat.set_shader_parameter("outer_width", 2.0 if is_pure else 3.0)


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
	queue_free()
