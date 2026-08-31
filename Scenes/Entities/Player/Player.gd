extends CharacterBody2D

signal hp_changed(new_hp: float, max_hp: float)

enum PlayerState {
	IDLE,
	RUN,
	JUMP,
	FALL,
	LAND,
	ATTACK1,
	ATTACK2,
	ATTACK3,
	DASH,
	DEATH
}

@onready var AnimationCharacter: AnimatedSprite2D = $AnimatedSprite2D
@onready var AnimationControl: AnimationPlayer = $AnimationPlayer
@onready var FlashHit: AnimationPlayer = $FlashHitPlayer
@onready var hit_particles: GPUParticles2D = $Hit_particles

const SPEED: float = 100.0
const SPEED_RUN: float = 130.0
const JUMP_VELOCITY: float = -250.0

const DEATH_FADE_DURATION: float = 2.0

const DASH_SPEED: float = 300.0
const DASH_DURATION: float = 0.3
const DASH_COOLDOWN: float = 0.8

# Cooldown do golpe especial (Attack3)
const ATTACK3_COOLDOWN: float = 3.0

# Deslizada do golpe especial (Attack3)
const ATTACK3_SLIDE_SPEED: float = 200.0
const ATTACK3_SLIDE_FRICTION: float = 900.0

# Tempo sem poder dashar depois de usar o Attack3 (pra não ficar roubado)
const ATTACK3_DASH_LOCK: float = 2.0

# Trava bem curta do dash durante o hit-stun
const HIT_STUN_DASH_LOCK: float = 0.2

const DAMAGE_LABEL = preload("uid://by3nwql4oot7k")

@export var hit_slow_multiplier := 0.20  # quase travado enquanto atordoado
@export var hit_slow_duration := 0.4    # por quanto tempo fica lento

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
var camera2D: Camera2D
var cameraShakeNoise: FastNoiseLite

var hit_slow_timer: float = 0.0

# Controle de cooldown do Attack3
var can_attack3: bool = true
var attack3_cooldown_timer: float = 1.0



func _ready() -> void:
	go_to_idle_state()
	hp_changed.emit(hp, max_hp)
	camera2D = get_node("Camera2D")
	cameraShakeNoise = FastNoiseLite.new()


func _physics_process(delta: float) -> void:

	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
		if dash_cooldown_timer <= 0:
			can_dash = true

	if attack3_cooldown_timer > 0:
		attack3_cooldown_timer -= delta
		if attack3_cooldown_timer <= 0:
			can_attack3 = true

	if hit_slow_timer > 0:
		hit_slow_timer -= delta

	if not is_on_floor() and not is_dashing:
		velocity += get_gravity() * delta

	match status:
		PlayerState.IDLE:
			idle_state()

		PlayerState.RUN:
			run_state()

		PlayerState.JUMP:
			jump_state()

		PlayerState.FALL:
			fall_state()

		PlayerState.LAND:
			land_state()

		PlayerState.ATTACK1:
			attack1_state()

		PlayerState.ATTACK2:
			attack2_state()

		PlayerState.ATTACK3:
			attack3_state(delta)

		PlayerState.DEATH:
			death_state()

		PlayerState.DASH:
			dash_state(delta)

	move_and_slide()


# RODA QUANDO TROCA

func go_to_idle_state():
	status = PlayerState.IDLE
	AnimationCharacter.play("Idle")
	AnimationControl.play("idle_assasin")


func go_to_run_state():
	status = PlayerState.RUN

	if AnimationCharacter.animation != "Run":
		AnimationCharacter.play("Run")
		AnimationControl.play("run_assasin")


func go_to_jump_state():
	status = PlayerState.JUMP
	AnimationCharacter.play("Jump")
	velocity.y = JUMP_VELOCITY
	jump_count += 1


func go_to_fall_state():
	status = PlayerState.FALL
	AnimationCharacter.play("Fall")


func go_to_land_state():
	status = PlayerState.LAND
	AnimationCharacter.play("Land")
	velocity.x = 0


func go_to_attack1_state():
	status = PlayerState.ATTACK1
	face_mouse()
	AnimationControl.play("attack1_assasin")
	AnimationCharacter.play("Attack_1")
	$AttackPivot/HitBox.damage = get_attack_damage()
	velocity.x = 0


func go_to_attack2_state():
	status = PlayerState.ATTACK2
	face_mouse()
	AnimationCharacter.play("Attack_2")
	AnimationControl.play("attack2_assasin")
	$AttackPivot/HitBox.damage = get_attack_damage()
	velocity.x = 0

func go_to_attack3_state():
	status = PlayerState.ATTACK3
	AnimationCharacter.play("Attack_Slash")
	AnimationControl.play("attack3_slash_assasin")
	$AttackPivot2/HitBox2.damage = 15.0

	# Impulso da deslizada, na direção que o personagem já está olhando
	var slide_direction := -1.0 if AnimationCharacter.flip_h else 1.0
	velocity.x = slide_direction * ATTACK3_SLIDE_SPEED

	# Ativa o cooldown assim que o golpe especial começa
	can_attack3 = false
	attack3_cooldown_timer = ATTACK3_COOLDOWN

	# Trava o dash por um tempo, pra não poder cancelar/emendar o golpe especial nele
	can_dash = false
	dash_cooldown_timer = max(dash_cooldown_timer, ATTACK3_DASH_LOCK)

