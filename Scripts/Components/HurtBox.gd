extends Area2D
class_name Hurtbox

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if area is Hitbox:
		print("=== HURTBOX ===")
		print("Hitbox recebido: ", area)
		print("DANO RECEBIDO: ", area.damage)
		print("STUN: ", area.stun_duration)

		if get_parent().has_method("take_damage"):
			get_parent().take_damage(int(area.damage))

		if area.stun_duration > 0.0 and get_parent().has_method("apply_stun"):
			get_parent().apply_stun(area.stun_duration)
