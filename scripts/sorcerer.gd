class_name Sorcerer
extends CharacterBody2D

const SPRITE_SIZE = 64

## Effet cosmétique de lancement de sort : forme lumineuse derrière le
## sorcier (carré/triangle/rond selon le tube, couleur de l'élément)
const CAST_SHAPE := preload("res://scenes/outils/cast_shape.tscn")

## Munitions d'un tube mises à jour (tube_index, nouveau montant) :
## le HUD et le PipeManager rafraîchissent l'affichage du compteur.
signal ammo_changed(tube_index: int, ammo_amount: int)
## Sort chargé dans un tube (tube_index, dictionnaire du sort) : le
## PipeManager met à jour l'icône du tuyau correspondant.
signal spell_changed(tube_index: int, spell: Dictionary)
signal life_changed
## Émis à la fin de la sortie de porte (fade + décalage terminés) : la
## porte chaîne la sortie du sorcier suivant dessus
signal door_exit_done

@export var speed: int = 400
var jump_pressed_time: float = 0.0
var is_jumping: bool = false
@export var max_jump_time: float = 0.3 # durée max que l'on peut "charger" le saut en secondes
@export var jump_impulse_min: int = 600 # saut minimal
@export var jump_impulse_max: int = 5000 # saut maximal
@export var fall_acceleration: int = 3000

# --- Wall slide / Wall jump ---
@export var wall_slide_max_fall_speed: int = 150 # vitesse de chute max pendant une glissade contre un mur
@export var wall_slide_max_duration: float = 0.5 # durée max de la glissade ralentie (ensuite on re-chute normalement)
@export var wall_jump_impulse: int = 900 # impulsion verticale fixe du wall jump (plus haut que jump_impulse_min)
@export var wall_jump_horizontal_impulse: int = 500 # impulsion horizontale de base, opposée au mur
@export var wall_jump_stick_influence: float = 0.4 # à quel point le stick modifie la direction du wall jump

# --- Squash & Stretch (effets PUREMENT VISUELS sur le sprite) ---
# Ces paramètres ne touchent JAMAIS la physique : seule l'échelle/rotation
# du sprite change, autour d'un pivot posé aux pieds (astuce offset de la
# scène). Le squash ponctuel (tween) et le stretch procédural se composent
# multiplicativement à chaque frame (cf. _maj_sprite).
@export_group("Squash & Stretch")
@export var anticipation_force := 0.12      # compression avant saut (proportion de la taille)
@export var anticipation_duree := 0.1       # durée du squash d'anticipation (s)
@export var stretch_force := 0.15           # étirement max en montée (proportion)
@export var stretch_vitesse_max := 600.0    # px/s de montée → étirement maximal
@export var atterrissage_force := 0.15      # squash max à l'impact (proportion)
@export var atterrissage_duree := 0.18      # durée du squash d'atterrissage (s)
@export var rebond_force := 0.05            # overshoot (léger étirement) après le squash
@export var atterrissage_vitesse_max := 1200.0 # px/s d'impact → squash maximal
@export var inclinaison_force := 5.0        # degrés d'inclinaison max en course
@export var inclinaison_lissage := 10.0     # vitesse du lissage de l'inclinaison (par s)
@export var sorcerer_color: GlobalEnum.SorcererColor
var controller_id: int = 0
# Device physique dont on lit les entrées : distinct de controller_id
# (identité/données immuables) pour qu'une manette de remplacement puisse
# prendre le contrôle d'un joueur déconnecté. -1 = non initialisé.
var input_device: int = -1
# Sorcier d'affichage (écran de pause) : idle + soulèvement de tuyaux
# uniquement — ni physique, ni déplacement, ni saut, ni attaque, ni dash
var frozen: bool = false
# Traversée de porte (cinématique d'arrivée + fondu de sortie) : le module
# DoorFade décide des tweens, du shader, des exceptions de collision et du
# fade du sac. Les portes appellent le Sorcerer : la façade délègue au
# module (une seule chose à connaître pour les portes : le Sorcerer).
@onready var door_fade: DoorFade = $DoorFade

# Fumée de contact : le Sorcerer raconte ses événements (atterrissage,
# décollage, glissade, wall jump) — le module Dust décide du rendu
# (seuil, éventail, teinte par la surface).
@onready var dust: Dust = $Dust


## Vrai si ce sorcier est rattaché à une porte d'entrée cinématique
func _has_entry_door_cinematic() -> bool:
	return door_fade.has_entry_door_cinematic()


## Sortie de porte (cinématique d'arrivée), appelée par EntryDoorCinematic
## au tour du sorcier : délègue au module DoorFade (fade, décalage, snap).
func start_door_exit(target: Vector2, dernier: bool) -> void:
	door_fade.start_door_exit(target, dernier)

# --- Fondu de sortie (porte de sortie de boutique / de niveau) ---
# Miroir du fade d'arrivée : le module DoorFade possède les deux transitions
# (tweens, shader, exceptions de collision, fade du sac).

## Démarre le fondu de sortie. `on_done` est appelé à la fin du fondu :
## validation définitive (la porte téléporte alors tout le monde).
func start_exit_fade(on_done: Callable) -> void:
	door_fade.start_exit_fade(on_done)

## Annule le fondu en cours (joueur sorti de la zone de la porte) :
## retour express vers opaque, progression repartira de zéro au prochain
## contact. Sans effet si le fondu est déjà terminé (validation
## définitive) ou jamais démarré.
func cancel_exit_fade() -> void:
	door_fade.cancel_exit_fade()

# --- Dash ---
@export var dash_speed: int = 1200
@export var dash_duration: float = 0.1 # durée du dash en secondes
@export var dash_cooldown: float = 1.0 # temps avant de pouvoir redasher
@export var dash_invisible_alpha: float = 0.25 # transparence pendant le dash
# (l'invincibilité du dash — pendant et post-dash — vit dans le module
# Protection : post_dash_duration)
@export var dash_ignore_groups: Array[String] = ["enemy_group", "player_group"] # groupes à traverser pendant le dash
@export var dash_unstuck_distance: float = 40.0 # distance en dessous de laquelle on considère 2 joueurs "superposés" en fin de dash
@export var dash_unstuck_push: float = 24.0 # écart appliqué pour les séparer proprement
@export var dash_trail_interval: float = 0.01 # secondes entre deux images rémanentes
@export var dash_trail_fade_duration: float = 0.2 # temps de disparition d'une image rémanente
@export var dash_trail_start_alpha: float = 1.0 # opacité de départ d'une image rémanente (1.0 = 100%)

var is_dashing: bool = false
var can_dash: bool = true
# Matériau des traînées de dash (créé à la première traînée, partagé par
# toutes : mêmes couleurs, white_amount figé à 1)
var _dash_trail_material: ShaderMaterial = null
var dash_direction: Vector2 = Vector2.RIGHT
var dash_shader_material: ShaderMaterial
var dash_trail_accumulator: float = 0.0

