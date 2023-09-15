#[compute]
#version 450

// Definitions
struct Agent {
    vec2 position;
    vec2 velocity;
};

// Uniforms and buffers
layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;
layout(set = 0, binding = 0, std430) restrict buffer Agents {
    Agent agents[];
};
layout(set = 0, binding = 1, std430) restrict readonly buffer Params {
  float deltaTime;
};
layout(set = 0, binding = 2, rgba8) uniform image2D outputImage;

void main() {
    uint index = gl_GlobalInvocationID.x;
    ivec2 pixelCoords = ivec2(index % 1024, index / 1024);
    vec3 pixel = imageLoad(outputImage, pixelCoords).rgb;
    
    // Blur
    vec3 color = vec3(0.0);
    for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
            color += imageLoad(outputImage, pixelCoords + ivec2(i, j)).rgb;
        }
    }
    color /= 9.0;
    color = mix(pixel, color, 5.0 * deltaTime);

    // Evaporate
    color = color - 0.75 * deltaTime;
    color = max(color, vec3(0.0));

    // diffuse
    //vec3 color = pixel.rgb - 0.2 * deltaTime;
    //color = max(color, vec3(0.1, 0.1, 0.1));

    imageStore(outputImage, pixelCoords, vec4(color, 1.0));
}