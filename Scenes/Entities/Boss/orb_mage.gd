extends CharacterBody2D

enum State { IDLE, CHASE, ATTACK1, ATTACK2 }
var current_state: State = State.IDLE

@export var speed: float = 80.0
@export var attack1_range: float = 40.0  # distancia MAXIMA pro ataque de perto (attack1)
@export var attack2_range: float = 90.0  # distancia MAXIMA pro ataque de longe (attack2), tem que ser > attack1_range

@export var attack1_damage: float = 15.0
@export var attack2_damage: float = 20.0

var player: Node2D = null
var facing_direction: int = 1  # 1 = direita, -1 = esquerda

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var anim_player: AnimationPlayer = $BossTree  # ajusta pro nome real
@onready var detection_area: Area2D = $DetectionArea    # ajusta se tiver outro nome


func _ready() -> void:
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	animated_sprite.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			_process_idle()
		State.CHASE:
			_process_chase()
		State.ATTACK1, State.ATTACK2:
			_process_attack()

	move_and_slide()


func _process_idle() -> void:
	velocity = Vector2.ZERO
	animated_sprite.play("Idle_OrbMage")
	# fica parado ate a DetectionArea disparar o body_entered


func _process_chase() -> void:
	if player == null or not is_instance_valid(player):
		player = null
		_change_state(State.IDLE)
		return

	var distance_to_player: float = global_position.distance_to(player.global_position)
	_update_facing()

	if distance_to_player <= attack1_range:
		_change_state(State.ATTACK1)
		return

	if distance_to_player <= attack2_range:
		_change_state(State.ATTACK2)
		return

	# ainda longe, continua perseguindo infinitamente
	var direction: Vector2 = (player.global_position - global_position).normalized()
	velocity = direction * speed
	animated_sprite.play("Move_OrbMage")


func _process_attack() -> void:
	velocity = Vector2.ZERO
	# a animação (AnimatedSprite2D + AnimationPlayer) cuida do resto,
	# incluindo ligar/desligar o CollisionShape2D do Hitbox


func _update_facing() -> void:
	if player == null:
		return
	facing_direction = 1 if player.global_position.x > global_position.x else -1
	animated_sprite.flip_h = facing_direction < 0
	$HitBox1/CollisionShape2D.position.x = 7 if facing_direction > 0 else -7  # ajusta esses valores pro tamanho do teu boss/hitbox


func _change_state(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.ATTACK1:
			$HitBox1/CollisionShape2D.damage = attack1_damage
			animated_sprite.play("Attack_1_OrgbMage")
			anim_player.play("attack1_OrbMage")
		State.ATTACK2:
			$HitBox2/CollisionShape2D.damage = attack2_damage
			animated_sprite.play("Attack_2_OrbMage")
			anim_player.play("attack2_OrbMage")
		State.CHASE, State.IDLE:
			pass


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and player == null:
		player = body
		_change_state(State.CHASE)


func _on_animation_finished() -> void:
	if animated_sprite.animation == "Attack_1_OrgbMage" or animated_sprite.animation == "Attack_2_OrbMage":
		_change_state(State.CHASE)