var lives: int = 3
var screen_size: Vector2
var direction: Vector2 = Vector2.RIGHT
## Dernière direction de visée NON NEUTRE (stick ou touches). Recalée à
## chaque frame où une direction est pressée : au moment du tir, elle vaut
## donc la direction tenue. Si AUCUNE direction n'est tenue au moment du
## tir, l'attaque part devant le sorcier (sens du regard, cf. fire_attack) —
## notamment après un saut clavier, dont la touche EST la touche « haut ».
var aim_direction: Vector2 = Vector2.RIGHT
var energy_counts: Array = [3, 3, 3]  # Fossil, Pure, Tainted
# Maximum de munitions par tube (0 à 4 : le HUD ne couvre que cet intervalle)
const MAX_ENERGY := 4
var in_shop: bool = false
## Vrai tant que le sorcier est enfermé dans une cabine : ses boutons
## d'attaque alimentent la cabine (via Cabin.appui_bouton) et ne doivent
## ni sélectionner un tube du sac, ni tirer. Posé/levé par la cabine.
var cabin_lock: bool = false
## Sur la homepage : les attaques sont utilisables et la mort déclenche un
## respawn après 1,5 s (géré par le cadavre), jamais le game over.
var in_homepage: bool = false
# Tuyaux soulevables hors boutique (écran home) : X/Y/B font sortir les
# tuyaux comme en boutique, sans pouvoir tirer
var tubes_selectable: bool = false
var selected_tube: int = -1
var can_fire: bool = true
## Façade duck-typing (les boss lisent body.get("can_take_damage") avant
## d'appeler hit()) : lecture seule, la source de vérité est le module
## Protection. Pour rendre intouchable : hit() / dash_started() du module.
var can_take_damage: bool:
	get:
		return not $Protection.is_untouchable()
var level_scale: Vector2

# Après une détonation de mine, on attend le relâchement du bouton
# avant d'autoriser un nouveau tir (sinon le bouton encore maintenu
# re-pose une mine aussitôt)
var fire_wait_release := {
	0: false,  # Fossil (Tube 1)
	1: false,  # Pure (Tube 2)
	2: false,  # Tainted (Tube 3)
}

# État précédent des boutons de tube (front montant pour la sélection en boutique)
var tube_buttons_prev := {
	0: false,
	1: false,
	2: false,
}

var spells: Dictionary = {}

var is_jump_long_press: bool = false

# --- Wall slide / Wall jump ---
var is_wall_sliding: bool = false # vrai pendant une glissade contre un mur
var wall_slide_timer: float = 0.0 # temps de glissade accumulé pour la durée max
var jump_button_prev: bool = false # état du bouton A à la frame précédente (front montant pour le wall jump)
var last_wall_jump_side: int = 0 # côté du mur du dernier wall jump (-1 = mur à gauche, +1 = mur à droite) ; 0 = réarmé (sol touché)

# --- Fumée de contact (atterrissage, mur, glissade, wall jump) ---
# Bouffée de pixels blanc-gris (famille « matière », blending NORMAL —
# la poussière masque la lumière, elle ne l'ajoute pas) qui jaillit aux
# instants où le corps rencontre une surface, style Dead Cells :
# atterrissage, premier contact d'une glissade murale, poussée du wall
# jump, et émission continue pendant la glissade. Le Sorcerer raconte
# l'événement (position de contact, force) : le module Dust décide du
# rendu (seuil, éventail, teinte par la surface).
var etait_au_sol: bool = false       # is_on_floor() de la frame précédente (détection d'atterrissage)
var etait_en_glissade: bool = false  # glissade de la frame précédente (détection du contact du mur)

# --- Squash & stretch : état des effets visuels ---
var _squash_tween: Tween = null       # tween d'anticipation ou d'atterrissage en cours
var _squash_x := 0.0                  # écart d'échelle horizontale du tween ponctuel
var _squash_y := 0.0                  # écart d'échelle verticale du tween ponctuel
var _inclinaison := 0.0               # rotation lissée de course (radians)

var current_state: GlobalEnum.State = GlobalEnum.State.IDLE
# Vrai tant que l'animation d'attaque cosmétique est en cours (elle est
# alors coupée par un changement d'état, ou relancée par un nouveau tir)
var is_playing_attack: bool = false

var hit_knockback_velocity: Vector2 = Vector2.ZERO
var hit_knockback_timer: float = 0.0

func _ready() -> void:
	add_to_group("player_group")
	# Le module DoorFade reçoit la référence au sorcier AVANT l'auto-inscription
	# (le link de porte ci-dessous passe par le module) et relaie son signal
	# de fin de sortie : la porte écoute la façade du Sorcerer.
	door_fade.setup(self)
	door_fade.door_exit_done.connect(func(): door_exit_done.emit())
	# Le module Dust reçoit la référence au sorcier : la fumée de contact
	# s'attache au niveau (le parent du sorcier) et échantillonne la
	# surface du TileMapLayer du niveau.
	dust.setup(self)
	# Nouvelle run : réarme le verrou du fondu de game over (variable static,
	# elle persiste sinon d'une partie à l'autre)
	_game_over_fade_started = false
	screen_size = get_viewport_rect().size
	level_scale = get_parent().transform.get_scale()
	var slot := PlayerManager.get_player_slot(controller_id)
	# Apparition aux portes d'entrée du terrain1 si la scène en contient :
	# - une seule porte → joueurs écartés autour d'elle (level, magasins) ;
	# - plusieurs portes → une porte par joueur, triées de la plus haute à
	#   la plus basse (ex. magasin course : 1 couloir par joueur).
	# Sinon (Home, écran de pause) : ancien point central.
	var entry_doors: Array = []
	for child in get_parent().get_children():
		if child is Node2D and String(child.name).begins_with("Terrain1PortesEntree"):
			entry_doors.append(child)
	if not entry_doors.is_empty():
		# Tri (y, puis x) : ordre déterministe quand plusieurs portes partagent
		# la même hauteur (ex. intro 4 joueurs : haut-gauche, haut-droite,
		# bas-gauche, bas-droite). Le rang d'un joueur identifie alors toujours
		# la même porte, et le couloir inactif (scellé) est toujours le dernier.
		entry_doors.sort_custom(func(a, b):
			if not is_equal_approx(a.position.y, b.position.y):
				return a.position.y < b.position.y
			return a.position.x < b.position.x)
		var active_ids := PlayerManager.active_player_ids()
		var rank: int = active_ids.find(controller_id)
		if rank == -1:
			rank = slot
		if entry_doors.size() > 1:
			var door: Node2D = entry_doors[rank % entry_doors.size()]
			# Un seul sorcier par porte (course : 1 couloir/joueur) : il
			# reste au centre, sans décalage. Pieds posés sur la ligne de
			# sol de cette scène (snap, cf. _door_exit_snap_to_ground)
			position = door.position + Vector2(0, 32.0)
			var door_cine := door as EntryDoorCinematic
			if door_cine != null:
				door_cine.inscrire_sorcier(self, 0)
				door_fade.link_door(door_cine)
		else:
			var door: Node2D = entry_doors[0]
			# Départ au centre de la porte, pieds posés sur la ligne de sol
			# de cette scène (snap, cf. _door_exit_snap_to_ground) : la
			# sortie le décalera ensuite
			position = door.position + Vector2(0, 32.0)
			var door_cine := door as EntryDoorCinematic
			if door_cine != null:
				door_cine.inscrire_sorcier(self, rank)
				door_fade.link_door(door_cine)
	else:
		position = (1.4 * screen_size / 2) + Vector2(slot * 64, 128)
		position += Vector2(0, SPRITE_SIZE * slot)
	if input_device == -1:
		input_device = controller_id
	# Le PipeManager (sac visuel) reçoit la référence au sorcier AVANT
	# load_data() : le refresh_all final de load_data se branchera sur
	# l'état réellement chargé
	if has_node("PipeManager"):
		$PipeManager.setup(self)
	# Le module Protection reçoit la référence au sorcier et signale les
	# coups reçus : les vies sont décrémentées ici, la mort reste au Sorcerer.
	if has_node("Protection"):
		$Protection.setup(self)
		$Protection.hit_taken.connect(_on_protection_hit_taken)
	load_data()
	lives = 3

	# Cinématique d'arrivée : si une porte d'entrée est présente dans la
	# scène, le sorcier démarre invisible (fade arrival_fade 0) et gelé.
	# La porte déclenche sa sortie via start_door_exit(). Sans porte
	# (homepage, écran de pause) : apparition classique immédiate.
	# NB : le matériau du sorcier est créé plus bas dans _ready (les
	# sous-ressources d'une scène sont partagées entre instances, chaque
	# joueur a besoin de ses propres couleurs de shader) → le fade 0 est
	# appliqué juste après sa création (voir _apply_arrival_fade_0)
	if _has_entry_door_cinematic():
		door_fade.prepare_arrival_cinematic()
	else:
		$AnimatedSprite2D.play("walk")

	if not $AnimatedSprite2D.animation_finished.is_connected(_on_attack_animation_finished):
		$AnimatedSprite2D.animation_finished.connect(_on_attack_animation_finished)

	$DashDuration.wait_time = dash_duration
	$DashDuration.one_shot = true
	if not $DashDuration.timeout.is_connected(_on_dash_duration_timeout):
		$DashDuration.timeout.connect(_on_dash_duration_timeout)
	$DashCooldown.wait_time = dash_cooldown
	$DashCooldown.one_shot = true
	if not $DashCooldown.timeout.is_connected(_on_dash_cooldown_timeout):
		$DashCooldown.timeout.connect(_on_dash_cooldown_timeout)

	# Matériau créé à chaud (et non réutilisé depuis le .tscn) : les
	# sous-ressources d'une scène sont partagées entre toutes les instances,
	# or chaque joueur a besoin de ses propres couleurs de shader
	dash_shader_material = ShaderMaterial.new()
	dash_shader_material.shader = preload("res://assets/shaders/wizard_color.gdshader")
	WizardPalette.apply_to_material(dash_shader_material, sorcerer_color)
	$AnimatedSprite2D.material = dash_shader_material
	# Le sorcier arrive par une porte : invisible tant que la cinématique
	# d'arrivée ne l'a pas fait sortir (le fade est animé via le shader)
	if frozen and _has_entry_door_cinematic():
		door_fade.apply_arrival_fade_0()


