extends Node2D

const NUMBER_OF_FRAME_ELEVATOR : int = 76
## Délai de grâce en bas de cage : si le niveau ne s'est pas lancé dans
## ce délai après la descente (personne n'a traversé la zone de
## téléportation), l'ascenseur remonte.
const DELAI_GRACE_BAS : float = 1.5

## Détection d'écrasement pendant la remontée : rectangle juste au-dessus
## du toit (Toit : 98 px de large, sommet à y = -88 en local), large
## comme la cabine + marge. Si un joueur s'y trouve, la cabine
## cinématique est en train de le plaquer contre le plafond.
const ZONE_ECRASEMENT_TAILLE := Vector2(110, 20)
const ZONE_ECRASEMENT_OFFSET := Vector2(0, -98)
## Micro-pause « se bloque » avant la descente de secours (s)
const ARRET_BLOQUE_DUREE := 0.25

## États de l'ascenseur : EN_HAUT = préparation normale (jauge), DESCENTE
## = départ lancé, AU_BAS = délai de grâce en bas, REMONTEE = remontée
## (personne n'est parti). Pendant DESCENTE / AU_BAS / REMONTEE, la
## jauge est ignorée : les entrées/sorties continuent d'être comptées
## mais aucune décision de départ n'est prise.
enum Etat { EN_HAUT, DESCENTE, AU_BAS, REMONTEE }
var _etat: Etat = Etat.EN_HAUT

## Front montant de la jauge (règle validée) : la descente n'est ARMÉE
## que si la cible de jauge passe de non-pleine à pleine. Sans ça, tout
## le monde resté à bord pendant une remontée relancerait la descente
## instantanément à l'arrivée en haut (jauge encore pleine) — boucle
## haut/bas sans laisser le temps de sortir.
var _jauge_etait_pleine := false
var _depart_arme := false
## Remontée interrompue par un joueur écrasé : la descente à l'envers
## qui suit s'achève EN BAS (cycle complet : délai de grâce), et non en
## haut comme une remontée normale.
var _remontee_bloquee := false
## Requête physique de la zone d'écrasement (construite une fois)
var _requete_ecrasement := PhysicsShapeQueryParameters2D.new()

var number_of_players_in_the_elevator: int = 0
var animated_sprite_2D: AnimatedSprite2D

func _ready() -> void:
	animated_sprite_2D = $AnimatableBody2D/AnimatedSprite2D
	# Timer de grâce (présent dans la scène, non connecté) : branché ici.
	var timer: Timer = $AnimatableBody2D/Timer
	timer.wait_time = DELAI_GRACE_BAS
	timer.one_shot = true
	timer.timeout.connect(_on_delai_grace_timeout)
	# Fin du mouvement PHYSIQUE (descente ET remontée, cf. _etat) : c'est
	# la position du corps qui décide, pas l'anim du sprite.
	$AnimatableBody2D/AnimationPlayer.animation_finished.connect(_on_mouvement_termine)
	# Requête d'écrasement : rectangle au-dessus du toit, cherche la
	# couche des joueurs (1), la cabine exclue.
	var forme := RectangleShape2D.new()
	forme.size = ZONE_ECRASEMENT_TAILLE
	_requete_ecrasement.shape = forme
	_requete_ecrasement.collision_mask = 1
	_requete_ecrasement.exclude = [$AnimatableBody2D.get_rid()]

# 2 - Avoir le nombre de joueurs dans l'ascenseur
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_group"):
		number_of_players_in_the_elevator += 1
		
	animate_elevator_preparation()
	
	
func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("player_group"):
		number_of_players_in_the_elevator -= 1

	animate_elevator_preparation()
	

# 3 - avoir la frame à atteindre
## Division entière VOLONTAIRE : la frame cible est un entier d'animation
@warning_ignore("integer_division")
func get_frame_to_reach()-> int:
	
	# Joueurs de la partie (une manette branchée en cours de partie et
	# ignorée ne doit pas changer la vitesse de l'ascenseur)
	var number_of_players_connected: int = PlayerManager.active_player_ids().size()
	
	# Aucune manette connectée : pas de joueurs, pas de division par zéro
	if number_of_players_connected == 0:
		return 0
	
	# Division entière VOLONTAIRE : la frame cible est un entier d'animation
	@warning_ignore("integer_division")
	return number_of_players_in_the_elevator * NUMBER_OF_FRAME_ELEVATOR / number_of_players_connected


# 4 - Animer l'asceneur jusqu'à la frame_to_reach
# Ne prend des décisions qu'à l'état EN_HAUT : pendant la descente, le
# délai de grâce et la remontée, la jauge est ignorée.
func animate_elevator_preparation():
	if _etat != Etat.EN_HAUT:
		return
	var frame_to_reach = get_frame_to_reach()
	var elevator_frame : int = animated_sprite_2D.frame
	
	# Front montant : arme le départ seulement quand la cible passe de
	# non-pleine à pleine (dernier joueur monté à bord).
	var pleine: bool = frame_to_reach >= NUMBER_OF_FRAME_ELEVATOR
	if pleine and not _jauge_etait_pleine:
		_depart_arme = true
	elif not pleine:
		_depart_arme = false
	_jauge_etait_pleine = pleine
	
	if frame_to_reach > elevator_frame:
		animated_sprite_2D.play("ascenseur_energie")

	
	elif frame_to_reach < elevator_frame:
		animated_sprite_2D.play_backwards("ascenseur_energie")


