@icon("res://addons/easy_compute/icon.svg")
class_name EasyCompute extends RefCounted


signal compute_dispatched(shader_name: String)
signal compute_synced()


var rd: RenderingDevice = null
var shader_cache: Dictionary = {}
var data_cache: Dictionary = {}


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		# Check if rendering device is already initialized
		if rd == null:
			return
		assert(is_instance_valid(rd), "Rendering device is not valid")

		# Destroy compute pipelines
		for obj in shader_cache.values():
			if obj["pipeline"].is_valid():
				rd.free_rid(obj["pipeline"])

		# Destroy uniform sets
		for obj in shader_cache.values():
			if obj["uniform_set"].is_valid():
				rd.free_rid(obj["uniform_set"])

		# Destroy uniform objects
		for obj in data_cache.values():
			var rid = obj["rid"]

			# if rid is an array, loop through it
			if rid is Array:
				for r in rid:
					if r.is_valid():
						rd.free_rid(r)
			# else, just destroy it
			else:
				if rid.is_valid():
					rd.free_rid(rid)
		data_cache.clear()
		assert(data_cache.size() == 0, "Data cache was not cleared")

		# Destroy shaders
		for obj in shader_cache.values():
			if obj["shader"].is_valid():
				rd.free_rid(obj["shader"])
		shader_cache.clear()
		assert(shader_cache.size() == 0, "Data cache was not cleared")

		# Destroy rendering device
		rd.free()
		assert(not is_instance_valid(rd), "Rendering device was not freed")
		rd = null

func _init_gpu() -> bool:
	# Check if rendering device is already initialized
	if rd != null:
		return true

	# Create a rendering device
	rd = RenderingServer.create_local_rendering_device()
	if rd == null:
		push_error("Failed to create rendering device")
		assert(false, "Failed to create rendering device")
		return false

	return true

func _finish_register(uniform_name: String, rid: RID, binding: int, uniform_type: int) -> void:
	# Create uniform
	var uniform = RDUniform.new()
	uniform.uniform_type = uniform_type
	uniform.binding = binding
	uniform.add_id(rid)

	# Add uniform to cache
	data_cache[uniform_name] = {
		"rid": rid,
		"uniform": uniform,
		"binding": binding,
	}

	# Invalidate uniform set
	for shd in shader_cache.values():
		if shd["uniform_set"].is_valid():
			rd.free_rid(shd["uniform_set"])
			shd["uniform_set"] = RID()

func _precheck(uniform_name: String, should_contain: bool = false) -> bool:
	if not _init_gpu():
		# Check if rendering device is already initialized
		return false
	elif (uniform_name in data_cache) != should_contain:
		# Check if uniform is already registered
		push_warning("Uniform with name '%s' %sregistered" % [uniform_name, "not " if should_contain else ""])
		return false

	return true

## Loads the given shader from file and creates a compute pipeline
func load_shader(shader_name: String, file_path: String) -> bool:
	if not _init_gpu():
		# Check if rendering device is already initialized
		return false
	elif shader_name in shader_cache:
		# Check if shader with name is already registered
		push_warning("Shader with name '%s' already registered" % [shader_name])
		return false
	elif not ".glsl" in file_path:
		# Check if file at path is a GLSL file
		push_warning("File at path '%s' is not a GLSL file" % [file_path])
		return false

	# Load shader from file
	var shader_code = load(file_path)
	var shader_spirv = shader_code.get_spirv()
	var shader = rd.shader_create_from_spirv(shader_spirv)

	# Create compute pipeline
	var pipeline = rd.compute_pipeline_create(shader)
	assert(pipeline.is_valid(), "Failed to create compute pipeline")

	# Add shader to cache
	shader_cache[shader_name] = {
		"shader": shader,
		"pipeline": pipeline,
		"uniform_set": RID(),
	}

	return true

## Unloads a shader along with its compute pipeline from the cache
func unload_shader(shader_name: String) -> bool:
	if not _init_gpu():
		# Check if rendering device is already initialized
		return false
	elif not shader_name in shader_cache:
		# Check if shader with name is registered
		push_warning("Shader with name '%s' is not registered" % [shader_name])
		return false

	# Remove shader from cache
	var obj = shader_cache[shader_name]
	shader_cache.erase(shader_name)

	# Destroy compute pipeline
	if obj["pipeline"].is_valid():
		rd.free_rid(obj["pipeline"])

	# Destroy uniform set
	if obj["uniform_set"].is_valid():
		rd.free_rid(obj["uniform_set"])

	# Destroy shader
	if obj["shader"].is_valid():
		rd.free_rid(obj["shader"])

	return true

