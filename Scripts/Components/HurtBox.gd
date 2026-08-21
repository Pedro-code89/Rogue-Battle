extends Area2D
class_name Hurtbox

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if area is Hitbox:
		if get_parent().has_method("take_damage"):
			get_parent().take_damage(area.damage)
