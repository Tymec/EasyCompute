extends Node


var compute: EasyCompute = EasyCompute.new()


func _ready():
	# Load shader from file
	compute.load_shader(
		"default",				# Name: used to identify the shader later
		"res://example.glsl"	# Path to the shader file
	)

	# Register a storage buffer with data
	var arr = PackedFloat32Array([1.0, 2.0, 3.0, 4.0])
	compute.register_storage_buffer(
		"example_storage",	# Name: used to identify the buffer later
		0, 					# Binding: this is the binding point in the shader
		0, 					# Size: since we're passing the data, we don't need to specify the size
		arr.to_byte_array()	# Data: byte array
	)

	# Register a uniform buffer without data
	compute.register_uniform_buffer(
		"example_uniform",	# Name: used to identify the buffer later
		1, 					# Binding: this is the binding point in the shader
		32, 				# Size (bytes): since we're not passing the data, we need to specify the size
		[]					# Data: empty array as we're not passing any data
	)

	# Register a texture
	var image = Image.create(
		512, 					# Width
		512,					# Height
		false,					# Use mipmaps
		Image.FORMAT_RGBA8		# Format
	)

	compute.register_texture(
		"example_texture",		# Name: used to identify the texture later
		2,						# Binding: this is the binding point in the shader
		512,					# Width
		512,					# Height
		image.get_data(),		# Data
		RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM	# Data format: (must match the format of the image data)
	)

	# Check if the compute shader is available
	if not compute.is_available():
		return

	# Execute the compute shader
	compute.execute(
		"default", 	# Name of the shader
		1,			# Number of work groups in X direction
		1,			# Number of work groups in Y direction
		1			# Number of work groups in Z direction
	)

	# Wait for the compute shader to finish
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
	compute.register_uniform_buffer(
		"example_uniform",	# Name: used to identify the buffer later
		1,					# Binding: this is the binding point in the shader
		16,					# Size (bytes): since we're not passing the data, we need to specify the size
		[]					# Data: empty array
	)
	
	# Set the uniform buffer data (size 16 means 2 32-bit floats)
	var uniform_data = PackedFloat32Array([1.0, 2.0])
	compute.update_buffer("example_uniform", uniform_data.to_byte_array())

	# Execute the compute shader again
	compute.execute(
		"default",		# Name of the shader
		1,				# Number of work groups in X direction
		1, 				# Number of work groups in Y direction
		1				# Number of work groups in Z direction
	)

	# Wait for the compute shader to finish
	compute.sync()