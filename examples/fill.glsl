#[compute]
#version 450

layout(set = 0, binding = 0, rgba8) uniform image2D colorImage;
layout(set = 0, binding = 1, std430) restrict readonly buffer Color {
  vec4 fillColor;
};

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
void main() {
    ivec2 storePos = ivec2(gl_LocalInvocationID.x, gl_WorkGroupID.x);
    imageStore(colorImage, storePos, fillColor);
}
