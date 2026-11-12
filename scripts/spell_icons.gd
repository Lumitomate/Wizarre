class_name SpellIcons

## Correspondance attaque → nom d'animation dans la ressource d'icônes
## de sorts (spell_icons.tres). Partagée par le tuyau du sac, le panneau
## de la cabine, son réceptacle et son bras, pour que le même sort
## s'affiche partout avec la même icône.
##
## F0 (Fireball) n'a pas d'icône dédiée : on renvoie celle de F1 (même
## élément Feu). Un type inconnu (-1, tube vide) renvoie "" → l'appelant
## cache l'icône.

static func anim_name(attack_type: int) -> String:
	if attack_type < 0 or attack_type >= GlobalEnum.AttackType.size():
		return ""
	var type_name: String = GlobalEnum.AttackType.keys()[attack_type]
	if type_name == "F0":
		return "Icone_AtkF1"
	return "Icone_Atk" + type_name
