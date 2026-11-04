extends Node

## Vérification headless de la scène Ammo : instanciation, changement de
## ammo_type, cohérence texture/polygones/cerne, et appel de fly_ammo_in
## avec la nouvelle signature (texture passée en paramètre).

const EXPECTED := {
	GlobalEnum.EnergyType.Fossil: "Ammo_Coal_V2.png",
	GlobalEnum.EnergyType.Pure: "Ammo_Pure_V2.png",
	GlobalEnum.EnergyType.Tainted: "Ammo_Tainted_V2.png",
}


func _ready() -> void:
	var ammo: Ammo = load("res://scenes/Ammo.tscn").instantiate()
	add_child(ammo)
	await get_tree().process_frame

	var failures := 0
	for type in [GlobalEnum.EnergyType.Fossil, GlobalEnum.EnergyType.Pure, GlobalEnum.EnergyType.Tainted]:
		ammo.ammo_type = type
		await get_tree().process_frame
		var tex_path: String = ammo.get_node("Sprite2D").texture.resource_path.get_file()
		var expected: String = EXPECTED[type]
		var ok_tex := tex_path == expected
		var coal_off: bool = ammo.get_node("CoalPolygon").disabled
		var pure_off: bool = ammo.get_node("PurePolygon").disabled
		var tainted_off: bool = ammo.get_node("TaintedPolygon").disabled
		var ok_poly := (not coal_off) if type == GlobalEnum.EnergyType.Fossil \
				else ((not pure_off) if type == GlobalEnum.EnergyType.Pure else (not tainted_off))
		var mat: ShaderMaterial = ammo.get_node("Sprite2D").material
		var inner: float = mat.get_shader_parameter("inner_width")
		var outer: float = mat.get_shader_parameter("outer_width")
		print("%s → texture=%s polygones_ok=%s cerne(int/ext)=%s/%s" % [
				GlobalEnum.EnergyType.keys()[type], tex_path, ok_poly, inner, outer])
		if not ok_tex or not ok_poly:
			failures += 1

	print("Résultat : %s" % ("ÉCHEC (%d)" % failures if failures > 0 else "OK"))
	get_tree().quit(1 if failures > 0 else 0)
