class_name DoorFade extends Node

## DoorFade — le fade de traversée d'une porte du Sorcerer : le fade
## d'arrivée (cinématique de sortie de porte d'entrée) et le fade de
## sortie (traversée de la porte de sortie de boutique/niveau). Les deux
## transitions miroirs partagent le même shader param (arrival_fade), le
## même fade du sac et la même durée. La porte raconte son événement,
## le module décide du reste (tweens, shader, exceptions de collision,
## fade du sac).

signal door_exit_done

## Durée du fade bas→haut et vitesse de décalage
const DOOR_EXIT_FADE_DURATION := 0.6
const DOOR_EXIT_WALK_SPEED := 120.0
## Durée du fondu de sortie : identique au fade d'arrivée
const EXIT_FADE_DURATION := DOOR_EXIT_FADE_DURATION
## Durée du retour express vers opaque quand le fondu est annulé
const EXIT_FADE_RETURN_DURATION := 0.2

var sorcier: Sorcerer

## La porte d'où ce sorcier sort (référence directe : dans les scènes à
## plusieurs portes, chercher par type retournerait toujours la première)
var _door_cine: EntryDoorCinematic = null

## Cinématique d'arrivée : phase en cours, gelée jusqu'à la refermeture
## de la porte. 0 = fade sur place, 1 = décalage latéral
var _door_exit_active := false
var _door_exit_phase := 0
var _door_exit_target := Vector2.ZERO
var _door_exit_decalage: int = 0   # sens du décalage : -1 gauche, +1 droite, 0 aucun
var _door_exit_dernier := false    # dernier sorti : prévient la porte de refermer
## Couche de collision d'origine, restaurée à la fin de la sortie de porte
var _collision_layer_origin: int = 1

## Fondu de sortie : actif et tween en cours
var _exit_fade_active: bool = false
var _exit_fade_tween: Tween = null


func setup(s: Sorcerer) -> void:
	sorcier = s


# ── Lien avec la porte d'entrée ─────────────────────────────────────────────

## Lier la porte d'entrée cinématique de cette scène (auto-inscription du
## sorcier au spawn : la porte déclenchera sa sortie via start_door_exit).
func link_door(porte: EntryDoorCinematic) -> void:
	_door_cine = porte


## Rompt le lien avec la porte (Shophands : tous les sorciers se sont
## auto-inscrits à leur spawn, mais seul le décideur en sort — la scène
## réinscrit ensuite le décideur seul).
func clear_door_link() -> void:
	_door_cine = null


## Vrai si ce sorcier est rattaché à une porte d'entrée cinématique
func has_entry_door_cinematic() -> bool:
	return _door_cine != null and is_instance_valid(_door_cine)


# ── Cinématique d'arrivée (sortie de la porte d'entrée) ─────────────────────

## Préparation au spawn (une porte d'entrée cinématique est présente) :
## le sorcier est gelé, invisible et fantôme pendant l'attente et le fade.
func prepare_arrival_cinematic() -> void:
	sorcier.frozen = true
	sorcier.get_node("AnimatedSprite2D").play("idle")
	# Sac invisible tant que la cinématique ne l'a pas révélé
	if sorcier.has_node("PipeManager"):
		sorcier.get_node("PipeManager").modulate.a = 0.0
	# Fantôme pendant l'attente et le fade : les sorciers attendent tous au
	# même point (le centre de la porte), sans se bloquer mutuellement
	_collision_layer_origin = sorcier.collision_layer
	sorcier.collision_layer = 0


## Le fade d'arrivée démarre invisible (le shader d'arrivée révèle le corps
## du bas vers le haut pendant la sortie de porte).
func apply_arrival_fade_0() -> void:
	sorcier.dash_shader_material.set_shader_parameter("arrival_fade", 0.0)


## Révélation immédiate d'un sorcier préparé pour la cinématique mais qui
## n'en sortira pas (Shophands : les receveurs apparaissent hors de la
## porte, directement visibles et solides). Le dégel reste à la charge
## de la scène (shop_hands débloque les receveurs à la fin de la
## cinématique du décideur).
func reveal_arrival() -> void:
	sorcier.collision_layer = _collision_layer_origin
	sorcier.dash_shader_material.set_shader_parameter("arrival_fade", 1.0)
	if sorcier.has_node("PipeManager"):
		sorcier.get_node("PipeManager").modulate.a = 1.0


