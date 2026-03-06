extends StaticBody2D

@export var door_type: Enum.DoorType

var can_open : bool = false

var animation_suffix
 
func _ready() -> void:
	
	match door_type:
		Enum.DoorType.TIME:
			animation_suffix="temps"
		Enum.DoorType.NO_DAMAGE:
			animation_suffix="dieu"
		Enum.DoorType.FRIENDSHIP:
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
	
	var run_info = GlobalInfo.run_info
	
	match door_type:
		Enum.DoorType.TIME:
			if run_info["run_duration"] < 20000:
				can_open = true
		Enum.DoorType.FRIENDSHIP:
			can_open = true
			for k in GlobalInfo.run_info["players_info"].keys():
				if str(k) != "default" and GlobalInfo.run_info["players_info"][k]["lives"] == 0:
					can_open = false
		Enum.DoorType.NO_DAMAGE:
			for k in GlobalInfo.run_info["players_info"].keys():
				if str(k) != "default" and GlobalInfo.run_info["players_info"][k]["lives"] != 3:
					can_open = false
			can_open = true
	


func _on_timer_timeout() -> void:
	open_door()
