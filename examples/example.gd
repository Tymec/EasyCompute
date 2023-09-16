extends Node

var compute: EasyCompute = EasyCompute.new()

func _ready():
	# Load shader from file with the specified path and store it with the specified name
	compute.load_shader("default", "res://example.glsl")

	# Register a storage buffer
	var arr = PackedFloat32Array([1.0, 2.0, 3.0, 4.0])
	compute.register_storage_buffer(
		"example_storage",	# Name: used to identify the buffer later
		0, 					# Binding: this is the binding point in the shader
		0, 					# Size: since we're passing the data, we don't need to specify the size
		arr.to_byte_array()
	)

	# Register a uniform buffer with size 32 (4 32-bit floats) and no data
	compute.register_uniform_buffer("example_uniform", 1, 32)

	# Register a texture
	var image = Image.create(512, 512, false, Image.FORMAT_RGBA8)
	compute.register_texture("example_texture", 2, 512, 512, image.get_data(), RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM)

	# Check if the compute shader is available
	if not compute.is_available():
		return

	# Execute the compute shader (1 work group in each direction) and wait for it to finish
	compute.execute("default", 1, 1, 1)
	compute.sync()

	# Retrieve the texture data
	var _texture_data = compute.fetch_texture("example_texture")
	# do something with the texture data #

	# Update the storage buffer
	arr[0] = 5.0
	compute.update_buffer("example_storage", arr.to_byte_array())

	# Unregister the uniform buffer
	compute.unregister_buffer("example_uniform")

	# Register the uniform buffer again, but with half the size
	compute.register_uniform_buffer("example_uniform", 1, 16, [])
	
	# Set the uniform buffer data (size 16 means 2 32-bit floats)
	var uniform_data = PackedFloat32Array([1.0, 2.0])
	compute.update_buffer("example_uniform", uniform_data.to_byte_array())

	# Execute the compute shader again (1 work group in each direction) and wait for it to finish
	compute.execute("default", 1, 1, 1)

	# Wait for the compute shader to finish
	compute.sync()