func set_state(new_state: GlobalEnum.State) -> void:
	if current_state == new_state:
		return
	
	current_state = new_state
	is_playing_attack = false
	_play_state_animation(new_state)


func _play_state_animation(state: GlobalEnum.State) -> void:
	match state:
		GlobalEnum.State.IDLE:
			$AnimatedSprite2D.play("idle")
			
		GlobalEnum.State.RUN:
			$AnimatedSprite2D.play("walk")
			
		GlobalEnum.State.JUMP:
			$AnimatedSprite2D.play("jump")
			
		GlobalEnum.State.FALL:
			$AnimatedSprite2D.play("fall")


func _play_attack_animation() -> void:
	var sprite := $AnimatedSprite2D
	is_playing_attack = true
	# stop() pour rejouer depuis la frame 0 si une attaque est déjà en cours
	sprite.stop()
	sprite.play("attack_fire")


func _on_attack_animation_finished() -> void:
	if not is_playing_attack:
		return
	is_playing_attack = false
	# Retour automatique à l'animation de l'état courant
	_play_state_animation(current_state)
			
		
func _process(_delta: float) -> void:
	# Détection front montant (juste-appuyé) pour les 3 boutons de tube,
	# mise à jour chaque frame pour ne rater aucun appui
	var jx := _tube_button_just_pressed(0)
	var jy := _tube_button_just_pressed(1)
	var jb := _tube_button_just_pressed(2)

	if frozen:
		# Sorcier d'affichage (écran de pause) : uniquement le soulèvement
		# des tuyaux ; le bouton de saut est réservé à la jauge Reprendre
		if jx:
			select_tube(0)
		elif jy:
			select_tube(1)
		elif jb:
			select_tube(2)
		return

	var new_direction = PlayerInput.direction(input_device)
	if new_direction.length() > 0.2:
		direction = new_direction
		aim_direction = new_direction
	else:
		direction = Vector2(Vector2.RIGHT.dot(direction), 0.00001).normalized() * 0.1
	if direction.x < -0.2:
		$AnimatedSprite2D.flip_h = true
	elif direction.x > 0.2:
		$AnimatedSprite2D.flip_h = false

	if can_fire and not is_dashing and not cabin_lock:
		if jx:
			if in_shop:
				select_tube(0)
			else:
				fire_attack(0)
		elif jy:
			if in_shop:
				select_tube(1)
			else:
				fire_attack(1)
		elif jb:
			if in_shop:
				select_tube(2)
			else:
				fire_attack(2)
	elif tubes_selectable and not is_dashing and not cabin_lock:
		# Écran home (et autres écrans sans tir) : les tuyaux se soulèvent
		# comme en boutique, sans déclencher d'attaque
		if jx:
			select_tube(0)
		elif jy:
			select_tube(1)
		elif jb:
			select_tube(2)

	if can_dash and not is_dashing:
		if PlayerInput.button_pressed(input_device, PlayerInput.Action.DASH):
			start_dash()
			
	if not PlayerInput.button_pressed(input_device, PlayerInput.Action.JUMP):
		is_jump_long_press = false

	

