extends AnimatedSprite2D

signal shop_entered

## Sorcier en train de fonder dans la porte (un seul à la fois : le
## premier arrivé). La téléportation n'est déclenchée qu'à la FIN de son
## fondu — micro-validation par temps passé devant la porte, cf.
## Sorcerer.start_exit_fade(). S'il quitte la zone avant la fin, le fondu
## est annulé (retour express vers opaque) et repartira de zéro.
var _fading_player: Node2D = null
## Verrou : dès que shop_entered a été émis, la porte n'écoute plus rien
## (rien ne doit démarrer pendant la fenêtre de changement de scène)
var _activated: bool = false

func _ready() -> void:
	$Area2D/CollisionShape2D.disabled = true
	# body_exited n'est pas câblé dans la scène (.tscn) : connexion ici
	# pour gérer l'annulation du fondu quand le joueur quitte la zone
	if not $Area2D.body_exited.is_connected(_on_area_2d_body_exited):
		$Area2D.body_exited.connect(_on_area_2d_body_exited)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if _activated or _fading_player != null:
		return
	if body.is_in_group("player_group"):
		_fading_player = body
		body.start_exit_fade(_on_exit_fade_done)

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body == _fading_player:
		# Le joueur peut avoir été libéré (mort) pendant son fondu
		if is_instance_valid(body):
			body.cancel_exit_fade()
		_fading_player = null

func _on_exit_fade_done() -> void:
	_fading_player = null
	_activated = true
	# Porte désactivée après validation (hygiène : aucun nouveau fondu ne
	# doit démarrer avant le free de la scène, différé d'une frame)
	$Area2D/CollisionShape2D.set_deferred("disabled", true)
	shop_entered.emit()

func _on_animation_finished() -> void:
	$Area2D/CollisionShape2D.disabled = false
