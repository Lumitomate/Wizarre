class_name SpellRules

# Règles partagées de calcul des sorts. Utilisée par Sorcerer (normalisation
# après chargement/prise) et par les objets d'attaque (calcul du tier à la prise).

# La nomenclature des enum donne directement l'élément :
# F1 → "F", G3 → "G", L1 → "L", P2 → "P"
static func element_of(attack_type: int) -> String:
	return GlobalEnum.AttackType.keys()[attack_type].left(1)


# Compte les attaques d'un même élément dans les tubes du joueur
static func count_element(spells: Dictionary, element: String) -> int:
	var count := 0
	for i in range(3):
		var spell: Dictionary = spells[i]
		if not spell.is_empty() and element_of(spell["attack_type"]) == element:
			count += 1
	return count


# Tier canonique = nombre d'attaques du même élément que le joueur possède
# (1 → I, 2 → II, 3 et plus → III). AttackTier : I=0, II=1, III=2
static func compute_tier(spells: Dictionary, attack_type: int) -> int:
	var element := element_of(attack_type)
	return mini(count_element(spells, element) + 1, 3) - 1


# Rétroactif : le tier d'une attaque = nombre d'attaques du même
# élément que le joueur possède (1 → I, 2 → II, 3 et plus → III).
# TOUTES les attaques d'un même élément partagent ce tier : collecter
# un nouveau feu améliore aussi les feux déjà possédés.
static func normalize_spell_tiers(spells: Dictionary) -> void:
	var element_counts := {}
	for i in range(3):
		var spell: Dictionary = spells[i]
		if spell.is_empty():
			continue
		var element := element_of(spell["attack_type"])
		element_counts[element] = int(element_counts.get(element, 0)) + 1
	for i in range(3):
		var spell: Dictionary = spells[i]
		if spell.is_empty():
			continue
		var element := element_of(spell["attack_type"])
		spells[i]["attack_tier"] = mini(int(element_counts[element]), 3) - 1