func _physics_process(delta: float) -> void:
	# (Le décalage latéral de fin de sortie de porte est piloté par le
	# module DoorFade, qui a son propre _physics_process.)

	# Sorcier d'affichage : aucune physique (il resterait sinon en chute
	# sur l'écran de pause, et le bouton de saut le ferait sauter)
	if frozen:
		return

	# Effets visuels procéduraux (stretch, inclinaison) : lisent la
	# vélocité sans jamais l'écrire, aucun impact gameplay
	_update_effets_visuels(delta)

	if is_dashing:
		velocity = dash_direction * dash_speed
		move_and_slide()
		if is_dash_blocked():
			stop_dash_on_collision()
			return

		dash_trail_accumulator += delta
		if dash_trail_accumulator >= dash_trail_interval:
			dash_trail_accumulator = 0.0
			spawn_dash_afterimage()
		return

	# Ciblage L2 en cours : le sorcier est immobile (c'est la cible qui est
	# pilotée par le stick), mais la gravité continue s'il était en l'air.
	# Le second appui sur le tube L2 (explosion) reste géré dans _process/fire_attack.
	if _get_own_light_target() != null:
		velocity.x = 0
		if not is_on_floor():
			velocity.y += fall_acceleration * delta
		move_and_slide()
		set_state(GlobalEnum.State.FALL if not is_on_floor() else GlobalEnum.State.IDLE)
		return

	# Ronce P3 en croissance : le sorcier est immobile (il dirige la pousse
	# avec le stick), la gravité continue s'il était en l'air. Pendant le
	# vol de la graine (FLYING), il reste libre de ses mouvements.
	var own_bramble := _get_own_bramble()
	if own_bramble != null and own_bramble.is_growing():
		velocity.x = 0
		if not is_on_floor():
			velocity.y += fall_acceleration * delta
		move_and_slide()
		set_state(GlobalEnum.State.FALL if not is_on_floor() else GlobalEnum.State.IDLE)
		return

	# Mouvements horizontaux
	var axis := PlayerInput.direction(input_device)
	if axis.x < -0.2:
		velocity.x = -speed
	elif axis.x > 0.2:
		velocity.x = speed
	else:
		velocity.x = 0

	# Saut + nuancier
	if is_on_floor() and PlayerInput.button_pressed(input_device, PlayerInput.Action.JUMP) and !is_jump_long_press:
		is_jump_long_press = true
		jump_pressed_time = 0.0
		velocity.y = -jump_impulse_min
		set_state(GlobalEnum.State.JUMP)
		# Anticipation visuelle en PARALLÈLE (aucun délai d'input) : le
		# sorcier semble jaillir du sol en se décompressant. Pas d'effet
		# équivalent au wall jump : la chute l'étire déjà, et le mur a
		# son nuage de poussière.
		_lancer_anticipation()
		# Décollage : même bouffée qu'à l'atterrissage (pieds, éventail
		# latéral), force indexée sur l'impulsion du saut — la fumée
		# reste au point de départ, elle matérialise l'envol
		dust.jump_takeoff(_position_pieds(), jump_impulse_min)

	# --- Dead Cells style hit flash & blink ---
	# (le clignotement de dégât est piloté par le module Protection)

	# Knockback basé sur la direction du dash
	if hit_knockback_timer > 0:
		hit_knockback_timer -= delta
		velocity = hit_knockback_velocity
		# Le knockback décroît progressivement
		hit_knockback_velocity = hit_knockback_velocity.lerp(Vector2.ZERO, delta * 8.0)
		move_and_slide()
		# Pendant le knockback, on ignore les inputs et la gravité
		return

	if PlayerInput.button_pressed(input_device, PlayerInput.Action.JUMP) and is_jump_long_press:
		jump_pressed_time += delta
		if jump_pressed_time <= max_jump_time:
			var t = jump_pressed_time / max_jump_time
			var jump_boost = (jump_impulse_max - jump_impulse_min) * (1 - t) * delta
			velocity.y -= jump_boost

	# Détection du mur (1A) : on cherche une collision quasi verticale
	# (normale horizontale) pour connaître le côté du mur.
	# is_on_wall() reflète le move_and_slide de la frame précédente.
	var wall_side := 0
	if not is_on_floor() and is_on_wall():
		for i in get_slide_collision_count():
			var normal := get_slide_collision(i).get_normal()
			if abs(normal.x) > 0.7 and abs(normal.y) < 0.5:
				# normale pointant vers la droite → mur à notre gauche, et inversement
				wall_side = -1 if normal.x > 0 else 1
				break

	# Glissade (1A) : en l'air, collé au mur, stick poussé vers le mur.
	# La glissade ralentie est limitée dans le temps : au-delà de
	# wall_slide_max_duration on re-chute normalement (le wall jump reste possible).
	var axis_x := axis.x
	var touching_wall := wall_side != 0 and axis_x * wall_side > 0.2 and velocity.y > 0
	if touching_wall:
		wall_slide_timer += delta
		# Fumée au premier contact du mur (proportionnelle à la vitesse de
		# chute à l'impact), puis émission continue légère tant que la
		# glissade dure (les bottes raclent le mur)
		if not etait_en_glissade:
			dust.wall_slide_start(_position_contact_mur(wall_side), wall_side, absf(velocity.y))
		else:
			dust.wall_slide_tick(_position_contact_mur(wall_side), wall_side, delta)
	else:
		wall_slide_timer = 0.0 # on repose le compteur dès qu'on quitte le mur
		dust.wall_slide_end()
	etait_en_glissade = touching_wall
	is_wall_sliding = touching_wall and wall_slide_timer <= wall_slide_max_duration

	# Gravité (réduite pendant la glissade : la chute est plafonnée)
	if not is_on_floor():
		if is_wall_sliding:
			velocity.y = min(velocity.y + fall_acceleration * delta, wall_slide_max_fall_speed)
		else:
			velocity.y += fall_acceleration * delta

	# Wall jump (2B/3B/4) : A en l'air au contact d'un mur.
	# Front montant uniquement : maintenir A ne déclenche pas le wall jump,
	# il faut un nouvel appui (sinon un saut au sol suivi du maintien de A
	# contre un mur redéclencherait un wall jump automatiquement).
	var jump_button_pressed := PlayerInput.button_pressed(input_device, PlayerInput.Action.JUMP)
	var jump_button_just_pressed := jump_button_pressed and not jump_button_prev
	jump_button_prev = jump_button_pressed
	if not is_on_floor() and wall_side != 0 and jump_button_just_pressed:
		# 2B : un seul wall jump par mur — l'autre mur ou le sol réarme
		if last_wall_jump_side != wall_side:
			last_wall_jump_side = wall_side

			# La poussée déloge un VRAI nuage au point de contact du mur :
			# force maximale (la vitesse de chute est ici plafonnée par la
			# glissade, trop basse pour le seuil), et particules partant en
			# MAJORITÉ vers le bas (la poussière délogée tombe le long du mur).
			# mur_cote clampe l'arrivée du côté libre : sans lui, l'éventail
			# vers le bas renverrait une moitié des particules DANS le mur.
			dust.wall_jump(_position_contact_mur(wall_side), wall_side)

			# 4 : impulsion diagonale opposée au mur, légèrement modulée par le stick.
			# Pousser plus loin du mur écarte la trajectoire, pousser vers le mur la resserre,
			# mais impossible de sauter DANS le mur.
			var jump_h := float(-wall_side)
			if abs(axis_x) > 0.2:
				jump_h = clampf(jump_h + axis_x * wall_jump_stick_influence, -1.0, 1.0)

			velocity.x = jump_h * wall_jump_horizontal_impulse
			velocity.y = -wall_jump_impulse
			# 3B : impulsion fixe, on bloque le nuancier (pas de boost en maintenant A)
			is_jump_long_press = true
			jump_pressed_time = max_jump_time
			set_state(GlobalEnum.State.JUMP)

	# Physique
	var vitesse_avant := velocity.y
	move_and_slide()

	# Mise à jour des états
	if is_on_floor():
		last_wall_jump_side = 0 # le sol réarme le wall jump (2B)
		# Atterrissage : transition air → sol avec une vitesse de chute
		# suffisante → bouffée proportionnelle à l'impact
		if not etait_au_sol and vitesse_avant > 0.0:
			dust.landing(_position_pieds(), vitesse_avant)
			# Squash d'impact, force ∝ vitesse d'atterrissage (mêmes
			# données que la fumée) ; l'overshoot fait le rebond discret
			_lancer_squash_atterrissage(clampf(vitesse_avant / atterrissage_vitesse_max, 0.25, 1.0))
		if abs(velocity.x) > 0:
			set_state(GlobalEnum.State.RUN)
		else:
			set_state(GlobalEnum.State.IDLE)
	else:
		if velocity.y > 0:
			set_state(GlobalEnum.State.FALL)
	etait_au_sol = is_on_floor()


