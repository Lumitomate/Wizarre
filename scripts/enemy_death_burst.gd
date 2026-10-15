class_name EnemyDeathBurst
extends Node2D

# Éclatement d'un Enemy à sa mort : quelques morceaux de corps (sprites
# restes_ennemis) et des pixels de sang giclent dans le sens de l'attaque
# fatale, retombent avec une vraie physique (seule la tilemap les bloque),
# puis disparaissent rapidement du sol. La scène s'auto-supprime quand le
# dernier débris a disparu : EnemyFlying.die() n'a que trois lignes à faire.
#
# Physique « à la main » inspirée de SorcererCorpse : gravité identique,
# collision_layer = 0 (toutes les entités passent à travers les débris),
# collision_mask = 12 (seule la tilemap les bloque). Pas de rebond pour le
# sang : une goutte qui touche le sol s'arrête et fond immédiatement.

## Textures des morceaux de corps (tirage aléatoire à chaque mort)
const CHUNK_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/Monstres/Monstre_particules/restes_ennemis_1.png"),
	preload("res://assets/sprites/Monstres/Monstre_particules/restes_ennemis_2.png"),
	preload("res://assets/sprites/Monstres/Monstre_particules/restes_ennemis_3.png"),
	preload("res://assets/sprites/Monstres/Monstre_particules/restes_ennemis_4.png"),
	preload("res://assets/sprites/Monstres/Monstre_particules/restes_ennemis_5.png"),
	preload("res://assets/sprites/Monstres/Monstre_particules/restes_ennemis_6.png"),
	preload("res://assets/sprites/Monstres/Monstre_particules/restes_ennemis_7.png"),
	preload("res://assets/sprites/Monstres/Monstre_particules/restes_ennemis_8.png"),
]

## Couleurs du sang (tirage aléatoire par goutte)
const BLOOD_COLORS: Array[Color] = [
	Color("ff5fcd"),
	Color("be4a9a"),
	Color("953376"),
]

const GRAVITY := 1200.0          # même gravité que le sorcier et son cadavre
const BOUNCE_RESTITUTION := 0.3  # rebond du premier contact (~30 % de la vitesse)
const STOP_SPEED := 40.0         # en dessous de cette vitesse au sol : le morceau se pose

# Cônes de diffusion (demi-angles en degrés) autour de la direction de l'attaque
const CHUNK_CONE_DEG := 50.0
const BLOOD_CONE_DEG := 60.0

# Vitesses d'éjection (px/s) — les morceaux partent 2 fois plus vite
const CHUNK_SPEED_MIN := 240.0
const CHUNK_SPEED_MAX := 640.0
const BLOOD_SPEED_MIN := 200.0
const BLOOD_SPEED_MAX := 450.0

# Disparition
const CHUNK_REST_MIN := 0.8      # temps au sol avant le fondu (aléatoire : décalé)
const CHUNK_REST_MAX := 1.5
const CHUNK_FADE_DURATION := 0.3
const BLOOD_FADE_MIN := 0.2      # fondu dès le contact avec le sol
const BLOOD_FADE_MAX := 0.4
# Garde-fou : si un débris ne touche jamais le sol (fosse…), il fond quand même
const CHUNK_MAX_LIFETIME := 3.0
const BLOOD_MAX_LIFETIME := 1.2

## Direction de l'attaque fatale (unitaire), fixée par EnemyFlying.die()
var direction: Vector2 = Vector2.UP

## Quantités de débris (la mouche les réduit : 1-3 morceaux, 8-12 gouttes)
@export var chunk_count_min := 4
@export var chunk_count_max := 8
@export var blood_count_min := 50
@export var blood_count_max := 80

var _pieces: Array[Piece] = []

# Texture 2x2 blanche partagée, teintée par goutte via modulate (le sang)
static var _pixel_texture: ImageTexture = null


class Piece:
	var body: CharacterBody2D
	var is_chunk: bool
	var angular_speed := 0.0   # culbute en vol (morceaux uniquement)
	var has_bounced := false
	var landed := false
	var rest_duration := 0.0
	var rest_timer := 0.0
	var lifetime := 0.0
	var fading := false


func _ready() -> void:
	_spawn_chunks()
	_spawn_blood()


