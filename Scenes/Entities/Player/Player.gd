extends CharacterBody2D

signal hp_changed(new_hp: float, max_hp: float)

enum PlayerState {
	IDLE,
	RUN,
	JUMP,
	TRANSITION,
	FALL,
	LAND,
	ATTACK1,
	ATTACK2,
	DASH,
	DEATH
}

@onready var AnimationCharacter: AnimatedSprite2D = $AnimatedSprite2D
@onready var AnimationControl: AnimationPlayer = $AnimationPlayer
@onready var FlashHit: AnimationPlayer = $FlashHitPlayer


const SPEED: float = 90.0
const SPEED_RUN: float = 120.0
const JUMP_VELOCITY: float = -270.0

const DEATH_FADE_DURATION: float = 1.0

const DASH_SPEED: float = 400.0
const DASH_DURATION: float = 0.2
const DASH_COOLDOWN: float = 1.0

var status: PlayerState
var buffered_attack := false
var jump_count: int = 0
var max_jump_count: int = 2
var hp: int = 100
var max_hp: int = 100

var is_dashing: bool = false
var can_dash: bool = true
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: float = 1.0
var dash_trail_timer: float = 0.0
var camera2D : Camera2D
var cameraShakeNoise: FastNoiseLite

const DASH_TRAIL_INTERVAL: float = 0.03
const DASH_TRAIL_FADE_TIME: float = 0.3

func _ready() -> void:
	go_to_idle_state()
	hp_changed.emit(hp, max_hp)
	camera2D = get_node("Camera2D")
	cameraShakeNoise = FastNoiseLite.new()

func _physics_process(delta: float) -> void:

	if Input.is_action_just_pressed("ui_cancel"):
		take_damage(10)

	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
		if dash_cooldown_timer <= 0:
			can_dash = true

	if not is_on_floor() and not is_dashing:
		velocity += get_gravity() * delta

	match status:
		PlayerState.IDLE:
			idle_state()
		PlayerState.RUN:
			run_state()
		PlayerState.JUMP:
			jump_state()
		PlayerState.TRANSITION:
			transition_state()
		PlayerState.FALL:
			fall_state()
		PlayerState.LAND:
			land_state()
		PlayerState.ATTACK1:
			attack1_state()
		PlayerState.ATTACK2:
			attack2_state()
		PlayerState.DEATH:
			death_state()
		PlayerState.DASH:
			dash_state(delta)

	move_and_slide()

# RODA QUANDO TROCA

func go_to_idle_state():
	status = PlayerState.IDLE
	AnimationCharacter.play("Idle")

func go_to_run_state():
	status = PlayerState.RUN
	if AnimationCharacter.animation != "Run":
		AnimationCharacter.play("Run")

func go_to_jump_state():
	status = PlayerState.JUMP
	AnimationCharacter.play("Jump")
	AnimationControl.play("jump")
	velocity.y = JUMP_VELOCITY
	jump_count += 1

func go_to_transition_state():
	status = PlayerState.TRANSITION
	AnimationCharacter.play("Transition")

func go_to_fall_state():
	status = PlayerState.FALL
	AnimationCharacter.play("Fall")
	AnimationControl.play("fall")

func go_to_land_state():
	status = PlayerState.LAND
	AnimationCharacter.play("Land")
	velocity.x = 0

func go_to_attack1_state():
	status = PlayerState.ATTACK1
	face_mouse()
	AnimationControl.play("attack_1")
	AnimationCharacter.play("Attack_1")
	$AttackPivot/HitBox.damage = 10.0
	velocity.x = 0

func go_to_attack2_state():
	status = PlayerState.ATTACK2
	face_mouse()
	AnimationCharacter.play("Attack_2")
	AnimationControl.play("attack_2")
	$AttackPivot/HitBox.damage = 20.0
	velocity.x = 0

func go_to_death_state():
	status = PlayerState.DEATH
	velocity.x = 0
	AnimationCharacter.play("Death")
	play_death_fade()

func go_to_dash_state():
	status = PlayerState.DASH
	is_dashing = true
	can_dash = false
	buffered_attack = false
	dash_timer = DASH_DURATION
	dash_trail_timer = 0.0

	var input_dir := Input.get_axis("move_left", "move_right")
	if input_dir != 0:
		dash_direction = input_dir
	else:
		dash_direction = -1.0 if AnimationCharacter.flip_h else 1.0

	# Vira o personagem e o AttackPivot pra direção do dash,
	# assim ele fica de frente pro lado que tá indo, mesmo saindo do attack/idle
	if dash_direction < 0:
		AnimationCharacter.flip_h = true
		$AttackPivot.position.x = -20
	else:
		AnimationCharacter.flip_h = false
		$AttackPivot.position.x = 20

	velocity.x = dash_direction * DASH_SPEED
	velocity.y = 0
	AnimationCharacter.play("Run")

# FUNÇÕES QUE RODAM CONSTANTEMENTE

func idle_state():
	move()

	if not is_on_floor():
		go_to_fall_state()
		return

	if Input.is_action_just_pressed("dash") and can_dash:
		go_to_dash_state()
		return

	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0:
		go_to_run_state()
		return

	if Input.is_action_just_pressed("jump"):
		go_to_jump_state()
		return

	if Input.is_action_just_pressed("mouse_left"):
		go_to_attack1_state()
		return

func run_state():

	move()

	if not is_on_floor():
		go_to_fall_state()
		return

	if Input.is_action_just_pressed("dash") and can_dash:
		go_to_dash_state()
		return

	var direction := Input.get_axis("move_left", "move_right")
	if direction == 0 and velocity.x == 0:
		go_to_idle_state()
		return

	if Input.is_action_just_pressed("jump"):
		go_to_jump_state()
		return

	if Input.is_action_just_pressed("mouse_left"):
		go_to_attack1_state()
		return

