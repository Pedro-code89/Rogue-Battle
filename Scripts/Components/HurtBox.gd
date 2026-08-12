extends Area2D
class_name Hurtbox 

signal took_damage(amount: float)

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if area is Hitbox:
		took_damage.emit(area.damage)
