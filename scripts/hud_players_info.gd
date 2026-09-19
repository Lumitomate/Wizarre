class_name PlayerInfo extends Control

var ammo_counts: Array = [0, 0, 0]
var lives: int = 0

# Les gemmes du HUD suivent l'ordre des énergies des tubes :
# Fossil = 0, Pure = 1, Tainted = 2
const GEM_NODES := ["HudFosil", "HudPure", "HudTainted"]

func _ready() -> void:
	refresh_status()


func load_data(data_to_load: Dictionary) -> void:
	lives = data_to_load["lives"]
	ammo_counts = data_to_load["energy_counts"]


func refresh_status() -> void:
	# Vies : le sprite couvre 0 à 3 (frame = nombre de vies)
	$HudVie.frame = clampi(lives, 0, 3)

	# Gemmes : sprites de 5 frames dans l'ordre décroissant
	# (frame 0 = 4 ammo ou plus, frame 4 = 0 ammo)
	for tube_index in range(ammo_counts.size()):
		var gem: AnimatedSprite2D = get_node(GEM_NODES[tube_index])
		gem.frame = 4 - clampi(ammo_counts[tube_index], 0, 4)

func set_bg_color(color_id: GlobalEnum.SorcererColor):
	# Le matériau du .tscn est partagé entre les 4 HUD joueurs : on en
	# duplique un par instance avant d'y écrire les couleurs du joueur
	var sprite: AnimatedSprite2D = $SorcereColor
	var mat: ShaderMaterial = sprite.material.duplicate()
	WizardPalette.apply_to_material(mat, color_id)
	sprite.material = mat


func _on_ammo_changed(tube_index: int, ammo_amount: int):
	ammo_counts[tube_index] = ammo_amount
	refresh_status()
	
func _on_life_changed(amount: int) -> void:
	lives = amount
	refresh_status()