func spawn_dash_afterimage() -> void:
	var afterimage = Sprite2D.new()
	afterimage.texture = $AnimatedSprite2D.sprite_frames.get_frame_texture($AnimatedSprite2D.animation, $AnimatedSprite2D.frame)

	get_parent().add_child(afterimage) # on l'ajoute à l'arbre AVANT de fixer son transform global

	afterimage.global_position = $AnimatedSprite2D.global_position
	afterimage.global_rotation = $AnimatedSprite2D.global_rotation
	afterimage.global_scale = $AnimatedSprite2D.global_scale
	afterimage.flip_h = $AnimatedSprite2D.flip_h
	# Même offset que le sprite (pivot aux pieds) : la traînée s'étend
	# vers le haut depuis son origine, exactement comme le corps — et
	# elle hérite de la pose déformée (inclinaison/squash) en cours,
	# ce qui renforce la lecture du mouvement
	afterimage.offset = $AnimatedSprite2D.offset
	afterimage.z_index = z_index + 10 # au-dessus de tout pour être visible

	# Dupliqué pour hériter aussi des couleurs du shader (sinon les
	# traînées de dash apparaîtraient avec la palette rouge de base).
	# Matériau de traînée mis en cache par sorcier : toutes les traînées
	# partagent les mêmes paramètres (white_amount = 1, palette du
	# propriétaire) — dupliquer à chaque image rémanente (~100/s pendant
	# un dash) allouait un matériau pour rien.
	if _dash_trail_material == null:
		_dash_trail_material = dash_shader_material.duplicate()
		_dash_trail_material.set_shader_parameter("white_amount", 1.0)
	afterimage.material = _dash_trail_material
	afterimage.modulate.a = dash_trail_start_alpha

	# Crée le tween directement sur l'afterimage pour une meilleure gestion
	var trail_tween = afterimage.create_tween()
	trail_tween.set_parallel(false)
	trail_tween.set_trans(Tween.TRANS_LINEAR)
	trail_tween.set_ease(Tween.EASE_IN)
	trail_tween.tween_property(afterimage, "modulate:a", 0.0, dash_trail_fade_duration)
	trail_tween.tween_callback(Callable(afterimage, "queue_free"))


func is_dash_blocked() -> bool:
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		# On ne considère bloquant que si la surface touchée s'oppose réellement
		# à la direction du dash (ex: un mur en pleine face), pas le sol quand on dash à l'horizontale
		if dash_direction.dot(collision.get_normal()) < -0.1:
			return true
	return false


# --- Squash & stretch : implémentation ---

## Mise à jour par frame des effets CONTINUS (aucun impact gameplay :
## la vélocité n'est que lue). Stretch : uniquement à la montée (la
## descente et le sommet retrouvent la taille normale avant
## l'atterrissage). Inclinaison : cible ∝ vitesse horizontale, lissée
## exponentiellement (retour doux à 0° à l'arrêt).
func _update_effets_visuels(delta: float) -> void:
	var cible := clampf(velocity.x / float(speed), -1.0, 1.0) * deg_to_rad(inclinaison_force)
	_inclinaison = lerpf(_inclinaison, cible, 1.0 - exp(-inclinaison_lissage * delta))
	_maj_sprite()


## Applique au sprite la composition procédural (stretch/inclinaison)
## × squash ponctuel (tween). SEUL endroit où le sprite est transformé.
func _maj_sprite() -> void:
	var f := clampf(-velocity.y / stretch_vitesse_max, 0.0, 1.0)
	var sprite := $AnimatedSprite2D
	sprite.scale = Vector2(
		(1.0 - stretch_force * f * 0.5) * (1.0 + _squash_x),
		(1.0 + stretch_force * f) * (1.0 + _squash_y))
	sprite.rotation = _inclinaison


## Anticipation du saut : tween PUREMENT PARALLÈLE (le saut part
## instantanément, l'effet se joue par-dessus la montée).
func _lancer_anticipation() -> void:
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_method(_appliquer_anticipation, 0.0, 1.0, anticipation_duree)


## Courbe de l'anticipation : compression (0→35 %), retour (35→70 %),
## puis taille normale — le stretch de la montée prend le relais.
func _appliquer_anticipation(t: float) -> void:
	if t < 0.35:
		var s := t / 0.35
		_squash_x = anticipation_force * s
		_squash_y = -anticipation_force * s
	elif t < 0.7:
		var s := (t - 0.35) / 0.35
		_squash_x = anticipation_force * (1.0 - s)
		_squash_y = -anticipation_force * (1.0 - s)
	else:
		_squash_x = 0.0
		_squash_y = 0.0
	_maj_sprite()


## Squash d'atterrissage : force entre 0 et 1 (∝ vitesse d'impact).
func _lancer_squash_atterrissage(force: float) -> void:
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_method(_appliquer_squash_atterrissage.bind(force), 0.0, 1.0, atterrissage_duree)


## Courbe du squash d'atterrissage : impact (0→25 %), tenue (25→50 %),
## overshoot vers un léger étirement (50→80 %), retour discret
## (80→100 %). L'amplitude suit la force d'impact.
func _appliquer_squash_atterrissage(t: float, force: float) -> void:
	if t < 0.25:
		var s := t / 0.25
		_squash_x = atterrissage_force * force * s
		_squash_y = -atterrissage_force * force * s
	elif t < 0.5:
		_squash_x = atterrissage_force * force
		_squash_y = -atterrissage_force * force
	elif t < 0.8:
		var s := (t - 0.5) / 0.3
		_squash_x = atterrissage_force * force * (1.0 - s) - rebond_force * force * s
		_squash_y = -atterrissage_force * force * (1.0 - s) + rebond_force * force * s
	else:
		var s := (t - 0.8) / 0.2
		_squash_x = -rebond_force * force * (1.0 - s)
		_squash_y = rebond_force * force * (1.0 - s)
	_maj_sprite()


## Position globale des pieds du sorcier (bas de la capsule de collision),
## scale du corps compris. Le décalage de remontée (2 px au-dessus de la
## surface) appartient au module Dust — les pieds flottent JUSTE au-dessus
## du sol.
func _position_pieds() -> Vector2:
	var forme := $CollisionShape2D as CollisionShape2D
	if forme == null or not forme.shape is CapsuleShape2D:
		return global_position
	var capsule := forme.shape as CapsuleShape2D
	return global_position + Vector2(forme.position.x, forme.position.y + capsule.height * 0.5) * scale \
		+ Vector2(0, -Dust.FEET_LIFT)


## Point de contact avec le mur du côté `wall_side` (-1 = gauche, +1 = droite),
## sur le flanc de la capsule (+2 px pour ne pas être DANS le mur).
func _position_contact_mur(wall_side: int) -> Vector2:
	var forme := $CollisionShape2D as CollisionShape2D
	var rayon := 10.0
	if forme != null and forme.shape is CapsuleShape2D:
		rayon = (forme.shape as CapsuleShape2D).radius
	return global_position + Vector2(wall_side * (rayon + 2.0), 0) * scale


func stop_dash_on_collision() -> void:
	if not is_dashing:
		return
	$DashDuration.stop() # on annule le temps de dash restant, on l'a déjà géré manuellement
	velocity = Vector2.ZERO # on ne garde pas l'élan du dash au moment de l'impact
	end_dash()


func start_dash() -> void:
	# Dasher pendant un ciblage (arc L3 ou cible L2) annule l'attaque
	# (munition rendue)
	_cancel_light_bow()
	_cancel_light_target()
	# Dasher pendant la croissance d'une ronce (P3) la gèle sur place
	# (la munition est déjà consommée au 1er appui, rien à rendre)
	_freeze_own_bramble()
	is_dashing = true
	can_dash = false

	# On dash dans la direction actuelle du stick, ou dans le sens du regard
	# si le stick est au repos (ATTENTION : pas de "flip_h and -1 or 1" —
	# en GDScript, and/or renvoient un booléen, donc toujours +1 = droite !)
	if direction.length() > 0.2:
		dash_direction = direction.normalized()
	else:
		dash_direction = Vector2(-1.0 if $AnimatedSprite2D.flip_h else 1.0, 0)

	for group_name in dash_ignore_groups:
		for body in get_tree().get_nodes_in_group(group_name):
			if body != self and body is Node2D:
				add_collision_exception_with(body)

	$AnimatedSprite2D.modulate.a = dash_invisible_alpha
	dash_shader_material.set_shader_parameter("white_amount", 1.0)
	# L'invincibilité du dash est décidée par le module Protection : le
	# Sorcerer raconte son dash, le module gère la fenêtre (et la fenêtre
	# post-dash à la fin).
	$Protection.dash_started()

	dash_trail_accumulator = 0.0
	spawn_dash_afterimage()

	$DashDuration.start()


