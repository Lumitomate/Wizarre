extends StaticBody2D

@export var door_type: Enum.DoorType

var can_open : bool = false

func _ready() -> void:
	$Timer.start()

func open_door() -> void :
	if can_open:
		$AnimatedSprite2D.play("Ouverture")

func _process(_delta: float) -> void:
	if $AnimatedSprite2D.frame == 10:
		$CollisionShape2D.disabled = true
		
func check_door_opening_condition(run_info: Dictionary) -> void:
	
	match door_type:
		Enum.DoorType.TIME:
			can_open = true
		Enum.DoorType.FRIENDSHIP:
			can_open = true
		Enum.DoorType.NO_DAMAGE:
			can_open = true
	


func _on_timer_timeout() -> void:
	open_door()
