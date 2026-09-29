class_name RebondSorciers
extends Area2D

## Zone de rebond des projectiles sur les SORCIERS (graines P1, P3...) :
## à attacher en enfant d'un RigidBody2D projectile. Quand le projectile
## approche d'un sorcier — y compris son LANCEUR — sa vitesse est réfléchie
## comme une balle.
##
## Détails :
##  - le rebond est calculé DANS LE RÉFÉRENTIEL du sorcier : sa vitesse de
##    saut/chute compte, sinon un sorcier qui saute plus vite que le
##    projectile le traverse (vitesse bornée pour garder le contrôle) ;
##  - la normale est calculée contre une capsule ÉLARGIE qui épouse le
##    corps VISIBLE du sorcier et descend jusqu'à ses pieds : la capsule
##    physique seule est plus fine que le sprite et s'arrête au-dessus du
##    sol, donc un projectile qui retombait à côté du corps ou sur les
##    pieds la traversait sans rebondir ;
##  - les ENNEMIS sont ignorés (le projectile continue de les traverser) ;
##  - aucune action tant que le projectile est gelé (ex. graine plantée).
##
## Usage (dans le script du projectile) :
##     _rebond = RebondSorciers.new()
##     _rebond.echelle = <échelle des sprites du projectile>
##     add_child(_rebond)

## Corps élargi : 1,6 × la capsule physique (= largeur du sprite du sorcier)
const BOUNCE_RADIUS_FACTOR := 1.6
## Bande "tête" : 1,2 × le rayon élargi (chute à peine désaxée = rebond haut)
const BOUNCE_HEAD_BAND := 1.2
## Pieds du sorcier : position + 32 px dans le repère parent
const SORCIER_FEET_OFFSET := 32.0
## Portée de détection (≈ largeur du sprite du projectile autour de lui)
const RAYON_DETECTION := 9.0
## Vitesse max du projectile après un rebond
const MAX_BOUNCE_SPEED := 700.0

## Échelle de la zone de détection (= l'échelle des sprites du projectile).
var echelle: float = 1.0:
	set(valeur):
		echelle = valeur
		if _forme != null:
			_forme.scale = Vector2(echelle, echelle)

var _forme: CollisionShape2D


func _ready() -> void:
	collision_layer = 0
	# Calque 1 : sorciers ET ennemis — le filtre ci-dessous ne retient que
	# les sorciers. Le projectile n'a PAS de collision physique avec eux
	# (mask inchangé côté projectile) : il les traverserait sinon.
	collision_mask = 1
	_forme = CollisionShape2D.new()
	var cercle := CircleShape2D.new()
	cercle.radius = RAYON_DETECTION
	_forme.shape = cercle
	_forme.scale = Vector2(echelle, echelle)
	add_child(_forme)


func _physics_process(_delta: float) -> void:
	var projectile := get_parent() as RigidBody2D
	if projectile == null or projectile.freeze:
		return
	for body in get_overlapping_bodies():
		if not (body is Sorcerer):
			continue
		var normal := _bounce_normal(body, projectile.linear_velocity.y > 0.0)
		# Vitesse du projectile VUE PAR le sorcier (référentiel sorcier) ;
		# réflexion seulement s'il s'APPROCHE, sinon un projectile encore
		# chevauchant repartirait dans l'autre sens à chaque frame.
		var vitesse_sorcier: Vector2 = body.velocity if "velocity" in body else Vector2.ZERO
		var rel_v := projectile.linear_velocity - vitesse_sorcier
		if rel_v.dot(normal) < 0.0:
			projectile.linear_velocity = vitesse_sorcier + rel_v.bounce(normal)
			var vitesse: float = projectile.linear_velocity.length()
			if vitesse > MAX_BOUNCE_SPEED:
				projectile.linear_velocity = projectile.linear_velocity / vitesse * MAX_BOUNCE_SPEED


## Normale de rebond pour un sorcier, calculée contre une capsule ÉLARGIE
## qui épouse son corps VISIBLE et descend jusqu'à ses pieds.
##  - projectile qui TOMBE au-dessus du corps, même près des bords →
##    rebond vers le haut et légèrement vers l'extérieur ;
##  - projectile À L'INTÉRIEUR du corps (tombé sous le sorcier) → sortie
##    par la moitié où il se trouve : en haut il rebondit, en bas il est
##    laissé au sol (il pourra se planter quand le sorcier s'écartera) ;
##  - sinon (contact de côté) → du point le plus proche sur la capsule
##    élargie vers le projectile.
func _bounce_normal(sorcier: Node2D, tombe: bool) -> Vector2:
	var shape_node := sorcier.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or not shape_node.shape is CapsuleShape2D:
		return (get_parent().global_position - sorcier.global_position).normalized()
	var t: Transform2D = shape_node.global_transform
	var inv := t.affine_inverse()
	var local: Vector2 = inv * (get_parent() as Node2D).global_position
	var capsule: CapsuleShape2D = shape_node.shape
	var radius: float = capsule.radius * BOUNCE_RADIUS_FACTOR
	# Bas du corps étendu jusqu'aux pieds visibles (position + 32 px dans
	# le repère parent, cf. spawn de la cinématique d'arrivée)
	var pieds_global: Vector2 = sorcier.get_parent().to_global(
		sorcier.position + Vector2(0, SORCIER_FEET_OFFSET)
	)
	var pieds_local_y: float = (inv * pieds_global).y
	var half_cyl: float = maxf(pieds_local_y - radius, 0.0)
	# Projectile qui TOMBE au-dessus du corps (bande élargie aux épaules) :
	# rebond vers le haut, poussé légèrement vers l'extérieur
	if tombe and local.y < 0.0 and absf(local.x) < radius * BOUNCE_HEAD_BAND:
		return Vector2(signf(local.x) * 0.4, -1.0).normalized()
	var closest := Vector2(0.0, clampf(local.y, -half_cyl, half_cyl))
	var delta: Vector2 = local - closest
	if delta.length() < radius:
		# projectile à l'intérieur du corps : sortie par la moitié où il est
		if local.y <= 0.0:
			return Vector2(0, -1)
		return Vector2(0, 1)
	if delta.length_squared() < 0.0001:
		return Vector2(0, -1)
	# Repasse la normale en coordonnées globales (échelle/rotation du sorcier)
	return t.basis_xform(delta).normalized()
