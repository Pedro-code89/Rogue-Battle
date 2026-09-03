extends Sprite2D

@export var recarga_texturas: Array[Texture2D] = []
@export var target: CharacterBody2D


func _ready() -> void:
	if not recarga_texturas.is_empty():
		texture = recarga_texturas[recarga_texturas.size() - 1]


func _process(_delta: float) -> void:
	if target == null or recarga_texturas.is_empty():
		return

	# A barra agora usa a carga do ATTACK_SPECIAL
	var progress: float = target.special_charge / target.SPECIAL_CHARGE_MAX

	progress = clamp(progress, 0.0, 1.0)

	var index := int(round(progress * (recarga_texturas.size() - 1)))
	index = clamp(index, 0, recarga_texturas.size() - 1)

	texture = recarga_texturas[index]
