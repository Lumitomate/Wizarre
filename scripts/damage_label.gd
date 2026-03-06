extends Label

var amount: int = 1

func _ready() -> void:
	$Opacity.start()
	text = "-" + str(amount)

func _process(_delta: float) -> void:
	var progress = ($Opacity.time_left / $Opacity.wait_time) ** 2
	label_settings.font_color = Color(1, 1, 1, progress)
	position.y -= 1


func _on_opacity_timeout() -> void:
	queue_free()
