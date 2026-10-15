class_name AttackProjectile extends Area2D

# Classe de base des projectiles (Area2D). Factorise le comportement de
# contact commun : détection des corps des deux camps et application des
# dégâts. Les projectiles spécifiques surchargent can_damage() pour leurs
# règles propres (immunité du lanceur, délai d'activation, etc.).

@export var damage: int = 1

# Sorcier lanceur de l'attaque (renseigné par spawner_attack) : transmis
# aux ennemis touchés pour la représaille
var caster: Node2D = null

# --- Garde anti double-coup « dans la zone » (règle validée) ---
# Ex. colonne de feu F1 : une CHAÎNE de colonnes le long de la visée —
# traverser le feu dure plus que le cooldown de dégâts, le corps était
# donc brûlé plusieurs fois de suite. Règle : être chevauché par
# n'importe quelle zone du MÊME TYPE d'attaque protège d'un nouveau coup
# de ce type ; la protection se lève dès que le corps ne chevauche plus
# aucune zone. Symétrique joueurs/ennemis.
#
# Registre statique partagé, clé par TAG d'attaque (dérivé du script —
# chaque type d'attaque a sa clé sans configuration) puis par
# instance_id du corps :
#   {tag: {id_corps: {"zones": int, "touche": bool}}}
# "zones" = nombre de zones de ce type chevauchant le corps ; "touche"
# = ce corps a déjà été touché par ce type d'attaque pendant cette
# présence. Bloqué si zones > 0 ET touche. À la sortie de la dernière
# zone, l'entrée est retirée : la protection se lève.
#
# PIÈGE GÉRÉ ICI : un Area2D libéré n'émet PAS body_exited — chaque
# projectile marque les corps qu'il surveille et se nettoie à sa
# destruction (tree_exiting), sinon la protection fuiterait et
# deviendrait permanente.
static var _superpositions: Dictionary = {}

## Tag anti double-coup de ce type d'attaque : le chemin du script est
## unique par type, donc aucune configuration nécessaire.
func tag_anti_double() -> String:
	return str(get_script().resource_path)


## Corps surveillable (les deux camps damageables)
static func _surveillable(body: Node2D) -> bool:
	return body.is_in_group("player_group") or body.is_in_group("enemy_group")


## Entrée du corps dans une zone de ce projectile (appelée par les
## sous-classes depuis leur body_entered)
func _surveiller_entree(body: Node2D) -> void:
	if not _surveillable(body):
		return
	var tag := tag_anti_double()
	var par_corps: Dictionary = _superpositions.get_or_add(tag, {})
	var entree: Dictionary = par_corps.get_or_add(body.get_instance_id(), {"zones": 0, "touche": false})
	entree["zones"] += 1


## Sortie du corps d'une zone (appelée par les sous-classes depuis leur
## body_exited). Dernière zone quittée → la protection se lève.
func _surveiller_sortie(body: Node2D) -> void:
	if not _surveillable(body):
		return
	var tag := tag_anti_double()
	var par_corps: Dictionary = _superpositions.get(tag, {})
	var id := body.get_instance_id()
	var entree = par_corps.get(id, null)
	if entree == null:
		return
	entree["zones"] -= 1
	if entree["zones"] <= 0:
		par_corps.erase(id)


## Un coup sur ce corps est-il bloqué par la règle « dans la zone » ?
func double_toc_bloque(body: Node2D) -> bool:
	var par_corps: Dictionary = _superpositions.get(tag_anti_double(), {})
	var entree = par_corps.get(body.get_instance_id(), null)
	return entree != null and entree["zones"] > 0 and entree["touche"]


## Le corps vient d'être touché par ce type d'attaque : il ne peut plus
## l'être tant qu'il reste dans une zone.
func _marquer_touche(body: Node2D) -> void:
	var tag := tag_anti_double()
	var par_corps: Dictionary = _superpositions.get(tag, {})
	var entree = par_corps.get(body.get_instance_id(), null)
	if entree != null:
		entree["touche"] = true


## Les corps que CE projectile surveille (pour le nettoyage à sa
## destruction)
var _corps_surveilles: Array[Node2D] = []


func _ready() -> void:
	# Nettoyage à la destruction : un Area2D libéré n'émet pas
	# body_exited — sans ça, les corps qu'il surveillait resteraient
	# protégés pour toujours.
	tree_exiting.connect(_nettoyer_surveillance)


func _nettoyer_surveillance() -> void:
	var tag := tag_anti_double()
	var par_corps: Dictionary = _superpositions.get(tag, {})
	for corps in _corps_surveilles:
		if not is_instance_valid(corps):
			continue
		var entree = par_corps.get(corps.get_instance_id(), null)
		if entree != null:
			entree["zones"] -= 1
			if entree["zones"] <= 0:
				par_corps.erase(corps.get_instance_id())
	_corps_surveilles.clear()


# Hook surchargeable : le corps peut-il être touché par ce projectile ?
func can_damage(_body: Node2D) -> bool:
	return true


func _on_body_entered(body: Node2D) -> void:
	if _surveillable(body):
		_surveiller_entree(body)
		_corps_surveilles.append(body)
	if body.is_in_group("player_group"):
		if can_damage(body):
			body.hit(damage)
			_marquer_touche(body)
	elif body.is_in_group("enemy_group"):
		if can_damage(body):
			# Origine = le projectile : l'ennemi éclate dans le sens de son vol
			body.hit(damage, caster, self)
			_marquer_touche(body)


## Sortie d'une zone (branchée par les sous-classes qui utilisent la
## garde anti double-coup)
func _on_body_exited(body: Node2D) -> void:
	_surveiller_sortie(body)