## Registers a storage buffer under the given name
func register_storage_buffer(buffer_name: String, binding: int, size: int = 0, data: PackedByteArray = PackedByteArray()) -> bool:
	if not _precheck(buffer_name, false):
		return false

	# Use data size if size is not specified
	if size == 0:
		size = data.size()

	assert(size > 0, "Size for buffer '%s' must be greater than 0" % [buffer_name])

	# Create buffer
	var rid = rd.storage_buffer_create(size, data)
	assert(rid.is_valid(), "Failed to create storage buffer '%s'" % [buffer_name])

	# Create uniform, cache it and invalidate uniform set
	_finish_register(buffer_name, rid, binding, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER)

	return true

## Registers a uniform buffer under the given name
func register_uniform_buffer(buffer_name: String, binding: int, size: int = 0, data: PackedByteArray = PackedByteArray()) -> bool:
	if not _precheck(buffer_name, false):
		return false

	# Use data size if size is not specified
	if size == 0:
		size = data.size()

	assert(size > 0, "Size for buffer '%s' must be greater than 0" % [buffer_name])

	# Create buffer
	var rid = rd.uniform_buffer_create(size, data)
	assert(rid.is_valid(), "Failed to create uniform buffer '%s'" % [buffer_name])

	# Create uniform, cache it and invalidate uniform set
	_finish_register(buffer_name, rid, binding, RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER)

	return true

## Registers a texture uniform under the given name
func register_texture(
	texture_name: String, binding: int,
	width: float = 0, height: float = 0,
	data: PackedByteArray = [],
	format: int = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM,
	additional_usage_bits: int = 0,
) -> bool:
	if not _precheck(texture_name, false):
		return false

	# Create texture format
	var texture_format = RDTextureFormat.new()
	texture_format.format = format
	texture_format.width = width
	texture_format.height = height
	texture_format.usage_bits = ( 
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | 		# Required
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT |	# Required to retrieve texture data using 'fetch_texture()'
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT		# Required to update texture data using 'update_texture()'
	) | additional_usage_bits

	# Create texture view
	var texture_view = RDTextureView.new()

	# Create texture
	var rid = rd.texture_create(texture_format, texture_view, [] if data.is_empty() else [data])
	assert(rid.is_valid(), "Failed to create texture '%s'" % [texture_name])

	# Create uniform, cache it and invalidate uniform set
	_finish_register(texture_name, rid, binding, RenderingDevice.UNIFORM_TYPE_IMAGE)

	return true

## Registers a sampler uniform under the given name
func register_sampler(
	sampler_name: String, binding: int,
	width: float = 0, height: float = 0,
	data: PackedByteArray = [],
	format: int = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM,
	additional_usage_bits: int = 0,
) -> bool:
	if not _precheck(sampler_name, false):
		return false

	# Create texture format
	var texture_format = RDTextureFormat.new()
	texture_format.format = format
	texture_format.width = width
	texture_format.height = height
	texture_format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | 		# Required
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |		# Required to sample texture
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT |	# Required to retrieve texture data using 'fetch_sampler()'
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT		# Required to update texture data using 'update_sampler()'
	) | additional_usage_bits

	# Create texture view
	var texture_view = RDTextureView.new()

	# Create texture
	var texture_rid = rd.texture_create(texture_format, texture_view, [] if data.is_empty() else [data])

	# Create sampler state
	var sampler_state = RDSamplerState.new()
	#sampler_state.unnormalized_uvw = true

	# Create sampler
	var sampler_rid = rd.sampler_create(sampler_state)

	# Create uniform
	var uniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.binding = binding
	uniform.add_id(sampler_rid)
	uniform.add_id(texture_rid)

	# Add uniform to cache
	data_cache[sampler_name] = {
		"rid": [texture_rid, sampler_rid],
		"uniform": uniform,
		"binding": binding,
	}

	# Invalidate uniform set
	for shd in shader_cache.values():
		if shd["uniform_set"].is_valid():
			rd.free_rid(shd["uniform_set"])
			shd["uniform_set"] = RID()

	return false

