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

// Functions
float checkAround(Agent agent, vec2 dir) {
    float concentration = 0.0;
    vec2 direction = agent.velocity + dir;
    vec2 pos = agent.position + direction * 10.0;

    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 col = imageLoad(outputImage, ivec2(pos + vec2(x, y))).rg;
            concentration += (col.r + col.g) / 2.0;
        }
    }

    return concentration;
}

uint hashi(uint x) {
  x ^= x >> uint(16);
  x *= 0x7feb352dU;
  x ^= x >> uint(15);
  x *= 0x846ca68bU;
  x ^= x >> uint(16);
  return x;
}

float random(vec2 t) {
    return float(hashi(uint(t.x) + hashi(uint(t.y)))) / float(0xffffffffU);
}

void main() {
    // Get the current index
    uint index = uint(gl_GlobalInvocationID.x);
    if (index >= agents.length()) {
        return;
    }

    // Get the agent at the current index
    Agent agent = agents[index];

    // Randomize the direction
    float rand = random(agent.position * deltaTime);

    // Check around and choose the largest concentration
    float rotation = 0.0;
    float leftConcentration = checkAround(agent, vec2(-1.0, 0.0));
    float rightConcentration = checkAround(agent, vec2(1.0, 0.0));
    float forwardConcentration = checkAround(agent, vec2(0.0, -1.0));
    // Steer towards the direction with the highest concentration
    if (forwardConcentration > leftConcentration && forwardConcentration > rightConcentration) {
        // Forward
    } else if (forwardConcentration < leftConcentration && forwardConcentration < rightConcentration) {
        // Apply a random rotation
        rotation += (rand - 0.5) * 4.0 * deltaTime;
    } else if (leftConcentration > rightConcentration) {
        // Left
        rotation += rand * 4.0 * deltaTime;
    } else {
        // Right
        rotation -= rand * 4.0 * deltaTime;
    }
    agent.velocity = agent.velocity * mat2(cos(rotation), -sin(rotation), sin(rotation), cos(rotation));
    agent.velocity = normalize(agent.velocity) * 100.0;

    // Move the agent
    agent.position += agent.velocity * deltaTime;

    // Wrap the agent around the screen
    // if (agent.position.x < 0.0) {
    //     agent.position.x += 1024.0;
    // } else if (agent.position.x >= 1024.0) {
    //     agent.position.x -= 1024.0;
    // }

    // if (agent.position.y < 0.0) {
    //     agent.position.y += 1024.0;
    // } else if (agent.position.y >= 1024.0) {
    //     agent.position.y -= 1024.0;
    // }

    // When approaching the edge, go in a random direction
    if (agent.position.x < 1.0 || agent.position.x >= 1023.0 || agent.position.y < 1.0 || agent.position.y >= 1023.0) {
        agent.position.x = min(1023.0, max(0.01, agent.position.x));
        agent.position.y = min(1023.0, max(0.01, agent.position.y));
        
        rand = random(agent.position * deltaTime) * 2.0 * 3.14159;
        agent.velocity = vec2(cos(rand), sin(rand)) * 100.0;
    }

    // Write the agent back to the buffer
    agents[index] = agent;

    // Write the agent to the image
    vec3 color = vec3(
        //(agent.position.x / 1024.0) * 0.5 + 0.5,
        //(agent.position.y / 1024.0) * 0.5 + 0.5,
        //0.0
        1.0, 1.0, 1.0
    );

    imageStore(outputImage, ivec2(agent.position), vec4(color, 1.0));
}