func end_dash() -> void:
	is_dashing = false

	for group_name in dash_ignore_groups:
		for body in get_tree().get_nodes_in_group(group_name):
			if body != self and body is Node2D:
				remove_collision_exception_with(body)

	unstick_from_other_players()

	$AnimatedSprite2D.modulate.a = 1.0
	dash_shader_material.set_shader_parameter("white_amount", 0.0)
	# L'invincibilité continue après le dash via la fenêtre post-dash
	# (gérée par le module Protection)
	$Protection.dash_ended()
	$DashCooldown.start()


func unstick_from_other_players() -> void:
	for body in get_tree().get_nodes_in_group("player_group"):
		if body == self or not body is Node2D:
			continue
		var distance_to_body = position.distance_to(body.position)
		if distance_to_body < dash_unstuck_distance:
			var push_direction = position - body.position
			if push_direction.length() < 0.01:
				push_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
			position += push_direction.normalized() * dash_unstuck_push


func set_attack(tube_index: int, attack_type: int, attack_tier: int) -> void:
	if tube_index < 0 or tube_index >= 3:
		return
	spells[tube_index] = {
		"attack_type": attack_type,
		"attack_tier": attack_tier
	}
	# Le tier d'une attaque dépend du nombre d'attaques du même élément :
	# on re-normalise pour que TOUTES les attaques de cet élément montent
	# au bon tier (collecter un 2e feu passe aussi le 1er feu en tier II)
	SpellRules.normalize_spell_tiers(spells)
	# Notifie le sac visuel pour mettre à jour l'icône du sort du tube
	spell_changed.emit(tube_index, spells[tube_index])
	# En boutique : un échange vient de charger un sort → le tube se
	# referme seul après un court délai (le sort est déjà chargé, le
	# tube relevé n'a plus d'utilité)
	if in_shop:
		get_tree().create_timer(TUBE_CLOSE_DELAY).timeout.connect(
			_close_tube_after_swap.bind(tube_index))

## Délai (s) avant refermeture automatique du tube après un échange en
## boutique (objet attrapé et converti en sort)
const TUBE_CLOSE_DELAY := 0.8

## Fermeture automatique du tube après échange en boutique : rabaisse le
## tube (anim reverse) et désélectionne (selected_tube = -1). Ne ferme que
## si le tube rempli est toujours celui sélectionné (si le joueur a déjà
## sélectionné un autre tube entre-temps, on ne touche à rien).
func _close_tube_after_swap(tube_index: int) -> void:
	if not is_inside_tree() or selected_tube != tube_index:
		return
	var previous := selected_tube
	selected_tube = -1
	if has_node("PipeManager"):
		$PipeManager.apply_selection(-1, previous)

## Referme d'autorité le tube sélectionné, sans appui joueur. Appelée par
## la cabine à l'enfermement (le sac est masqué pendant le rituel : il ne
## doit pas réapparaître avec un tube levé — la fermeture après échange ne
## concerne que le tube qui a reçu l'objet) et par les portes de sortie
## (les tubes se rabattent dès que le sorcier quitte la boutique). Sans
## effet si aucun tube n'est sélectionné.
func fermer_tube_selectionne() -> void:
	if selected_tube == -1:
		return
	var previous := selected_tube
	selected_tube = -1
	if has_node("PipeManager"):
		$PipeManager.apply_selection(-1, previous)

func fire_attack(tube_index: int) -> void:
	if tube_index < 0 or tube_index >= 3:
		return
	# Impossible de tirer pendant la phase de magasin
	if in_shop:
		return
	# Ni enfermé dans une cabine (défense en profondeur)
	if cabin_lock:
		return
	var spell = spells[tube_index]
	if spell.is_empty():
		return
	
	var attack_type: int = spell["attack_type"]
	var attack_tier: int = spell["attack_tier"]
	
	# Pendant un ciblage (L2 ou L3), le sorcier ne peut pas lancer une autre
	# attaque : seul le second appui sur le tube du ciblage en cours est
	# autorisé (le L3 reste libre de ses mouvements, lui)
	var own_light_target := _get_own_light_target()
	var own_light_bow := _get_own_light_bow()
	if own_light_bow != null and attack_type != GlobalEnum.AttackType.L3:
		return
	if own_light_target != null and attack_type != GlobalEnum.AttackType.L2:
		return
	
	# Ronce P3 en croissance : le lanceur ne peut pas lancer une autre
	# attaque. 2e appui pendant la croissance → gel ; pendant le vol de la
	# graine → rien à geler, on ignore (pas de nouvelle munition consommée)
	var own_bramble := _get_own_bramble()
	if own_bramble != null and attack_type != GlobalEnum.AttackType.P3:
		return
	if attack_type == GlobalEnum.AttackType.P3 and own_bramble != null:
		if own_bramble.is_growing():
			own_bramble.freeze_growth()
		# Verrou de relâchement : éviter de re-geler tant que le bouton est maintenu
		fire_wait_release[tube_index] = true
		return
	
	# Cible lumineuse L2 : le 2e appui déclenche l'explosion du curseur
	if attack_type == GlobalEnum.AttackType.L2:
		var light_target := own_light_target
		if light_target != null:
			light_target.start_explosion()
			fire_wait_release[tube_index] = true
			return

	# Arc lumineux L3 : le 2e appui tire la flèche
	if attack_type == GlobalEnum.AttackType.L3 and own_light_bow != null:
		if not own_light_bow.try_shoot():
			# Tir annulé (sorcier trop proche de l'arc) : l'arc disparaît
			# et la munition du tube est rendue
			add_energy(tube_index, 1)
		# Verrou de relâchement : éviter un nouveau tir tant que le bouton
		# est maintenu
		fire_wait_release[tube_index] = true
		return

	# Mine posée en idle par ce joueur : le 2e appui déclenche la chute
	# et l'explosion au lieu de poser une nouvelle mine (sans consommer d'énergie)
	if attack_type == GlobalEnum.AttackType.F3:
		var mine := _get_own_mine()
		if mine != null:
			mine.explode()
			# Verrou de relâchement : éviter le re-déclenchement tant que le bouton est maintenu
			fire_wait_release[tube_index] = true
			return
	
	# Consomme l'énergie du tube (un seul geste : décrément + signal)
	if not consume_energy(tube_index, 1):
		return
	$AttackCooldown.start()
	can_fire = false
	_play_attack_animation()
	
	# Après la pose d'une mine : attendre le relâchement du bouton avant
	# le prochain tir (le 2e appui servira à déclencher l'explosion)
	if attack_type == GlobalEnum.AttackType.F3:
		fire_wait_release[tube_index] = true
	
	# Direction de tir : si AUCUNE direction n'est indiquée au moment du
	# tir (stick au repos, aucune touche), l'attaque part à l'horizontal
	# dans la direction du REGARD — pas vers le haut : au clavier, la touche
	# de saut EST la touche « haut » (W / flèche haut), et sans cette règle
	# l'attaque tirée après un saut partait vers le haut. Pour viser en
	# hauteur (ou en diagonale), il faut maintenir la direction au moment
	# du tir — même règle que le dash, déjà « sens du regard » si le stick
	# est au repos.
	var shoot_direction := aim_direction
	if PlayerInput.direction(input_device).length() <= 0.2:
		shoot_direction = Vector2(-1.0 if $AnimatedSprite2D.flip_h else 1.0, 0)
	
	var attack_list := AttackSpawner.spawn_attack(attack_type, attack_tier, position, shoot_direction, screen_size, level_scale, self)
	for attack in attack_list:
		self.get_parent().add_child(attack)
	_spawn_cast_shape(tube_index, attack_type)