## Removes any registered uniforms and buffers
func unregister_uniform(uniform_name: String) -> bool:
	if not _precheck(uniform_name, true):
		return false

	# Remove uniform from cache
	var obj = data_cache[uniform_name]
	data_cache.erase(uniform_name)

	# Invalidate uniform set
	for shd in shader_cache.values():
		if shd["uniform_set"].is_valid():
			rd.free_rid(shd["uniform_set"])
			shd["uniform_set"] = RID()

	# Destroy uniform object(s)
	var rid = obj["rid"]
	if rid is Array:
		# if rid is an array, loop through it
		for r in rid:
			if r.is_valid():
				rd.free_rid(r)
	else:
		# else, just destroy it
		if rid.is_valid():
			rd.free_rid(rid)

	return true

## Updates a buffer with new data
func update_buffer(buffer_name: String, data: PackedByteArray) -> bool:
	if not _precheck(buffer_name, true):
		return false

	# Update buffer
	var buffer = data_cache[buffer_name]
	rd.buffer_update(buffer["rid"], 0, data.size(), data)

	return true

## Updates a texture uniform with new data
func update_texture(texture_name: String, data: PackedByteArray) -> bool:
	if not _precheck(texture_name, true):
		return false

	# Update texture
	var texture = data_cache[texture_name]
	rd.texture_update(texture["rid"], 0, data)

	return true

## Updates a sampler uniform with new data
func update_sampler(sampler_name: String, data: PackedByteArray) -> bool:
	if not _precheck(sampler_name, true):
		return false

	# Update texture
	var sampler = data_cache[sampler_name]
	rd.texture_update(sampler["rid"][0], 0, data)
	
	return true

## Returns data of the given buffer from the GPU
func fetch_buffer(buffer_name: String) -> PackedByteArray:
	if not _precheck(buffer_name, true):
		return PackedByteArray()

	# Fetch buffer
	var buffer = data_cache[buffer_name]
	return rd.buffer_get_data(buffer["rid"])

## Returns data of the given texture from the GPU
func fetch_texture(texture_name: String) -> PackedByteArray:
	if not _precheck(texture_name, true):
		return PackedByteArray()

	# Fetch texture
	var texture = data_cache[texture_name]
	return rd.texture_get_data(texture["rid"], 0)

## Returns data of the given sampler from the GPU
func fetch_sampler(sampler_name: String) -> PackedByteArray:
	if not _precheck(sampler_name, true):
		return PackedByteArray()

	# Fetch texture
	var sampler = data_cache[sampler_name]
	return rd.texture_get_data(sampler["rid"][0], 0)

## Creates a compute list for the given shader and dispatches it
func execute(shader_name: String, x_groups: int = 1, y_groups: int = 1, z_groups: int = 1) -> void:
	assert(rd != null, "Rendering device is not initialized")
	assert(x_groups > 0 and y_groups > 0 and z_groups > 0, "Number of groups must be greater than 0")
	assert(shader_name in shader_cache, "Shader with name '%s' is not registered" % [shader_name])

	# Get shader and pipeline
	var shader = shader_cache[shader_name]["shader"]
	var pipeline = shader_cache[shader_name]["pipeline"]
	var uniform_set = shader_cache[shader_name]["uniform_set"]

	# Create compute list
	var compute_list = rd.compute_list_begin()

	# Bind compute pipeline
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)

	# Create uniform set if it doesn't exist
	if not uniform_set.is_valid():
		var uniforms = data_cache.values().map(func(obj):
			return obj["uniform"]
		)
		uniform_set = rd.uniform_set_create(uniforms, shader, 0)
		assert(uniform_set.is_valid(), "Failed to create uniform set")
		shader_cache[shader_name]["uniform_set"] = uniform_set
	
	# Bind uniform set
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)

	# Dispatch compute list
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)

	# End compute list
	rd.compute_list_end()

	# Submit compute list
	rd.submit()

	# Emit signal
	compute_dispatched.emit(shader_name)

## Forces a synchronization between the CPU and GPU
func sync() -> void:
	assert(rd != null, "Rendering device is not initialized")

	# Wait for compute list to finish
	rd.sync()

	# Emit signal
	compute_synced.emit()

## Returns whether the rendering device is available
func is_available() -> bool:
	return _init_gpu()
