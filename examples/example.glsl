#[compute]
#version 450

// Definitions


// Uniforms and buffers
layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;
layout(set = 0, binding = 0, std430) restrict buffer StorageBuffer {
    float speed;
    float deltaTime;

};
layout(set = 0, binding = 1, std140) restrict buffer UniformBuffer {
    vec2 position;
};
layout(rgba8, binding = 2) uniform image2D image;

void main() {

}