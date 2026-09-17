class_name EnemyFly extends EnemyFlying

# Mouche : variante rapide du monstre volant, spawn en groupe de 5.
# Fonctionne exactement comme EnemyFlying (mêmes vies, mêmes dégâts),
# avec une vitesse supérieure. La hitbox est réglée directement dans
# enemy_fly.tscn (CollisionShape2D).

# Vitesse propre à la mouche (légèrement plus rapide que le volant : 100)
@export var fly_speed: int = 130

# --- Comportement d'essaim ---
# Membres du groupe (inclut cette mouche) : rempli par le spawner
var swarm: Array[EnemyFly] = []
# Poste personnel autour du centre de l'essaim (re-tiré à chaque errance)
var swarm_offset: Vector2 = Vector2.ZERO
# Force d'attraction vers son poste dans l'essaim (0 = volant solo)
@export var swarm_cohesion: float = 0.8

# Rayon du poste personnel autour du centre de l'essaim (en px)
const FLY_SWARM_SPREAD := 40.0


func _ready() -> void:
	# Le _ready du parent (EnemyFlying) n'est pas appelé automatiquement
	# quand on le surcharge : on l'invoque explicitement pour jouer
	# l'animation et configurer la navigation
	super()
	speed = fly_speed


func _process(_delta: float) -> void:
	super(_delta)
	# Une mouche sans cible emprunte celle d'un membre de l'essaim : dès
	# qu'une mouche repère le sorcier, tout l'essaim le poursuit
	if target == null:
		for member in swarm:
			if is_instance_valid(member) and member != self and member.target != null:
				target = member.target
				break


# Errance : l'essaim erre en groupe. Chaque mouche se rend vers son poste
# personnel autour du centre de l'essaim (offset re-tiré à chaque appel,
# ce qui fait dériver le groupe organiquement)
func set_random_navigation_target() -> void:
	var center := _swarm_center()
	if center == Vector2.INF:
		super()
		return
	swarm_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * FLY_SWARM_SPREAD
	set_navigation_target(center + swarm_offset)


# Mort d'une mouche : les mouches survivantes de l'essaim prennent le
# sorcier qui l'a tuée pour cible (celles qui n'en ont pas déjà une)
func die(attacker: Node2D = null) -> void:
	var killer := attacker if attacker != null else last_attacker
	if killer != null and is_instance_valid(killer) and killer.is_in_group("player_group"):
		for member in swarm:
			if is_instance_valid(member) and not member.is_queued_for_deletion() and member.target == null:
				member.target = killer
	super(attacker)


# Poursuite du sorcier (identique au volant) biaisée vers son poste dans
# l'essaim pour que le groupe reste soudé pendant la chasse
func _desired_direction(next_path_position: Vector2) -> Vector2:
	var chase_dir := super(next_path_position)
	var center := _swarm_center()
	if center == Vector2.INF:
		return chase_dir
	var to_post := center + swarm_offset - global_position
	if to_post.length() <= 8.0:
		return chase_dir
	return (chase_dir + to_post.normalized() * swarm_cohesion).normalized()


# Centre de l'essaim (membres encore en vie uniquement) ;
# Vector2.INF si aucun membre valide (comportement solo)
func _swarm_center() -> Vector2:
	var center := Vector2.ZERO
	var count := 0
	for member in swarm:
		if is_instance_valid(member):
			center += member.global_position
			count += 1
	if count == 0:
		return Vector2.INF
	return center / count
