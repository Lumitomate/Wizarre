class_name Protection extends Node

## Protection du sorcier : décide s'il est intouchable et orchestre les
## conséquences d'un coup (flash rouge, knockback, label de dégâts).
##
## Source de vérité unique de l'invincibilité. Les trois sources
## (cooldown de dégât, dash en cours, fenêtre post-dash) se composent :
## is_untouchable() lit les trois, il n'y a PLUS de course entre timers
## (le bug historique : un DamageCooldown qui expirait pendant un dash
## réactivait la vulnérabilité en plein dash). Chaque source garde son
## propre état ; rien ne se réécrit jamais.
##
## L'état des VIES reste au Sorcerer : après un coup, le module émet
## hit_taken() et le Sorcerer décrémente ses vies (et gère la mort).
## Le knockback est calculé ICI mais appliqué par la physique du
## Sorcerer (le module écrit hit_knockback_velocity/timer sur le sorcier,
## qui les lit dans sa physique).
##
## Référence au Sorcerer injectée via setup() (cf. PipeManager) — aucun
## get_parent() : la dépendance est explicite et testable.

## Un coup est passé à travers : le Sorcerer décrémente ses vies et gère
## la mort (le module ne connaît pas les vies).
signal hit_taken(damage: int)

@export var damage_cooldown_duration: float = 0.7
@export var post_dash_duration: float = 0.5
@export var flash_duration: float = 0.5
@export var flash_interval: float = 0.05

## Durée de l'impulsion de knockback (le Sorcerer l'applique dans sa
## physique pendant ce temps, puis l'amortit).
const KNOCKBACK_DURATION := 0.3
const KNOCKBACK_FORCE := 1000.0
const KNOCKBACK_LIFT := -200.0

## Sorcier protégé (injecté via setup()). Source de l'écriture du
## knockback et de l'accès au sprite (flash) et au label de dégâts.
var sorcier: Sorcerer = null

var damage_label_scene: PackedScene = preload("res://scenes/hud/hud_damage_label.tscn")

# --- Sources d'invincibilité (indépendantes, se composent) ---
var dash_active: bool = false
var _damage_cooldown: Timer
var _post_dash: Timer

# --- Clignotement de dégât (feedback Dead Cells style) ---
var _flash_running: bool = false
var _flash_timer: float = 0.0


## Injection de la référence au Sorcerer. Appelé par le Sorcerer dans
## son _ready.
func setup(sorcier: Sorcerer) -> void:
	self.sorcier = sorcier


func _ready() -> void:
	_damage_cooldown = Timer.new()
	_damage_cooldown.one_shot = true
	_damage_cooldown.wait_time = damage_cooldown_duration
	add_child(_damage_cooldown)
	_post_dash = Timer.new()
	_post_dash.one_shot = true
	_post_dash.wait_time = post_dash_duration
	add_child(_post_dash)


## Interface : vrai tant que ce sorcier ne peut pas être blessé ni ciblé.
## Les attaques qui ciblent (ex. têtes carnivores P1) s'en servent pour
## ne pas viser ni consommer une proie invincible — un dash est une
## esquive totale.
func is_untouchable() -> bool:
	return dash_active or not _damage_cooldown.is_stopped() or not _post_dash.is_stopped()


## Interface : un coup arrive. Sans effet si le sorcier est intouchable
## (cooldown de dégât, dash en cours, fenêtre post-dash). Sinon : feedback
## complet (flash, knockback, label) puis hit_taken() — le Sorcerer
## décrémente ses vies et gère la mort.
func hit(damage: int) -> void:
	if is_untouchable():
		return
	_damage_cooldown.start()
	_start_flash()
	_apply_knockback()
	_spawn_damage_label(damage)
	hit_taken.emit(damage)


## Interface : le Sorcerer raconte son dash (le module décide de
## l'invincibilité pendant et après). Appelé par start_dash().
func dash_started() -> void:
	dash_active = true


## Interface : fin du dash. L'invincibilité continue via la fenêtre
## post-dash ; le cooldown de dégât en cours, lui, n'est pas touché.
func dash_ended() -> void:
	dash_active = false
	_post_dash.start()


# --- Feedback d'un coup (flash, knockback, label) ---

## Flash rouge identique à celui du monstre (enemy_flying.gd) : montée
## au rouge vif en 0,05 s puis retour à la normale en 0,15 s. Passe par
## self_modulate pour ne pas interférer avec le modulate utilisé par le
## clignotement.
func _start_flash() -> void:
	var sprite := sorcier.get_node("AnimatedSprite2D")
	sprite.self_modulate = Color.WHITE
	var red_flash := sorcier.create_tween()
	red_flash.tween_property(sprite, "self_modulate", Color(1.0, 0.1, 0.1, 1.0), 0.05)
	red_flash.tween_property(sprite, "self_modulate", Color.WHITE, 0.15)
	_flash_running = true
	_flash_timer = 0.0  # délai avant le premier flash


func _process(delta: float) -> void:
	if not _flash_running:
		return
	var sprite := sorcier.get_node("AnimatedSprite2D")
	_flash_timer += delta
	# Clignotement : alterne entre rouge et transparent
	var blink := fmod(_flash_timer, flash_interval * 2.0)
	if blink < flash_interval:
		sprite.modulate = Color(2.0, 0.3, 0.3, 0.7)  # rouge
	else:
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.4)  # transparent
	if _flash_timer >= flash_duration:
		_flash_running = false
		_flash_timer = 0.0
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)  # reset


## Knockback basé sur la direction de l'ennemi (repoussé par lui). On
## cherche l'ennemi le plus proche (logique mutualisée dans EntityFinder).
## Sans ennemi : repoussé vers le haut, comme avant. La vélocité est
## écrite sur le sorcier : c'est SA physique qui l'applique.
func _apply_knockback() -> void:
	var plus_proche := EntityFinder.plus_proche(sorcier, sorcier.global_position, ["enemy_group"])
	var direction_knockback := Vector2.ZERO
	if plus_proche != null:
		direction_knockback = (sorcier.position - plus_proche.global_position).normalized()
	sorcier.hit_knockback_timer = KNOCKBACK_DURATION
	sorcier.hit_knockback_velocity = Vector2(
		direction_knockback.x * KNOCKBACK_FORCE,
		direction_knockback.y * KNOCKBACK_FORCE + KNOCKBACK_LIFT)


## NB : le label est instancié et positionné mais jamais ajouté à l'arbre
## (comportement hérité de l'ancien hit() — probable bug latent, à câbler).
func _spawn_damage_label(damage: int) -> void:
	var damage_label := damage_label_scene.instantiate()
	damage_label.position = sorcier.level_scale * (sorcier.position - Vector2(0, 64))