## Forme lumineuse de lancement, derrière le sorcier. Forme = tube
## (carré Fossil / triangle Pure / rond Tainted), couleur = élément du
## sort. Appelée après _play_attack_animation : les 2es appuis L2/L3/mine
## sont déjà repartis plus haut, l'effet ne joue que sur un vrai tir.
func _spawn_cast_shape(tube_index: int, attack_type: int) -> void:
	var shape: CastShape = CAST_SHAPE.instantiate()
	shape.shape_kind = [
		CastShape.Shape.Square,
		CastShape.Shape.Triangle,
		CastShape.Shape.Circle,
	][tube_index]
	shape.element = _cast_element(attack_type)
	add_child(shape)


## Élément d'un type d'attaque : la première lettre du nom (F/G/L/P)
## donne la famille (Feu, Glace, Lumière, Plante)
func _cast_element(attack_type: int) -> CastShape.Element:
	match attack_type:
		GlobalEnum.AttackType.F0, GlobalEnum.AttackType.F1, \
		GlobalEnum.AttackType.F2, GlobalEnum.AttackType.F3:
			return CastShape.Element.Feu
		GlobalEnum.AttackType.G1, GlobalEnum.AttackType.G2, \
		GlobalEnum.AttackType.G3:
			return CastShape.Element.Glace
		GlobalEnum.AttackType.L1, GlobalEnum.AttackType.L2, \
		GlobalEnum.AttackType.L3:
			return CastShape.Element.Lumiere
		_:
			return CastShape.Element.Plante

# Lit le bouton d'attaque du tube : renvoie true seulement si
# le bouton est pressé ET que le verrou de relâchement n'est pas actif.
# Si le verrou est actif, il se lève dès que le bouton est relâché.
func _fire_button_pressed(tube_index: int) -> bool:
	var pressed := PlayerInput.button_pressed(input_device, _tube_button(tube_index))
	if fire_wait_release.get(tube_index, false):
		if not pressed:
			fire_wait_release[tube_index] = false
		return false
	return pressed

# Front montant : renvoie true uniquement à l'instant où le bouton passe
# de relâché à appuyé (un seul appel par appui, contrairement à is_joy_button_pressed
# qui renvoie true à chaque frame tant que le bouton est maintenu).
# Essentiel en boutique : sans ça, select_tube est rappelé chaque frame et
# le tube se referme aussitôt sorti.
func _tube_button_just_pressed(tube_index: int) -> bool:
	var pressed := PlayerInput.button_pressed(input_device, _tube_button(tube_index))
	var was_pressed: bool = tube_buttons_prev.get(tube_index, false)
	tube_buttons_prev[tube_index] = pressed
	return pressed and not was_pressed


## Bouton logique d'un tube d'attaque (0/1/2 → ATK1/ATK2/ATK3)
func _tube_button(tube_index: int) -> PlayerInput.Action:
	match tube_index:
		0: return PlayerInput.Action.ATK1
		1: return PlayerInput.Action.ATK2
		_: return PlayerInput.Action.ATK3

func select_tube(tube_index: int) -> void:
	if tube_index < 0 or tube_index >= 3:
		return
	# Le Sorcerer DÉCIDE (source de vérité) : ré-appui sur le tube sorti
	# → refermeture (désélection), sinon bascule vers le nouveau tube.
	# selected_tube doit refléter l'état réel, sinon un objet pourrait
	# être attrapé dans un tube descendu (la règle d'attrapage en
	# boutique teste selected_tube)
	var previous := selected_tube
	selected_tube = -1 if selected_tube == tube_index else tube_index
	if has_node("PipeManager"):
		$PipeManager.apply_selection(selected_tube, previous)
	# Si un tube vient de s'OUVRIR, relance l'attrapage des objets déjà
	# en contact : le sorcier peut être immobile sur un objet depuis
	# avant l'ouverture, et aucun body_entered ne repartira — sans cette
	# relance, l'objet n'est attrapé qu'après un déplacement du sorcier.
	if in_shop and selected_tube != -1:
		for node in get_tree().get_nodes_in_group("attack_object_group"):
			var objet := node as AttackObject
			if objet != null:
				objet.essayer_attraper(self)

# Cherche une mine posée par CE joueur encore en phase idle.
# Caches : ces recherches sont appelées chaque frame physique (cible
# lumineuse et ronce) — un scan complet du groupe à chaque appel coûterait
# 4 joueurs × 60 fps. On ne re-scanne que si le cache est invalide
# (libéré, plus le nôtre, ou phase changée).
var _own_mine_cache: AttackFireMine = null
var _own_light_target_cache: AttackLightTarget = null
var _own_light_bow_cache: AttackLightBow = null
var _own_bramble_cache: AttackPlantBramble = null

func _get_own_mine() -> AttackFireMine:
	var cache := _own_mine_cache
	if cache != null and is_instance_valid(cache) and cache.caster == self \
			and cache.phase == AttackFireMine.Phase.IDLE:
		return cache
	for node in get_tree().get_nodes_in_group("fire_mine_group"):
		var mine := node as AttackFireMine
		if mine != null and mine.caster == self and mine.phase == AttackFireMine.Phase.IDLE:
			_own_mine_cache = mine
			return mine
	return null

# Cherche la cible lumineuse posée par CE joueur encore en phase TARGETING
func _get_own_light_target() -> AttackLightTarget:
	var cache := _own_light_target_cache
	if cache != null and is_instance_valid(cache) and cache.caster == self \
			and cache.phase == AttackLightTarget.Phase.TARGETING:
		return cache
	for node in get_tree().get_nodes_in_group("light_target_group"):
		var target := node as AttackLightTarget
		if target != null and target.caster == self and target.phase == AttackLightTarget.Phase.TARGETING:
			_own_light_target_cache = target
			return target
	return null

# Cherche l'arc lumineux planté par CE joueur encore en phase TARGETING
func _get_own_light_bow() -> AttackLightBow:
	var cache := _own_light_bow_cache
	if cache != null and is_instance_valid(cache) and cache.caster == self \
			and cache.phase == AttackLightBow.Phase.TARGETING:
		return cache
	for node in get_tree().get_nodes_in_group("light_bow_group"):
		var bow := node as AttackLightBow
		if bow != null and bow.caster == self and bow.phase == AttackLightBow.Phase.TARGETING:
			_own_light_bow_cache = bow
			return bow
	return null

# Cherche la ronce plantée par CE joueur encore en phase FLYING (graine
# en vol) ou GROWING (croissance dirigée)
func _get_own_bramble() -> AttackPlantBramble:
	var cache := _own_bramble_cache
	if cache != null and is_instance_valid(cache) and cache.caster == self \
			and (cache.phase == AttackPlantBramble.Phase.FLYING \
			or cache.phase == AttackPlantBramble.Phase.GROWING):
		return cache
	for node in get_tree().get_nodes_in_group("plant_bramble_group"):
		var bramble := node as AttackPlantBramble
		if bramble != null and bramble.caster == self \
				and (bramble.phase == AttackPlantBramble.Phase.FLYING \
				or bramble.phase == AttackPlantBramble.Phase.GROWING):
			_own_bramble_cache = bramble
			return bramble
	return null

