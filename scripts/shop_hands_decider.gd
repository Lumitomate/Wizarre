class_name ShophandsDecider
extends Area2D

## Décideur du magasin Shophands : trois plaques de pression actionnées par
## le sorcier décideur, chacune commandant la main qui pointe dans une
## direction (droite, gauche, bas).
##
## Fonctionnement (règles validées avec le propriétaire) :
##  - au REPOS, les mains sont FERMÉES (dernière frame), pointant vers leur
##    espace ;
##  - le sorcier marche sur une plaque → la main S'OUVRE progressivement
##    (animation jouée À L'ENVERS, de la dernière frame vers la frame 0) ;
##  - il quitte la plaque → la main se REFERME vers sa pose de repos
##    (animation rejouée en avant depuis la frame courante) ; revenir sur
##    la plaque relance l'ouverture depuis la frame courante (hésitation
##    fluide avant/arrière) ;
##  - quand la main atteint la frame 0 — entièrement ouverte, « tendue » —
##    la décision est gravée : le signal direction_choisie est émis UNE
##    seule fois, toutes les mains deviennent inertes et la main gagnante
##    reste tendue (ouverte).
##
## La direction émise est NORMALISÉE dans le repère de la scène ((1,0)
## droite, (-1,0) gauche, (0,1) bas) : la scène shop_hands la convertit en
## glissement de l'objet central (cf. shop_hands.gd).

signal direction_choisie(direction: Vector2)

## Direction (repère de la scène) de chaque main, rempli dans _ready.
var _direction_par_main := {}
## Vrai si l'animation de la main joue actuellement À L'ENVERS (la main
## s'ouvre) — permet de savoir dans quel sens elle vient de finir.
var _ouvre_par_main := {}
## Vrai dès qu'une main s'est entièrement ouverte : décision gravée, les
## plaques ne répondent plus.
var _verrouille := false


func _ready() -> void:
	# Associations validées (cf. shop_hands_decider.tscn) : la plaque de
	# droite actionne la main de droite, la centrale la main du bas, celle
	# de gauche la main de gauche.
	_relier($MainD, Vector2.RIGHT, $PressurePlate3)
	_relier($MainG, Vector2.LEFT, $PressurePlate)
	_relier($MainB, Vector2.DOWN, $PressurePlate2)


## Rattache une main à sa plaque et la met en pose de REPOS (fermée,
## dernière frame — frame 0 = main ouverte, c'est la pose finale).
func _relier(main: AnimatedSprite2D, direction: Vector2, plaque: PressurePlate) -> void:
	_direction_par_main[main] = direction
	_ouvre_par_main[main] = false
	main.stop()
	main.frame = _derniere_frame(main)
	if not main.animation_finished.is_connected(_on_anim_main_finie):
		main.animation_finished.connect(_on_anim_main_finie.bind(main))
	if not plaque.activated.is_connected(_on_plaque_activee):
		plaque.activated.connect(_on_plaque_activee.bind(main))
	if not plaque.deactivated.is_connected(_on_plaque_desactivee):
		plaque.deactivated.connect(_on_plaque_desactivee.bind(main))


## Variante 3 joueurs : la main du bas et sa plaque de pression sont
## retirées du jeu (2 receveurs seulement, espaces gauche et droite).
## La plaque contient un StaticBody2D : la masquer ne suffit pas, il faut
## désactiver ses collisions pour que le décideur ne s'y tienne pas.
func retirer_main_du_bas() -> void:
	var main_b: AnimatedSprite2D = $MainB
	_direction_par_main.erase(main_b)
	_ouvre_par_main.erase(main_b)
	main_b.visible = false
	var plaque: PressurePlate = $PressurePlate2
	plaque.visible = false
	plaque.get_node("StaticBody2D/CollisionShape2D").set_deferred("disabled", true)
	plaque.get_node("TriggerArea/TriggerCollision").set_deferred("disabled", true)


func _on_plaque_activee(main: AnimatedSprite2D) -> void:
	if _verrouille:
		return
	if main.frame == 0 and _ouvre_par_main.get(main, false):
		# Déjà entièrement ouverte : la gravure arrive à la fin de l'anim,
		# rien à relancer
		return
	# Ouverture à l'envers : play_backwards depuis la frame courante,
	# l'animation reprend là où elle en est (aller/retour fluide si le
	# sorcier hésite)
	_ouvre_par_main[main] = true
	main.play_backwards(main.animation)


func _on_plaque_desactivee(main: AnimatedSprite2D) -> void:
	if _verrouille:
		return
	if main.frame == 0:
		# Main entièrement ouverte : la décision est gravée même si le
		# pied se lève pendant la dernière frame d'animation
		_graver(main)
		return
	if main.frame >= _derniere_frame(main):
		# Déjà sur la pose de repos : rien à refermer, MAIS il faut stopper
		# une ouverture qui venait de démarrer — cas du frôlage : la sortie
		# est signalée avant que l'anim n'ait avancé d'une seule frame, et
		# sans ça la main continuait de s'ouvrir toute seule (jusqu'à
		# graver la décision !). pause() garde la frame courante (stop()
		# remettrait la main ouverte).
		_ouvre_par_main[main] = false
		main.pause()
		return
	# Refermeture en avant depuis la frame courante, jusqu'au repos
	_ouvre_par_main[main] = false
	main.play(main.animation)


func _on_anim_main_finie(main: AnimatedSprite2D) -> void:
	if _verrouille or not _direction_par_main.has(main):
		return
	if main.frame == 0:
		# Fin de l'anim jouée À L'ENVERS : la main est entièrement ouverte
		# (tendue) pendant que le décideur tient la plaque → décision
		# gravée, définitivement
		_graver(main)
	# Fin jouée en avant (dernière frame) : la main s'est refermée sur sa
	# pose de repos, rien à graver


## Grave la décision : la main gagnante reste tendue (ouverte, frame 0,
## elle vient de finir naturellement), les autres mains se figent où elles
## en sont, plus aucun déclenchement n'est possible.
func _graver(main: AnimatedSprite2D) -> void:
	_verrouille = true
	for main_autre in _direction_par_main:
		if main_autre != main:
			main_autre.pause()
	direction_choisie.emit(_direction_par_main[main])


func _derniere_frame(main: AnimatedSprite2D) -> int:
	return main.sprite_frames.get_frame_count(main.animation) - 1