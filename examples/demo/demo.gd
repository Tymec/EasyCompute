extends Node2D


@export var agent_count: int = 100000
@export var agent_speed: float = 100.0

@export var rect: TextureRect

var compute: EasyCompute = EasyCompute.new()
var agents: PackedFloat32Array = PackedFloat32Array([])
var image: Image


func _ready():
	# Load shaders
	compute.load_shader("Post", "res://examples/demo/Post.glsl")
	compute.load_shader("Movement", "res://examples/demo/Movement.glsl")
	
	# Create agents
	for i in range(0, agent_count):
		# Spawn inside a circle
		var pos = Vector2(512, 512) + Vector2.RIGHT.rotated(randf_range(0, TAU)) * randf_range(0, 512)
		#var vel = Vector2.RIGHT.rotated(randf_range(0, TAU))
		# Make velocity towards center
		var vel = (Vector2(512, 512) - pos).normalized()

		agents.append_array([
			pos.x, pos.y,
			vel.x, vel.y,
		])

	# Register buffers
	compute.register_storage_buffer("Agents", 0, 0, agents.to_byte_array())
	compute.register_storage_buffer("Params", 1, 4)

	# Create image
	image = Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	var texture = ImageTexture.create_from_image(image)
	rect.texture = texture

	# Center sprite
	#rect.position = get_viewport_rect().size / 2 - Vector2(256, 256)

	# Register textures
	compute.register_texture("Output", 2, 1024, 1024, image.get_data(), RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM)

func _process(delta):
	# Check if compute is available
	if not compute.is_available():
		return

	# Update params
	compute.update_buffer("Params", PackedFloat32Array([delta]).to_byte_array())

	# Run movement shader
	compute.execute("Movement", ceili(float(agent_count) / 1024.0))
	compute.sync()

	# Apply post processing
	compute.execute("Post", 1024)
	compute.sync()

	# Get the output image
	var image_data = compute.fetch_texture("Output")
	image = Image.create_from_data(1024, 1024, false, Image.FORMAT_RGBA8, image_data)
	rect.texture.update(image)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