## Sortie de porte (cinématique d'arrivée), appelée par la porte au tour du
## sorcier : fade d'opacité du bas vers le haut (anim walk sur place), puis
## décalage latéral vers target. `dernier` = ce sorcier est le dernier de la
## porte : quand son fade est fini, la porte se referme.
func start_door_exit(target: Vector2, dernier: bool) -> void:
	_door_exit_active = true
	_door_exit_phase = 0
	_door_exit_dernier = dernier
	# Sens du décalage déduit de la cible (la porte fournit la position
	# finale : centre = pas de décalage)
	_door_exit_decalage = 0
	if absf(target.x - sorcier.position.x) > 1.0:
		_door_exit_decalage = 1 if target.x > sorcier.position.x else -1
	_door_exit_target = target
	# Marche sur place pendant le fade (impression de sortir en marchant)
	sorcier.get_node("AnimatedSprite2D").play("walk")
	# Pose les pieds sur la ligne de sol réelle de la scène (le bas du
	# sprite de porte peut être enfoncé sous le sol selon les décors)
	_door_exit_snap_to_ground()
	# Sac invisible au départ : son fade démarre à la MOITIÉ du fade du corps
	if sorcier.has_node("PipeManager"):
		sorcier.get_node("PipeManager").modulate.a = 0.0
	# Fade bas → haut en DOOR_EXIT_FADE_DURATION (tween sur le paramètre shader)
	var tween := create_tween()
	tween.tween_method(_set_arrival_fade, 0.0, 1.0, DOOR_EXIT_FADE_DURATION)
	tween.tween_callback(_on_door_exit_fade_done)
	# Sac : fade 0 → 1 sur la 2e moitié du fade du corps (démarre à 50 %)
	if sorcier.has_node("PipeManager"):
		var tween_sac := create_tween()
		tween_sac.tween_interval(DOOR_EXIT_FADE_DURATION * 0.5)
		tween_sac.tween_property(sorcier.get_node("PipeManager"), "modulate:a", 1.0, DOOR_EXIT_FADE_DURATION * 0.5)


func _set_arrival_fade(v: float) -> void:
	sorcier.dash_shader_material.set_shader_parameter("arrival_fade", v)


func _on_door_exit_fade_done() -> void:
	# Fade terminé : le shader d'arrivée est désactivé (1.0 = tout visible,
	# aucun coût dans le shader), le sprite est un sprite normal
	_set_arrival_fade(1.0)
	# Sécurité : le sac est bien entièrement visible (son tween couvre la
	# 2e moitié du fade du corps, donc il vient de se terminer)
	if sorcier.has_node("PipeManager"):
		sorcier.get_node("PipeManager").modulate.a = 1.0
	if _door_exit_decalage == 0:
		# Rang centre (ou porte à un seul sorcier) : pas de décalage, la
		# sortie est déjà terminée
		_finish_door_exit()
	else:
		_door_exit_phase = 1
		sorcier.get_node("AnimatedSprite2D").flip_h = _door_exit_decalage < 0


func _finish_door_exit() -> void:
	_door_exit_active = false
	# Sorcier en place : idle (ne marche plus dans le vide), puis contrôles
	# immédiats — pas d'attente de la refermeture de la porte, qui n'est
	# que cosmétique. La collision est restaurée : il redevient solide.
	sorcier.get_node("AnimatedSprite2D").play("idle")
	sorcier.frozen = false
	sorcier.collision_layer = _collision_layer_origin
	# La sortie est complète : la porte peut faire sortir le suivant
	door_exit_done.emit()
	if _door_exit_dernier:
		# Dernier sorcier apparu : SA porte se referme (pendant que tout le
		# monde peut déjà jouer)
		if _door_cine != null and is_instance_valid(_door_cine):
			_door_cine.porte_dernier_sorcier_sorti()


func _physics_process(delta: float) -> void:
	# Cinématique d'arrivée : le sorcier est gelé pendant le fade sur
	# place ; ici on pilote uniquement le décalage latéral de fin de
	# sortie (marche contrôlée, pas d'inputs, pas de gravité).
	if _door_exit_active and _door_exit_phase == 1:
		var reste := _door_exit_target.x - sorcier.position.x
		if absf(reste) <= DOOR_EXIT_WALK_SPEED * delta:
			sorcier.position = Vector2(_door_exit_target.x, sorcier.position.y)
			_finish_door_exit()
		else:
			sorcier.position.x += signf(reste) * DOOR_EXIT_WALK_SPEED * delta