func _on_animated_sprite_2d_frame_changed() -> void:
	if _etat != Etat.EN_HAUT:
		return
	var frame_to_reach = get_frame_to_reach()
	var elevator_frame : int = animated_sprite_2D.frame
	
	
	if frame_to_reach == elevator_frame:
		animated_sprite_2D.pause()
		
		if elevator_frame == NUMBER_OF_FRAME_ELEVATOR and _depart_arme:
			_depart_arme = false
			start_the_movement()
		

#5 - Lancement de la descente
func start_the_movement():
		_etat = Etat.DESCENTE
		animated_sprite_2D.play("ascenseur_descente")
		$AnimatableBody2D/AnimationPlayer.play("ascenseur_mouv_descente")
		

## Fin du mouvement physique :
## - fin de DESCENTE → plateforme en bas : délai de grâce. Si le niveau
##   s'est lancé pendant le délai, la scène (et ce timer) est détruite :
##   le timeout ne peut donc arriver que si personne n'est parti.
## - fin de REMONTEE → retour à l'état normal ; la jauge se re-remplit
##   selon les joueurs présents à bord (le front montant exige qu'elle
##   soit d'abord redescendue avant un nouveau départ).
func _on_mouvement_termine(_anim: StringName) -> void:
	match _etat:
		Etat.DESCENTE:
			_etat = Etat.AU_BAS
			$AnimatableBody2D/Timer.start()
		Etat.REMONTEE:
			if _remontee_bloquee:
				# Remontée interrompue : la descente à l'envers s'est
				# achevée EN BAS — le joueur coincé a été libéré en route.
				# Cycle complet : délai de grâce avant nouvelle tentative.
				_remontee_bloquee = false
				_etat = Etat.AU_BAS
				$AnimatableBody2D/Timer.start()
			else:
				_etat = Etat.EN_HAUT
				animate_elevator_preparation()


## Délai de grâce écoulé sans lancement du niveau : remontée = les mêmes
## animations jouées à l'envers (aucun nouvel asset).
func _on_delai_grace_timeout() -> void:
	_etat = Etat.REMONTEE
	animated_sprite_2D.play_backwards()
	$AnimatableBody2D/AnimationPlayer.play_backwards()


## Pendant la remontée uniquement : si un joueur se fait plaquer par le
## toit contre le plafond, l'ascenseur se bloque puis redescend (cf.
## _bloquer_remontee). Une remontée déjà interrompue ne re-détecte pas.
func _physics_process(_delta: float) -> void:
	if _etat != Etat.REMONTEE or _remontee_bloquee:
		return
	if _joueur_dans_zone_ecrasement():
		_bloquer_remontee()


## La zone d'écrasement (au-dessus du toit, suit la cabine) chevauche-
## t-elle un joueur ?
func _joueur_dans_zone_ecrasement() -> bool:
	_requete_ecrasement.transform = \
		$AnimatableBody2D.global_transform * Transform2D(0.0, ZONE_ECRASEMENT_OFFSET)
	var espace := get_world_2d().direct_space_state
	for hit in espace.intersect_shape(_requete_ecrasement, 8):
		var corps = hit.collider
		if corps is Node2D and corps.is_in_group("player_group"):
			return true
	return false


## Joueur écrasé : l'ascenseur SE BLOQUE (pause des deux animations) un
## instant, puis redescend à l'envers depuis la position courante — le
## toit s'éloigne du plafond et libère le joueur. La fin de cette
## descente déclenchera le cycle complet (délai de grâce), cf.
## _on_mouvement_termine.
func _bloquer_remontee() -> void:
	_remontee_bloquee = true
	animated_sprite_2D.pause()
	$AnimatableBody2D/AnimationPlayer.pause()
	get_tree().create_timer(ARRET_BLOQUE_DUREE).timeout.connect(_reprendre_descente_bloquee)


## Reprise de la descente après la micro-pause : la remontée jouait les
## anims À L'ENVERS (elle montait) — la descente de secours reprend donc
## la lecture EN AVANT (le sens descente), depuis la position courante.
## L'anim s'achèvera en bas de cage (signal réel animation_finished) →
## cycle complet, cf. _on_mouvement_termine.
## CAS LIMITE : si le blocage a eu lieu DÈS LE DÉBUT de la remontée
## (ex. joueur debout sur le toit, encore en bas), la position est déjà
## au bout de l'anim — reprendre la lecture la ferait REPARTIR DU
## DÉBUT (play() sur une anim terminée) et le corps sauterait en HAUT
## de la cage : le fameux « téléport ». Il n'y a rien à redescendre :
## on repart directement sur un cycle normal (délai de grâce).
## (Le sorcier peut aussi avoir quitté l'arbre pendant la pause.)
func _reprendre_descente_bloquee() -> void:
	if not is_inside_tree():
		return
	var anim := anim_mouvement().get_animation(&"ascenseur_mouv_descente")
	if anim_mouvement().current_animation_position >= anim.length - 0.01:
		_remontee_bloquee = false
		_etat = Etat.AU_BAS
		$AnimatableBody2D/Timer.start()
		return
	animated_sprite_2D.play()
	anim_mouvement().play()


## L'AnimationPlayer du mouvement (raccourci lisible)
func anim_mouvement() -> AnimationPlayer:
	return $AnimatableBody2D/AnimationPlayer
