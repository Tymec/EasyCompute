# EasyCompute - Simplified Compute Shader Wrapper for Godot
EasyCompute is a Godot Engine addon that streamlines the usage of compute shaders with a user-friendly API. Simplify shader loading, buffer management, and shader execution to accelerate your development workflow.

## Installation
1. Download the latest version of the addon [here](https://github.com/Tymec/EasyCompute/releases/latest).
2. Place the `addons` folder in your project's root directory.
3. Now, you're ready to use the addon using the global `EasyCompute` class.

## Usage
![Example usage](/assets/usage.png)

### Initialization
Create a new instance of the `EasyCompute` class.
```gdscript
var compute = EasyCompute.new()
```

### Load Shader
Load a compute shader from a file and associate it with a name.
```gdscript
compute.load_shader("example", "res://example.glsl")
```

You can load multiple shaders and execute any of them at any time (as long as no other shader is currently executing). For example, you can execute a shader to draw to a texture, then execute another shader to blur that texture, without having to fetch the texture from the GPU to the CPU and then back to the GPU.

### Manage Buffers
Effortlessly handle storage and uniform buffers.

#### Storage Buffer
You can either create a buffer from existing data:
```gdscript
var arr = PackedFloat32Array([1.0, 2.0, 3.0, 4.0])
compute.register_storage_buffer(
    "example_storage",      # name
    0,                      # binding
    0,                      # size (ignored if data is provided)
    arr.to_byte_array()     # data
)
```

Or create an empty buffer with a specified size and update it later:
```gdscript
compute.register_storage_buffer(
    "example_storage",      # name
    0,                      # binding
    4 * 4,                  # size in bytes (4 floats * 4 bytes per float)
)

# later in the code
var arr = PackedFloat32Array([1.0, 2.0, 3.0, 4.0])
compute.update_buffer("example_storage", arr.to_byte_array())
```

#### Uniform Buffer
Same as storage buffers, but use `register_uniform_buffer` instead.
```gdscript
var uniform_data = PackedFloat32Array([1.0, 2.0, 3.0, 4.0])
compute.register_uniform_buffer("example_uniform", 1, 0, uniform_data.to_byte_array())
```

#### Texture
```gdscript
var image = Image.create(512, 512, false, Image.FORMAT_RGBA8)
compute.register_texture("example_texture", 2, 512, 512, image.get_data(), RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM)
```

### Execution
Ensure compute shader availability before executing it.
```gdscript
if not compute.is_available():
    return
```

Execute the compute shader with defined work groups.
```gdscript
compute.execute(
    "example",  # name of the shader to dispatch
    1,          # number of work groups in X dimension
    1,          # number of work groups in Y dimension
    1           # number of work groups in Z dimension
)
compute.sync()
```

### Data Handling
Retrieve buffer data post-compute.
```gdscript
var buffer_data = compute.fetch_buffer("example_storage")
var arr = buffer_data.to_float32_array()
```

Retrieve texture data post-compute.
```gdscript
var image_data = compute.fetch_texture("example_texture")
var image = Image.create_from_data(512, 512, false, Image.FORMAT_RGBA8, image_data)
```

Update storage buffers seamlessly.
```gdscript
arr[0] = 5.0
compute.update_buffer("example_storage", arr.to_byte_array())
```

### Finishing Up
When you're done with a buffer/texture, unregister it.
```gdscript
compute.unregister_buffer("example_uniform")
```

## License
Distributed under the MIT License. See [LICENSE](/LICENSE) for more information.