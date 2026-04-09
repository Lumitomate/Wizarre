extends Node2D

const NUMBER_OF_FRAME_ELEVATOR : int = 76
var number_of_players_in_the_elevator: int = 0
var animated_sprite_2D: AnimatedSprite2D

#BUG : QUAND UN JOUEUR SORT DE L'ASCENSEUR CHARGÉ À 100%, IL REVIENT À 0% MALGRÉ QU'UN JOUEUR SOIT DEDANS.

func _ready() -> void:
	animated_sprite_2D = $AnimatableBody2D/AnimatedSprite2D

func _process(_delta: float) -> void:
	pass


# 2 - Avoir le nombre de joueurs dans l'ascenseur
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_group"):
		number_of_players_in_the_elevator += 1
		
	animate_elevator_preparation()
	print("1 - Joueur ENTREE dans l'ascenseur")
	print("Il y a " + str (number_of_players_in_the_elevator) + " l'ascenseur")

	
func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("player_group"):
		number_of_players_in_the_elevator -= 1

	animate_elevator_preparation()
	print("1 - Joueur SORTIE de l'ascenseur")
	print("Il y a " + str (number_of_players_in_the_elevator) + " l'ascenseur")


# 3 - avoir la frame à atteindre
func get_frame_to_reach()-> int:
	
	var number_of_players_connected: int  = PlayerManager.known_controllers.size()
	
	return number_of_players_in_the_elevator * NUMBER_OF_FRAME_ELEVATOR / number_of_players_connected
	
	#print("1 - Il y a " + str(number_of_players_connected) + " joueurs connectés" )
	#print("1 - Il y a " + str(number_of_players_in_the_elevator) + " joueurs dans l'ascenseur" )


# 4 - Animer l'asceneur jusqu'à la frame_to_reach 
#JE VEUX QU'IL COMMENCE L'ANNIMATION DEPUIS LA FRAME ACTUELLE ET PAS QU'IL RECOMMENCE DE 0 MAIS JE SAIS PAS COMMENT FAIRE
func animate_elevator_preparation():
	var frame_to_reach = get_frame_to_reach()
	var elevator_frame : int = animated_sprite_2D.frame
	
	if frame_to_reach > elevator_frame:
		animated_sprite_2D.play("ascenseur_energie")
		print("2 - Frame to reach à atteindre")

	
	elif frame_to_reach < elevator_frame:
		animated_sprite_2D.play_backwards("ascenseur_energie")
		print("2 - Frame to reach dépassée")


	print("_La frame actuelle est " + str(elevator_frame) + " et la frame to reach est " + str(frame_to_reach))


func _on_animated_sprite_2d_frame_changed() -> void:
	var frame_to_reach = get_frame_to_reach()
	var elevator_frame : int = animated_sprite_2D.frame
	
	
	if frame_to_reach == elevator_frame:
		animated_sprite_2D.pause()
		print("2 - Frame to reach atteinte")
		
		if elevator_frame == NUMBER_OF_FRAME_ELEVATOR:
			start_the_movement()
		

#5 - Lancement de la descente
func start_the_movement():
		animated_sprite_2D.play("ascenseur_descente")
		$AnimatableBody2D/AnimationPlayer.play("ascenseur_mouv_descente")
		
