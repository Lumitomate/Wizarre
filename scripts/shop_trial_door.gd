extends StaticBody2D

@export var door_type: GlobalEnum.DoorType

var can_open : bool = false

var animation_suffix
 
func _ready() -> void:
	
	match door_type:
		GlobalEnum.DoorType.TIME:
			animation_suffix="temps"
		GlobalEnum.DoorType.NO_DAMAGE:
			animation_suffix="dieu"
		GlobalEnum.DoorType.FRIENDSHIP:
			animation_suffix="amitie"
		
	$AnimatedSprite2D.animation="ouverture_" + animation_suffix
	check_door_opening_condition()
	$Timer.start()

func open_door() -> void :
	if can_open:
		$AnimatedSprite2D.play("ouverture_" + animation_suffix)

func _process(_delta: float) -> void:
	if $AnimatedSprite2D.frame == 10:
		$CollisionShape2D.disabled = true
		
func check_door_opening_condition() -> void:
	
	match door_type:
		GlobalEnum.DoorType.TIME:
			if Run.run_duration < 20000:
				can_open = true
		GlobalEnum.DoorType.FRIENDSHIP:
			can_open = not Run.any_player_dead()
		GlobalEnum.DoorType.NO_DAMAGE:
			can_open = Run.all_players_full_lives()
	


func _on_timer_timeout() -> void:
	open_door()