# Gèle la ronce en croissance de CE joueur (dash ou 2e appui) : elle reste
# en place 2 s puis se décompose (munition déjà consommée, rien à rendre)
func _freeze_own_bramble() -> void:
	var bramble := _get_own_bramble()
	if bramble != null:
		bramble.freeze_growth()

# Annule l'arc lumineux planté par CE joueur et rend la munition du tube
# qui le porte (le ciblage a déjà coûté 1 munition au 1er appui)
func _cancel_light_bow() -> void:
	var bow := _get_own_light_bow()
	if bow == null:
		return
	for i in range(3):
		var spell: Dictionary = spells[i]
		if not spell.is_empty() and spell["attack_type"] == GlobalEnum.AttackType.L3:
			add_energy(i, 1)
			break
	bow.cancel()

# Annule la cible lumineuse (L2) de CE joueur et rend la munition du tube
# qui la porte (le ciblage a déjà coûté 1 munition au 1er appui)
func _cancel_light_target() -> void:
	var target := _get_own_light_target()
	if target == null:
		return
	for i in range(3):
		var spell: Dictionary = spells[i]
		if not spell.is_empty() and spell["attack_type"] == GlobalEnum.AttackType.L2:
			add_energy(i, 1)
			break
	target.cancel()

func add_energy(tube_index: int, amount: int) -> void:
	energy_counts[tube_index] = min(energy_counts[tube_index] + amount, MAX_ENERGY)
	ammo_changed.emit(tube_index, energy_counts[tube_index])


## Consomme des munitions d'un tube en UN seul geste : décrémente la
## source de vérité ET émet le signal de mise à jour (le sac rafraîchit
## alors le tuyau). Utiliser TOUJOURS cette fonction pour consommer —
## jamais un décrément direct suivi d'une émission manuelle.
func consume_energy(tube_index: int, amount: int) -> bool:
	if tube_index < 0 or tube_index >= 3:
		return false
	if energy_counts[tube_index] < amount:
		return false
	energy_counts[tube_index] -= amount
	ammo_changed.emit(tube_index, energy_counts[tube_index])
	return true


## Vrai tant que ce sorcier ne peut pas être blessé : dash (pendant et
## 0,5 s après), délai après un dégât reçu, et toute future source
## d'invincibilité. Les attaques qui ciblent (ex. têtes carnivores P1)
## s'en servent pour ne pas viser ni consommer une proie invincible —
## un dash est une esquive totale. Façade : la source de vérité est le
## module Protection.
func is_untouchable() -> bool:
	return $Protection.is_untouchable()


## Délègue au module Protection (source de vérité de l'invincibilité,
## du feedback et du knockback). Le module émet hit_taken() : les vies
## sont décrémentées ici (la mort reste au Sorcerer).
func hit(damage: int) -> void:
	$Protection.hit(damage)


## Réception d'un coup passé à travers la Protection : vies puis mort.
func _on_protection_hit_taken(damage: int) -> void:
	lives -= damage
	life_changed.emit(lives)
	if lives == 0:
		die()


# Anti-double-déclenchement : si plusieurs sorciers meurent dans la même
# fenêtre de 2 s (quasi simultanément), un seul fondu doit être lancé.
static var _game_over_fade_started: bool = false


func die() -> void:
	export_data()
	# Le corps reste au sol comme une "ragdoll" (bond léger + frame 0 de
	# l'animation death) au lieu de disparaître. Le sorcier lui-même est
	# libéré : il renaît au magasin suivant, et le cadavre s'effacera
	# tout seul à ce moment-là. Sur la homepage, le cadavre fait au
	# contraire RE-SPAWNER le joueur après 1,5 s (valeurs par défaut).
	var corpse := SorcererCorpse.from_sorcerer(self, 1.5 if in_homepage else -1.0)
	# Ajout différé obligatoire : die() peut être appelée depuis un callback
	# physique (ex: _on_explosion_body_entered), et on ne peut pas ajouter un
	# corps à l'arbre pendant que le serveur physique flushe ses requêtes.
	get_parent().add_child.call_deferred(corpse)
	# La partie continue tant qu'il reste au moins un joueur en vie :
	# seul la mort de TOUS les joueurs ramène à l'écran d'accueil
	queue_free()
	if not in_homepage and not _other_players_alive():
		# Game over : reset complet de la run (vague, durée, sorts, vies et
		# énergies de chaque manette) — la run suivante repart du début.
		# Sans ça, les données exportées à la mort (export_data) et le
		# niveau de vague atteint seraient rechargés au prochain spawn.
		# NB : jamais sur la homepage — les joueurs y ressuscitent tous.
		Run.reset_run()
		if not _game_over_fade_started:
			_game_over_fade_started = true
			_fade_to_homepage()


# Game over : fondu au noir de 2 s avant le retour à l'écran d'accueil.
func _fade_to_homepage() -> void:
	# Overlay noir plein écran au-dessus de tout (HUD compris)
	var layer := CanvasLayer.new()
	layer.name = "GameOverFade"
	layer.layer = 100
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Bloque les inputs pendant le fondu (et le retour à l'accueil)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(overlay)
	# Ajout différé : die() peut venir d'un callback physique
	get_tree().root.add_child.call_deferred(layer)

	# Tween porté par l'arbre (et non par ce sorcier, sur le point d'être
	# libéré) : il survit au changement de scène jusqu'au callback final
	var tween := get_tree().create_tween()
	tween.tween_property(overlay, "color:a", 1.0, 2.0)
	tween.tween_callback(Global.goto_scene.bind(GlobalEnum.Location.HOMEPAGE))
	# Réarme le verrou statique pour le prochain game over (le static survit
	# au changement de scène : sans reset, un 2e game over ne referait rien)
	tween.tween_callback(func() -> void: Sorcerer._game_over_fade_started = false)
	# L'overlay vit sur la racine : il survivrait sinon au changement de
	# scène et laisserait un écran noir permanent au-dessus de la homepage
	tween.tween_callback(layer.queue_free)


# Y a-t-il encore au moins un joueur (autre que ce sorcier) en vie ?
# Les joueurs morts ont été libérés (queue_free) : leur référence reste
# dans PlayerManager.players mais est invalide, d'où le is_instance_valid.
# La variable n'est volontairement PAS typée : assigner une instance
# libérée à une variable typée plante avant même la vérification.
func _other_players_alive() -> bool:
	for id in PlayerManager.known_controllers:
		if id == controller_id:
			continue
		var player = PlayerManager.players.get(id)
		if player != null and is_instance_valid(player) and player.is_inside_tree():
			return true
	return false


func export_data() -> void:
	Run.save_sorcerer(self)

func load_data() -> void:
	Run.load_sorcerer(self)
	SpellRules.normalize_spell_tiers(spells)
	
	# Le PipeManager (déjà branché via setup()) se resynchronise avec les
	# valeurs réellement chargées (munitions + sorts + icônes)
	if has_node("PipeManager"):
		$PipeManager.refresh_all()

func _on_attack_cooldown_timeout() -> void:
	can_fire = true


func _on_dash_duration_timeout() -> void:
	end_dash()


func _on_dash_cooldown_timeout() -> void:
	can_dash = true

func _on_save_data() -> void:
	export_data()
