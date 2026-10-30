class_name EntityFinder

## Utilitaire de recherche d'entité la plus proche. La logique était
## dupliquée dans enemy_flying (joueur le plus proche), la graine P1
## (entité la plus proche pour l'œil) et le knockback du sorcier
## (ennemi le plus proche) : un seul endroit désormais.

## Attaquant utilisable pour la représaille : le sorcier peut MOURIR
## pendant que son attaque vole encore (homepage surtout, où les tirs
## sont actifs) — passer l'instance freed à hit()/die() plante la machine
## ("The object-derived class of argument 2 is not a subclass...").
## Retourne le caster s'il est encore vivant, sinon null. Paramètre NON
## typé : une instance freed ne passe même pas le contrôle de type d'un
## paramètre Node2D — la validation doit se faire ici, avec Variant.
static func attaquant_valide(caster) -> Node2D:
	if is_instance_valid(caster):
		return caster as Node2D
	return null


## Nœud Node2D le plus proche du point `depuis` parmi les groupes donnés
## (scannés dans l'ordre). `context` : n'importe quel nœud dans l'arbre
## (sert uniquement à accéder à l'arbre depuis une fonction static).
## `exclude` : nœuds à ignorer (optionnel). Retourne null si aucun
## candidat valide. Les distances sont comparées en positions globales :
## l'ordre de proximité est identique en coordonnées locales tant que
## les entités partagent un parent à échelle uniforme (le cas ici).
static func plus_proche(context: Node, depuis: Vector2, groupes: Array, exclude: Array = []) -> Node2D:
	var plus_proche_node: Node2D = null
	var distance_min := INF
	for group_name in groupes:
		for node in context.get_tree().get_nodes_in_group(group_name):
			if node in exclude:
				continue
			var entity := node as Node2D
			if entity == null or not is_instance_valid(entity):
				continue
			var d := depuis.distance_to(entity.global_position)
			if d < distance_min:
				distance_min = d
				plus_proche_node = entity
	return plus_proche_node