func go_to_death_state():
	status = PlayerState.DEATH
	velocity.x = 0
	AnimationCharacter.play("Death")
	AnimationControl.play("death_assasin")
	play_death_fade()


func go_to_dash_state():
	status = PlayerState.DASH
	is_dashing = true
	can_dash = false
	buffered_attack = false
	dash_timer = DASH_DURATION

	var input_dir := Input.get_axis("move_left", "move_right")

	if input_dir != 0:
		dash_direction = input_dir
	else:
		dash_direction = -1.0 if AnimationCharacter.flip_h else 1.0

	# Vira o personagem e o AttackPivot pra direção do dash
	if dash_direction < 0:
		AnimationCharacter.flip_h = true
		$AttackPivot.position.x = -12
	else:
		AnimationCharacter.flip_h = false
		$AttackPivot.position.x = 12

	velocity.x = dash_direction * DASH_SPEED
	velocity.y = 0
	AnimationCharacter.play("Dash")
	AnimationControl.play("dash_assasin")


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

	if Input.is_action_just_pressed("mouse_right") and can_attack3:
		go_to_attack3_state()
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

	if Input.is_action_just_pressed("mouse_right") and can_attack3:
		go_to_attack3_state()
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

	# Quando começa a descer, vai direto para FALL
	if velocity.y > 0:
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

func attack3_state(delta: float):
	velocity.x = move_toward(velocity.x, 0, ATTACK3_SLIDE_FRICTION * delta)

	if Input.is_action_just_pressed("dash") and can_dash:
		go_to_dash_state()
		return

	if Input.is_action_just_pressed("mouse_left"):
		buffered_attack = true

	var total_frames = AnimationCharacter.sprite_frames.get_frame_count("Attack_Slash")
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

	dash_timer -= delta

	if dash_timer <= 0:
		is_dashing = false
		dash_cooldown_timer = DASH_COOLDOWN

		if is_on_floor():
			go_to_idle_state()
		else:
			go_to_fall_state()

		return

func get_attack_damage() -> int:
	return randi_range(5, 8)

# FUNÇÃO DE MOVIMENTO / FUNÇÃO BÁSICA

func move():
	var direction := Input.get_axis("move_left", "move_right")

	var current_speed = SPEED

	if Input.is_action_pressed("run"):
		current_speed = SPEED_RUN

	if hit_slow_timer > 0:
		current_speed *= hit_slow_multiplier

	if direction:
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	if direction < 0:
		AnimationCharacter.flip_h = true
		$AttackPivot.position.x = -10
	elif direction > 0:
		AnimationCharacter.flip_h = false
		$AttackPivot.position.x = 10

func face_mouse() -> void:
	var mouse_pos := get_global_mouse_position()

	if mouse_pos.x < global_position.x:
		AnimationCharacter.flip_h = true
		$AttackPivot.position.x = -10
	else:
		AnimationCharacter.flip_h = false
		$AttackPivot.position.x = 10

func take_damage(amount: int) -> void:
	if status == PlayerState.DEATH:
		return

	if is_dashing:
		return

	# Invencível durante o golpe especial (Attack3)
	if status == PlayerState.ATTACK3:
		return

	hp = clampi(hp - amount, 0, max_hp)

	hp_changed.emit(hp, max_hp)

	if hp <= 0:
		die()

	hit_slow_timer = hit_slow_duration
	velocity.x = 0  # corta o impulso atual pra sentir o travamento na hora do hit

	hit_slow_timer = hit_slow_duration
	velocity.x = 0  # corta o impulso atual pra sentir o travamento na hora do hit

	can_dash = false
	dash_cooldown_timer = max(dash_cooldown_timer, HIT_STUN_DASH_LOCK)

	flash_hit()

	var camera_tween = get_tree().create_tween()
	camera_tween.tween_method(StartCameraShake, 5.0, 1.0, 0.4)

	hit_particles.restart()
	hit_particles.emitting = true

	var newDamageLabel = DAMAGE_LABEL.instantiate() as Label
	newDamageLabel.text = str(amount)
	newDamageLabel.global_position = global_position + Vector2(-25, -70)

	get_tree().current_scene.call_deferred(
		"add_child",
		newDamageLabel
	)

func die() -> void:
	go_to_death_state()

func play_death_fade() -> void:
	var tween = create_tween()

	tween.tween_interval(0.4)
	tween.tween_property(
		AnimationCharacter,
		"modulate:a",
		0.0,
		DEATH_FADE_DURATION
	)

	tween.tween_callback(
		func(): set_physics_process(false)
	)

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

		"Attack_Slash":
			if buffered_attack:
				buffered_attack = false
				go_to_attack1_state()
			else:
				go_to_idle_state()
		"Land":
			go_to_idle_state()

func flash_hit():
	FlashHit.play("flash_hit")

func StartCameraShake(intensity: float):
	var cameraOffset = cameraShakeNoise.get_noise_1d(Time.get_ticks_msec()) * intensity

	camera2D.offset.x = cameraOffset
	camera2D.offset.y = cameraOffset
