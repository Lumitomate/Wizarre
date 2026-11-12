extends Area2D

signal shop_entered

## Délai entre deux cycles de l'anim d'attente (« waiting energy ») :
## même règle que l'ascenseur (cf. map_1_elevator.gd).
const DELAI_WAITING_ENERGY : float = 5.0

## Sorcier en train de fonder dans la porte (un seul à la fois : le
## premier arrivé). La téléportation n'est déclenchée qu'à la FIN de son
## fondu — micro-validation par temps passé devant la porte, cf.
## Sorcerer.start_exit_fade(). S'il quitte la zone avant la fin, le fondu
## est annulé (retour express vers opaque) et repartira de zéro.
var _fading_player: Node2D = null
## Verrou : dès que shop_entered a été émis, la porte n'écoute plus rien
## (rien ne doit démarrer pendant la fenêtre de changement de scène)
var _activated: bool = false

var _ouverture: AnimatedSprite2D
var _waiting_energy_sprite: AnimatedSprite2D
var _waiting_energy_timer: Timer

## API historique (du temps où la racine était elle-même le sprite) :
## le boss et les tests lisent l'état de l'anim d'ouverture via ces
## deux raccourcis. Ils visent TOUJOURS l'anim d'ouverture, jamais
## l'anim d'attente.
func is_playing() -> bool:
	return _ouverture.is_playing()

var frame: int :
	get:
		return _ouverture.frame
	set(value):
		_ouverture.frame = value

func _ready() -> void:
	$CollisionShape2D.disabled = true
	# Câblage complet ICI (la scène ne porte aucune connexion) : une
	# refonte de l'arbre dans l'éditeur ne peut plus perdre le câblage.
	if not body_entered.is_connected(_on_area_2d_body_entered):
		body_entered.connect(_on_area_2d_body_entered)
	if not body_exited.is_connected(_on_area_2d_body_exited):
		body_exited.connect(_on_area_2d_body_exited)
	_ouverture = $AnimatedSprite2D_ouverture
	_ouverture.animation_finished.connect(_on_ouverture_finished)
	# ANIMATION D'ATTENTE (« waiting energy ») — même règle que
	# l'ascenseur : elle ne démarre qu'une fois l'ouverture TERMINÉE, puis
	# joue un cycle toutes les 5 s pour montrer que la SUITE DU NIVEAU
	# passe par la porte. Aucun rôle mécanique : la détection des joueurs
	# vit dans la zone de collision de cette Area2D, le timer vit ici.
	_waiting_energy_sprite = $AnimatedSprite2DWaintingEnergy
	_waiting_energy_sprite.visible = false
	_waiting_energy_sprite.animation_finished.connect(_on_waiting_energy_finished)
	_waiting_energy_timer = Timer.new()
	_waiting_energy_timer.wait_time = DELAI_WAITING_ENERGY
	_waiting_energy_timer.one_shot = false
	_waiting_energy_timer.autostart = false  # démarré à la fin de l'ouverture
	_waiting_energy_timer.timeout.connect(_on_waiting_energy_timeout)
	add_child(_waiting_energy_timer)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if _activated or _fading_player != null:
		return
	if body.is_in_group("player_group"):
		_fading_player = body
		body.start_exit_fade(_on_exit_fade_done)
		# Un tube levé (sélection en boutique) se rabat dès le fondu de
		# sortie : le sorcier quitte la boutique, les tubes sont tous bas
		# (en niveau, aucun tube n'est jamais sélectionné — sans effet).
		if body is Sorcerer:
			(body as Sorcerer).fermer_tube_selectionne()

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body == _fading_player:
		# Le joueur peut avoir été libéré (mort) pendant son fondu
		if is_instance_valid(body):
			body.cancel_exit_fade()
		_fading_player = null

## Referme la porte : zone coupée, fondu en cours annulé, anim d'ouverture
## remise à zéro et clignotement d'attente coupé. Sert à la règle « on ne
## quitte pas la pièce pendant le rituel de la cabine » : le magasin
## referme la porte tant qu'un sorcier occupe la cabine. Une réouverture
## (play()) relancera le clignotement après la nouvelle anim d'ouverture.
func fermer() -> void:
	if _activated:
		return
	$CollisionShape2D.set_deferred("disabled", true)
	if _fading_player != null and is_instance_valid(_fading_player):
		(_fading_player as Sorcerer).cancel_exit_fade()
	_fading_player = null
	_arreter_attente()
	_ouverture.stop()
	_ouverture.frame = 0

## Joue l'anim d'ouverture (une seule fois : anim non bouclée). À la fin,
## la zone de sortie s'active et le clignotement d'attente démarre.
func play() -> void:
	_ouverture.play(&"default")

func _on_ouverture_finished() -> void:
	$CollisionShape2D.disabled = false
	_waiting_energy_timer.start()

func _on_waiting_energy_timeout() -> void:
	_waiting_energy_sprite.visible = true
	_waiting_energy_sprite.play(&"default")

## Fin d'un cycle de l'anim d'attente (l'anim « default » doit rester NON
## bouclée dans la scène, sinon ce signal n'arrive jamais) : on re-cache.
func _on_waiting_energy_finished() -> void:
	_waiting_energy_sprite.stop()
	_waiting_energy_sprite.visible = false

## Coupe le clignotement d'attente (fermeture de la porte ou fin de
## partie) : plus de timer, plus de sprite visible.
func _arreter_attente() -> void:
	_waiting_energy_timer.stop()
	_waiting_energy_sprite.stop()
	_waiting_energy_sprite.visible = false

func _on_exit_fade_done() -> void:
	_fading_player = null
	_activated = true
	# Porte désactivée après validation (hygiène : aucun nouveau fondu ne
	# doit démarrer avant le free de la scène, différé d'une frame)
	$CollisionShape2D.set_deferred("disabled", true)
	_arreter_attente()
	shop_entered.emit()