## Pose les pieds du sorcier sur la ligne de sol de la scène : ray vers le
## bas depuis le centre de la porte (même principe que le snap de la
## ronce P3). Le bas du sprite de porte peut être enfoncé sous le sol
## affiché selon les décors (ex. level : la porte est dans le socle) : si
## le départ du ray est DANS un solide, on remonte par paliers de 64 px
## jusqu'à trouver une face de sol praticable.
func _door_exit_snap_to_ground() -> void:
	var space_state := sorcier.get_world_2d().direct_space_state
	# Exclut tous les sorciers : les autres attendent au même point de la
	# porte et ne doivent pas servir de "sol"
	var exclude: Array[RID] = [sorcier.get_rid()]
	for player in sorcier.get_tree().get_nodes_in_group("player_group"):
		if player != sorcier and is_instance_valid(player):
			exclude.append(player.get_rid())
	var porte_global := sorcier.global_position
	if _door_cine != null and is_instance_valid(_door_cine):
		porte_global = _door_cine.global_position
	for palier in range(0, 5):
		var depart := porte_global + Vector2(0, -32.0 - 64.0 * palier)
		var query := PhysicsRayQueryParameters2D.create(
			depart, depart + Vector2(0, 500.0 + 64.0 * palier)
		)
		query.exclude = exclude
		var result := space_state.intersect_ray(query)
		# Ne retient qu'une face orientée vers le haut (un vrai sol)
		if result and result["normal"].y < -0.5:
			sorcier.position.y = sorcier.get_parent().to_local(result["position"]).y - 32.0
			return


# ── Fondu de sortie (porte de sortie de boutique / de niveau) ───────────────

## Miroir du fade d'arrivée : tween arrival_fade 1 → 0 sur le même shader,
## sac en parallèle. Lancé par la porte de sortie (exit_doors.gd) quand un
## joueur entre dans sa zone ; la téléportation n'a lieu qu'à la fin du
## fondu (micro-validation par temps passé devant la porte). Si le joueur
## quitte la zone, la porte appelle cancel_exit_fade() : retour express
## vers opaque et progression réinitialisée (le prochain contact repart
## de zéro).

## Démarre le fondu de sortie. `on_done` est appelé à la fin du fondu :
## validation définitive (la porte téléporte alors tout le monde).
func start_exit_fade(on_done: Callable) -> void:
	if _exit_fade_active:
		return
	_exit_fade_active = true
	# Fantôme vis-à-vis des autres joueurs pendant le fondu, SANS toucher
	# aux collision_layers : l'Area2D de la porte détecte les corps via
	# collision_mask — un layer à 0 la ferait "perdre" le sorcier
	# (body_exited immédiat) et annulerait le fondu aussitôt. Les
	# exceptions n'affectent que les contacts entre corps.
	for other in sorcier.get_tree().get_nodes_in_group("player_group"):
		if other != sorcier and other is Node2D:
			sorcier.add_collision_exception_with(other)
	# Départ du fondu : valeur actuelle du shader (1.0 en jeu normal)
	var depart: float = sorcier.dash_shader_material.get_shader_parameter("arrival_fade")
	_exit_fade_tween = create_tween()
	_exit_fade_tween.set_parallel(true)
	_exit_fade_tween.tween_method(_set_arrival_fade, depart, 0.0, EXIT_FADE_DURATION)
	if sorcier.has_node("PipeManager"):
		_exit_fade_tween.tween_property(sorcier.get_node("PipeManager"), "modulate:a", 0.0, EXIT_FADE_DURATION)
	_exit_fade_tween.chain().tween_callback(_finish_exit_fade.bind(on_done))


## Annule le fondu en cours (joueur sorti de la zone de la porte) :
## retour express vers opaque, progression repartira de zéro au prochain
## contact. Sans effet si le fondu est déjà terminé (validation
## définitive) ou jamais démarré.
func cancel_exit_fade() -> void:
	if not _exit_fade_active:
		return
	_exit_fade_active = false
	_remove_exit_fade_exceptions()
	if _exit_fade_tween != null and _exit_fade_tween.is_valid():
		_exit_fade_tween.kill()
	_exit_fade_tween = null
	# Retour express corps + sac vers l'opacité normale
	var depart: float = sorcier.dash_shader_material.get_shader_parameter("arrival_fade")
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_arrival_fade, depart, 1.0, EXIT_FADE_RETURN_DURATION)
	if sorcier.has_node("PipeManager"):
		tween.tween_property(sorcier.get_node("PipeManager"), "modulate:a", 1.0, EXIT_FADE_RETURN_DURATION)


## Fin du fondu : plus rien à annuler, la téléportation est lancée.
func _finish_exit_fade(on_done: Callable) -> void:
	_exit_fade_active = false
	_exit_fade_tween = null
	_remove_exit_fade_exceptions()
	on_done.call()


func _remove_exit_fade_exceptions() -> void:
	for other in sorcier.get_tree().get_nodes_in_group("player_group"):
		if other != sorcier and other is Node2D:
			sorcier.remove_collision_exception_with(other)
