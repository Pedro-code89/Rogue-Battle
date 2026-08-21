extends Label

func _ready() -> void:
	var damageLabelTween = get_tree().create_tween()
	damageLabelTween.set_parallel(true)
	damageLabelTween.tween_property(self, "scale", Vector2(0.7, 0.7), 0.2)
	damageLabelTween.tween_property(self, "scale", Vector2.ZERO, 0.5).set_delay(0.4)
	damageLabelTween.tween_property(self, "position:y", global_position.y - 80, 2.0).set_delay(0.4)
	await damageLabelTween.finished
	queue_free()
