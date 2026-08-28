extends CharacterBody2D
## Inimigo que persegue o jogador ao detectá-lo, por um tempo limitado.
 
@export var hp := 250
@export var max_hp := 250
 
@export var speed := 80.0
@export var stop_distance := 25.0
@export var attack_distance := 45.0
@export var chase_duration := 10.0
 
@onready var player: Node2D = get_tree().get_first_node_in_group("player")
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var chase_timer: Timer = $ChaseTimer
@onready var hit_particles: GPUParticles2D = $Hit_particles
@onready var shock_player_tree: AnimationPlayer = $ShockPlayerTree
 
var is_chasing := false
var is_attacking := false
var gravity := ProjectSettings.get_setting("physics/2d/default_gravity") as float
var is_dead := false
 
const DAMAGE_LABEL = preload("uid://by3nwql4oot7k")
 
 
func _ready() -> void:
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	chase_timer.timeout.connect(_on_chase_timer_timeout)
 
	chase_timer.wait_time = chase_duration
	chase_timer.one_shot = true
 
	animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
 
 
func _physics_process(delta: float) -> void:
	if is_dead:
		return
 
	_apply_gravity(delta)
 
	if player == null or not is_chasing:
		velocity.x = 0.0
		move_and_slide()
 
		if not is_attacking:
			_update_animation()
 
		return
 
	var distance := absf(global_position.x - player.global_position.x)
 
	# =========================
	# ATAQUE
	# =========================
	if distance <= attack_distance:
		velocity.x = 0.0
 
	_face_player()

	if not is_attacking:
		is_attacking = true
		animated_sprite.play("Attack_Shock")
		shock_player_tree.play("attack_shock")

	move_and_slide()
	return

# Só começa o ataque se não estiver atacando
	if not is_attacking:
		is_attacking = true
		animated_sprite.play("Attack_Shock")
		shock_player_tree.play("attack_shock")
 
	move_and_slide()
	return
 
	# =========================
	# PERSEGUIÇÃO
	# =========================
	if not is_attacking:
		velocity.x = _get_chase_velocity_x()
		move_and_slide()
		_update_animation()
	else:
		velocity.x = 0.0
		move_and_slide()
 
 
func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y += gravity * delta
 
 
func _get_chase_velocity_x() -> float:
	var distance := absf(global_position.x - player.global_position.x)
 
	if distance <= stop_distance:
		return 0.0
 
	return signf(player.global_position.x - global_position.x) * speed
 
 
func _update_animation() -> void:
	if absf(velocity.x) > 0.1:
		animated_sprite.play("Move_Shock")
		animated_sprite.flip_h = velocity.x < 0
	else:
		animated_sprite.play("Idle_Shock")
 
 
func _on_animated_sprite_animation_finished() -> void:
	if animated_sprite.animation == "Attack_Shock":
		is_attacking = false
 
		# Atualiza imediatamente para Idle ou Move
		_update_animation()
 
 
func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_chasing = true
		chase_timer.start()
 
 
func _on_chase_timer_timeout() -> void:
	is_chasing = false
	is_attacking = false
 
 
func take_damage(amount: int) -> void:
	print("DANO RECEBIDO:", amount)
	print("HP ANTES:", hp)
 
	hp -= amount
	hp = clampi(hp, 0, max_hp)
 
	print("HP AGORA:", hp)
 
	if hp <= 0:
		die()
		return
 
	var new_damage_label = DAMAGE_LABEL.instantiate() as Label
	new_damage_label.text = str(amount)
	new_damage_label.global_position = global_position + Vector2(-25, -70)
 
	get_tree().current_scene.call_deferred(
		"add_child",
		new_damage_label
	)
 
	hit_particles.restart()
	hit_particles.emitting = true
 
func _face_player() -> void:
	if player == null:
		return

	animated_sprite.flip_h = player.global_position.x < global_position.x

func die() -> void:
	is_dead = true
	is_attacking = false
	velocity = Vector2.ZERO
 
	animated_sprite.play("Death_Shock")
	shock_player_tree.play("death_shock")
 