func _physics_process(delta: float) -> void:
	for piece in _pieces:
		if piece.fading:
			continue
		piece.lifetime += delta
		if piece.landed:
			piece.rest_timer += delta
			if piece.rest_timer >= piece.rest_duration:
				_start_fade(piece, CHUNK_FADE_DURATION if piece.is_chunk else randf_range(BLOOD_FADE_MIN, BLOOD_FADE_MAX))
			continue
		# Garde-fou : débris jamais retombé (fosse, hors écran) → fondu forcé
		if piece.lifetime >= (CHUNK_MAX_LIFETIME if piece.is_chunk else BLOOD_MAX_LIFETIME):
			_start_fade(piece, CHUNK_FADE_DURATION)
			continue

		var body := piece.body
		body.velocity.y += GRAVITY * delta
		body.rotation += piece.angular_speed * delta
		body.move_and_slide()

		if body.get_slide_collision_count() > 0:
			var normal := body.get_slide_collision(0).get_normal()
			if piece.is_chunk and not piece.has_bounced:
				# Premier contact : un seul rebond à ~30 %, culbute amortie
				piece.has_bounced = true
				piece.angular_speed *= 0.4
				body.velocity = body.velocity.bounce(normal) * BOUNCE_RESTITUTION
				if body.velocity.length() < STOP_SPEED:
					_land(piece)
			else:
				_land(piece)

	# Nettoyage des débris disparus ; plus rien à afficher → auto-suppression
	_pieces = _pieces.filter(func(piece: Piece) -> bool: return is_instance_valid(piece.body))
	if _pieces.is_empty():
		queue_free()


## Pose le débris au sol : vitesse et rotation figées, compte à rebours
## avant le fondu (court pour le sang, plus long pour les morceaux)
func _land(piece: Piece) -> void:
	piece.landed = true
	piece.angular_speed = 0.0
	piece.body.velocity = Vector2.ZERO
	if not piece.is_chunk:
		piece.rest_duration = 0.0


func _start_fade(piece: Piece, duration: float) -> void:
	piece.fading = true
	var tween := piece.body.create_tween()
	tween.tween_property(piece.body, "modulate:a", 0.0, duration)
	tween.tween_callback(piece.body.queue_free)


func _spawn_chunks() -> void:
	for i in randi_range(chunk_count_min, chunk_count_max):
		var piece := Piece.new()
		piece.is_chunk = true
		piece.body = _make_body(4.0)

		var sprite := Sprite2D.new()
		sprite.texture = CHUNK_TEXTURES.pick_random()
		sprite.texture_filter = TEXTURE_FILTER_NEAREST
		sprite.rotation = randf_range(0.0, TAU)
		# Morceaux 2 fois plus gros que les sprites d'origine
		sprite.scale = Vector2.ONE * randf_range(1.6, 2.4)
		piece.body.add_child(sprite)

		piece.body.rotation = randf_range(0.0, TAU)
		piece.angular_speed = randf_range(-10.0, 10.0)
		piece.rest_duration = randf_range(CHUNK_REST_MIN, CHUNK_REST_MAX)
		piece.body.velocity = _ejection_velocity(CHUNK_CONE_DEG, CHUNK_SPEED_MIN, CHUNK_SPEED_MAX)
		_pieces.append(piece)


func _spawn_blood() -> void:
	for i in randi_range(blood_count_min, blood_count_max):
		var piece := Piece.new()
		piece.is_chunk = false
		piece.body = _make_body(2.0)

		var sprite := Sprite2D.new()
		sprite.texture = _get_pixel_texture()
		sprite.texture_filter = TEXTURE_FILTER_NEAREST
		sprite.modulate = BLOOD_COLORS.pick_random()
		# Texture 2x2 : scale 1.0-2.0 → gouttes de 2 à 4 px
		sprite.scale = Vector2.ONE * randf_range(1.0, 2.0)
		piece.body.add_child(sprite)

		piece.body.velocity = _ejection_velocity(BLOOD_CONE_DEG, BLOOD_SPEED_MIN, BLOOD_SPEED_MAX)
		_pieces.append(piece)


## Petit corps de débris : traverse tout sauf la tilemap (masque 12)
func _make_body(radius: float) -> CharacterBody2D:
	var body := CharacterBody2D.new()
	body.collision_layer = 0
	body.collision_mask = 12
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	body.add_child(shape)
	add_child(body)
	return body


## Vitesse d'éjection initiale : direction de l'attaque déviée dans un cône
## (± half_angle), vitesse aléatoire, plus une impulsion vers le haut pour
## que les débris « sautent » avant de retomber
func _ejection_velocity(half_angle_deg: float, speed_min: float, speed_max: float) -> Vector2:
	# Pas d'impulsion vers le haut : les débris partent droit dans le sens
	# de l'attaque (la gravité ne les fait s'incurver que sur la fin du vol)
	return direction.rotated(deg_to_rad(randf_range(-half_angle_deg, half_angle_deg))) \
			* randf_range(speed_min, speed_max)


## Texture 2x2 blanche du sang, créée une seule fois pour toutes les morts
static func _get_pixel_texture() -> ImageTexture:
	if _pixel_texture == null:
		var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_pixel_texture = ImageTexture.create_from_image(image)
	return _pixel_texture
