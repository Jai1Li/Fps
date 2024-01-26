extends CharacterBody3D

# Player Nodes
@onready var head = $Neck/Head
@onready var standing_collision_shape = $Standing_collision_shape
@onready var crouching_collision_shape = $Crouching_collision_shape
@onready var ray_cast_3d = $RayCast3D
@onready var neck = $Neck
@onready var eyes = $Neck/Head/Eyes
@onready var animation_player = $Neck/Head/Eyes/AnimationPlayer

# Movement variables
@export var current_speed = 5.0
const walking_speed = 5.0
const sprinting_speed = 8.0
const crouching_speed = 3.0
const JUMP_VELOCITY = 4.5
var last_velocity = Vector3.ZERO

# Slide variable
var slide_timer = 0.0
var slide_timer_max = 1.0
var slide_vector = Vector2.ZERO
var slide_speed = 5

# Headbob variable
var head_bobbing_sprinting_speed = 22
var head_bobbing_walking_speed = 14
var head_bobbing_crouching_speed = 10

var head_bobbing_crouching_intensity = 0.05
var head_bobbing_sprinting_intensity = 0.2
var head_bobbing_walking_intensity = 0.01

var head_bobbing_vector = Vector2.ZERO
var head_bobbing_index = 0.0
var head_bobbing_current_intensity = 0.0

var free_look_tilt_amount = 5

# States
var walking = false
var sprinting = false
var crouching = false
var free_looking = false
var sliding = false

# Player movement variable
var lerp_speed = 10.0
var air_lerp_speed = 3.0
var crouching_depth = -0.5

# Input variables
const mouse_sensitivity = 0.25

var direction = Vector3.ZERO

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	# Ensures the mouse is stuck to the screen
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _input(event):
	
	# Relative sight view
	if event is InputEventMouseMotion:
		if free_looking:
			neck.rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
			neck.rotation.y = clamp(neck.rotation.y, deg_to_rad(-100), deg_to_rad(100))
		else:
			rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
			head.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta):
	
	# Movement input
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	# Crouch Movement command
	if Input.is_action_pressed("move_crouch") || sliding: 
		current_speed = lerp(current_speed, crouching_speed, delta * lerp_speed)
		head.position.y = lerp(head.position.y, crouching_depth, delta * lerp_speed)
		standing_collision_shape.disabled = true
		crouching_collision_shape.disabled = false
		
	# Slide logic
		if sprinting && input_dir != Vector2.ZERO:
			sliding = true
			slide_timer = slide_timer_max
			slide_vector = input_dir
			free_looking = true
		
		walking = false
		sprinting = false
		crouching = true
		
	# Default movement command
	elif !ray_cast_3d.is_colliding():
		current_speed = walking_speed
		head.position.y = lerp(head.position.y, 0.0, delta * lerp_speed)
		standing_collision_shape.disabled = false
		crouching_collision_shape.disabled = true
		
	# Sprinting Movement Command
		if Input.is_action_pressed("move_sprint"):
			current_speed = lerp(current_speed, sprinting_speed, delta * lerp_speed)
			
			walking = false
			sprinting = true
			crouching = false
		else:
			current_speed = lerp(current_speed, walking_speed, delta * lerp_speed)
			
			walking = true
			sprinting = false
			crouching = false
	
	# Handle free look
	if Input.is_action_pressed("free_look") || sliding:
		free_looking = true
		
		if sliding:
			eyes.rotation.z = lerp(eyes.rotation.z, -deg_to_rad(7.0), delta * lerp_speed)
		else:
			eyes.rotation.z = -deg_to_rad(neck.rotation.y * free_look_tilt_amount)
	else:
		free_looking = false
		neck.rotation.y = lerp(neck.rotation.y, 0.0, delta * lerp_speed)
		eyes.rotation.z = lerp(eyes.rotation.z, 0.0, delta * lerp_speed)
	
	# Sliding
	if sliding:
		slide_timer -= delta
		if slide_timer <= 0:
			sliding = false
			free_looking = false
			
	# Handle Headbobbing
	if sprinting:
		head_bobbing_current_intensity = head_bobbing_sprinting_intensity
		head_bobbing_index += head_bobbing_sprinting_speed * delta
	elif crouching:
		head_bobbing_current_intensity = head_bobbing_crouching_intensity
		head_bobbing_index += head_bobbing_crouching_speed * delta
	elif walking:
		head_bobbing_current_intensity = head_bobbing_walking_intensity
		head_bobbing_index += head_bobbing_walking_speed * delta
		
	if is_on_floor() && !sliding && input_dir != Vector2.ZERO:
		head_bobbing_vector.y = sin(head_bobbing_index)
		head_bobbing_vector.x = sin(head_bobbing_index/2) + 0.5
		
		eyes.position.y = lerp(eyes.position.y, head_bobbing_vector.y * (head_bobbing_current_intensity / 2.0), delta * lerp_speed)
		eyes.position.x = lerp(eyes.position.x, head_bobbing_vector.x * head_bobbing_current_intensity, delta * lerp_speed)
	else:
		eyes.position.y = lerp(eyes.position.y, 0.0, delta * lerp_speed)
		eyes.position.x = lerp(eyes.position.x, 0.0, delta * lerp_speed)
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("move_jump") and is_on_floor() and !ray_cast_3d.is_colliding():
		velocity.y = JUMP_VELOCITY
		sliding = false
		animation_player.play("jump")
		
	if is_on_floor():
		if last_velocity.y < 0.0:
			animation_player.play("landing")

	if is_on_floor():
		direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * lerp_speed)
	else:
		if input_dir != Vector2.ZERO:
			direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * air_lerp_speed)
	
	if sliding:
		direction = (transform.basis * Vector3(slide_vector.x, 0, slide_vector.y)).normalized()
		current_speed = (slide_timer + 0.1) * slide_speed

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed

	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	last_velocity = velocity
	move_and_slide()