func jump_state():
	move()

	if Input.is_action_just_pressed("dash") and can_dash:
		go_to_dash_state()
		return

	if Input.is_action_just_pressed("jump") and jump_count < max_jump_count:
		go_to_jump_state()
		return

	if velocity.y > 0:
		go_to_transition_state()
		return

func transition_state():
	move()

	if Input.is_action_just_pressed("dash") and can_dash:
		go_to_dash_state()
		return

	if AnimationCharacter.frame == AnimationCharacter.sprite_frames.get_frame_count("Transition") - 1:
		go_to_fall_state()
		return

func fall_state():
	move()

	if Input.is_action_just_pressed("dash") and can_dash:
		go_to_dash_state()
		return

	if is_on_floor():
		jump_count = 0
		go_to_land_state()
		return

func land_state():
	pass

func attack1_state():
	face_mouse()
	velocity.x = 0

	if Input.is_action_just_pressed("dash") and can_dash:
		go_to_dash_state()
		return

	if Input.is_action_just_pressed("mouse_left"):
		buffered_attack = true

	var total_frames = AnimationCharacter.sprite_frames.get_frame_count("Attack_1")
	var current_frames = AnimationCharacter.frame

	if buffered_attack and current_frames >= total_frames * 0.8:
		buffered_attack = false
		go_to_attack2_state()
		return

func attack2_state():
	face_mouse()
	velocity.x = 0

	if Input.is_action_just_pressed("dash") and can_dash:
		go_to_dash_state()
		return

	if Input.is_action_just_pressed("mouse_left"):
		buffered_attack = true

	var total_frames = AnimationCharacter.sprite_frames.get_frame_count("Attack_2")
	var current_frames = AnimationCharacter.frame

	if buffered_attack and current_frames >= total_frames * 0.7:
		buffered_attack = false
		go_to_attack1_state()
		return

func death_state():
	velocity.x = 0

func dash_state(delta: float):
	velocity.x = dash_direction * DASH_SPEED
	velocity.y = 0

	dash_trail_timer -= delta
	if dash_trail_timer <= 0:
		dash_trail_timer = DASH_TRAIL_INTERVAL
		spawn_dash_trail()

	dash_timer -= delta
	if dash_timer <= 0:
		is_dashing = false
		dash_cooldown_timer = DASH_COOLDOWN

		if is_on_floor():
			go_to_idle_state()
		else:
			go_to_fall_state()
		return

func spawn_dash_trail() -> void:
	var trail := Sprite2D.new()
	trail.texture = AnimationCharacter.sprite_frames.get_frame_texture(AnimationCharacter.animation, AnimationCharacter.frame)
	trail.global_position = AnimationCharacter.global_position
	trail.flip_h = AnimationCharacter.flip_h
	trail.scale = AnimationCharacter.scale
	trail.z_index = AnimationCharacter.z_index - 1
	trail.modulate = Color(1.0, 1.0, 1.0, 0.5)

	get_parent().add_child(trail)

	var tween := trail.create_tween()
	tween.tween_property(trail, "modulate:a", 0.0, DASH_TRAIL_FADE_TIME)
	tween.tween_callback(trail.queue_free)

# FUNÇÃO DE MOVIMENTO/ FUNÇÃO BÁSICA

func move():
	var direction := Input.get_axis("move_left", "move_right")

	var current_speed = SPEED
	if Input.is_action_pressed("run"):
		current_speed = SPEED_RUN

	if direction:
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	if direction < 0:
		AnimationCharacter.flip_h = true
		$AttackPivot.position.x = -20
	elif direction > 0:
		AnimationCharacter.flip_h = false
		$AttackPivot.position.x = 20

func face_mouse() -> void:
	var mouse_pos := get_global_mouse_position()
	if mouse_pos.x < global_position.x:
		AnimationCharacter.flip_h = true
		$AttackPivot.position.x = -20
	else:
		AnimationCharacter.flip_h = false
		$AttackPivot.position.x = 20

func take_damage(amount: int) -> void:
	if status == PlayerState.DEATH:
		return

	if is_dashing:
		return 

	hp = clampi(hp - amount, 0, max_hp)

	hp_changed.emit(hp, max_hp)

	if hp <= 0:
		die()

	flash_hit()

	var camera_tween = get_tree().create_tween()
	camera_tween.tween_method(StartCameraShake, 5.0, 1.0, 0.4)

func die() -> void:
	go_to_death_state()

func play_death_fade() -> void:
	var tween = create_tween()
	tween.tween_interval(0.4)  # deixa a animação de morte rodar um pouco antes de sumir
	tween.tween_property(AnimationCharacter, "modulate:a", 0.0, DEATH_FADE_DURATION)
	tween.tween_callback(queue_free)

func _on_animated_sprite_2d_animation_finished() -> void:
	match AnimationCharacter.animation:
		"Attack_1":
			if buffered_attack:
				buffered_attack = false
				go_to_attack2_state()
			else:
				go_to_idle_state()
		"Attack_2":
			if buffered_attack:
				buffered_attack = false
				go_to_attack1_state()
			else:
				go_to_idle_state()
		"Land":
			go_to_idle_state()
		"Transition":
			go_to_fall_state()

func flash_hit():
	FlashHit.play("flash_hit")

func StartCameraShake(intensity: float):
	var cameraOffset = cameraShakeNoise.get_noise_1d(Time.get_ticks_msec()) * intensity
	camera2D.offset.x = cameraOffset
	camera2D.offset.y = cameraOffset
