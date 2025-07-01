#include <cuda_runtime.h>
#include <iostream>
#include <cmath>
#include <cstdio>
#include <ctime>

#ifdef _WIN32
#include <windows.h>
#define SLEEP_MS(x) Sleep(x)
#define IS_WINDOWS 1
#else
#include <unistd.h>
#define SLEEP_MS(x) usleep((x)*1000)
#define IS_WINDOWS 0
#endif

#define WIDTH 60
#define HEIGHT 30
#define GRAVITY -0.005f
#define THERMAL_FORCE 0.10f
#define VISCOSITY 0.96f
#define COOLING_RATE 0.998f
#define HEATING_RATE 0.04f

struct Particle {
    float x, y;
    float vx, vy;
    float temperature;
    float density;
    bool active;
};

__device__ float simpleRandom(unsigned int* seed) {
    *seed = (*seed * 1664525 + 1013904223);
    return (float)(*seed) / 4294967296.0f;
}

__global__ void initParticles(Particle* particles, int numParticles, unsigned int baseSeed) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= numParticles) return;

    unsigned int seed = baseSeed + idx * 7919;

    // Start particles randomly distributed throughout the lamp
    particles[idx].x = simpleRandom(&seed) * (WIDTH - 6) + 3;
    particles[idx].y = simpleRandom(&seed) * (HEIGHT - 4) + 2;
    particles[idx].vx = (simpleRandom(&seed) - 0.5f) * 0.02f;
    particles[idx].vy = (simpleRandom(&seed) - 0.5f) * 0.02f;
    particles[idx].temperature = simpleRandom(&seed) * 0.6f + 0.2f;
    particles[idx].density = 1.0f - particles[idx].temperature * 0.4f; // Hot = less dense
    particles[idx].active = true;
}

__global__ void updateParticles(Particle* particles, int numParticles, int width, int height, int frame) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= numParticles) return;

    Particle* p = &particles[idx];
    unsigned int seed = frame * 31415 + idx * 2718;

    // Heat source at bottom (like the lamp's heating element)
    float distFromBottom = p->y / (float)height;
    if (distFromBottom < 0.15f) {
        // Strong heating near bottom
        p->temperature += HEATING_RATE * (0.15f - distFromBottom) * 6.0f;
        if (p->temperature > 1.0f) p->temperature = 1.0f;
    }

    // Cooling at top (like touching the cool top of the lamp)
    if (distFromBottom > 0.85f) {
        p->temperature *= 0.995f; // Faster cooling at top
    } else {
        // Gradual cooling throughout the lamp
        p->temperature *= COOLING_RATE;
    }

    // Update density based on temperature (hot = less dense = rises)
    p->density = 1.2f - p->temperature * 0.5f;

    // Buoyancy force - hot particles rise, cool particles sink
    float buoyancy = (0.8f - p->density) * THERMAL_FORCE;
    p->vy += GRAVITY + buoyancy;

    // Add some convection currents and turbulence
    float convection = sinf(p->x * 0.1f + frame * 0.01f) * 0.001f;
    p->vx += convection;
    p->vx += (simpleRandom(&seed) - 0.5f) * 0.002f;
    p->vy += (simpleRandom(&seed) - 0.5f) * 0.001f;

    // Apply viscosity (lava is thick!)
    p->vx *= VISCOSITY;
    p->vy *= VISCOSITY;

    // Update position
    p->x += p->vx;
    p->y += p->vy;

    // Boundary conditions - bounce off walls
    if (p->x <= 2) { 
        p->x = 2; 
        p->vx = -p->vx * 0.5f; 
    }
    if (p->x >= width - 3) { 
        p->x = width - 3; 
        p->vx = -p->vx * 0.5f; 
    }

    // Bounce off top and bottom with some energy loss
    if (p->y <= 1) { 
        p->y = 1; 
        p->vy = -p->vy * 0.3f;
        // Extra heating when hitting the bottom heating element
        p->temperature += 0.05f;
        if (p->temperature > 1.0f) p->temperature = 1.0f;
    }
    if (p->y >= height - 2) { 
        p->y = height - 2; 
        p->vy = -p->vy * 0.3f;
        // Extra cooling when hitting the top
        p->temperature *= 0.95f;
    }

    // Ensure temperature bounds
    if (p->temperature < 0.0f) p->temperature = 0.0f;
    if (p->temperature > 1.0f) p->temperature = 1.0f;
}

__global__ void renderField(Particle* particles, int numParticles, float* field, int width, int height) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x >= width || y >= height) return;

    int idx = y * width + x;
    field[idx] = 0.0f;

    // Add base temperature gradient (hot at bottom, cool at top)
    float baseTemp = expf(-((float)y / height) * 2.5f) * 0.25f;
    field[idx] += baseTemp;

    // Add particle contributions
    for (int i = 0; i < numParticles; i++) {
        float dx = (float)x - particles[i].x;
        float dy = (float)y - particles[i].y;
        float dist = sqrtf(dx * dx + dy * dy);

        if (dist < 4.0f) {
            float influence = expf(-dist * dist * 0.3f);
            field[idx] += particles[i].temperature * influence * 0.7f;
        }
    }

    if (field[idx] > 1.0f) field[idx] = 1.0f;
}

void clearScreen() {
#ifdef _WIN32
    system("cls");
#else
    printf("\033[2J\033[H");
#endif
}

void renderLavaLamp(float* field, int width, int height, int frame) {
    clearScreen();

    // Draw lamp container
    if (IS_WINDOWS) {
        printf("    +");
        for (int i = 0; i < width; i++) printf("-");
        printf("+\n");
    } else {
        printf("    ╔");
        for (int i = 0; i < width; i++) printf("═");
        printf("╗\n");
    }

    for (int y = height - 1; y >= 0; y--) {
        printf("    %s", IS_WINDOWS ? "|" : "║");
        for (int x = 0; x < width; x++) {
            float val = field[y * width + x];

            if (IS_WINDOWS) {
                char c;
                if (val > 0.8f) c = '#';        // Very hot
                else if (val > 0.6f) c = '@';   // Hot
                else if (val > 0.4f) c = '*';   // Warm
                else if (val > 0.25f) c = 'o';  // Lukewarm
                else if (val > 0.15f) c = '.';  // Cool
                else if (val > 0.05f) c = '\''; // Cold
                else c = ' ';                   // Background
                printf("%c", c);
            } else {
                // Use colors for better effect on Unix terminals
                if (val > 0.8f) printf("\033[91m█\033[0m");      // Bright red
                else if (val > 0.6f) printf("\033[93m▓\033[0m"); // Yellow
                else if (val > 0.4f) printf("\033[33m▒\033[0m"); // Orange
                else if (val > 0.25f) printf("\033[31m░\033[0m"); // Red
                else if (val > 0.15f) printf("\033[90m·\033[0m"); // Gray
                else if (val > 0.05f) printf("\033[34m'\033[0m"); // Blue (cool)
                else printf(" ");
            }
        }
        printf("%s\n", IS_WINDOWS ? "|" : "║");
    }

    if (IS_WINDOWS) {
        printf("    +");
        for (int i = 0; i < width; i++) printf("-");
        printf("+\n");
        printf("    [========== HEATING ELEMENT ==========]\n");
        printf("    LAVA LAMP SIMULATION - Frame %d\n", frame);
    } else {
        printf("    ╚");
        for (int i = 0; i < width; i++) printf("═");
        printf("╝\n");
        printf("    🔥🔥🔥🔥🔥 HEATING ELEMENT 🔥🔥🔥🔥🔥\n");
        printf("    🌋 LAVA LAMP SIMULATION - Frame %d 🌋\n", frame);
    }

    fflush(stdout);
}

int main() {
    const int numParticles = 180;
    const int fieldSize = WIDTH * HEIGHT * sizeof(float);

#ifdef _WIN32
    SetConsoleOutputCP(CP_UTF8);
    SetConsoleCP(CP_UTF8);
#endif

    printf("Initializing CUDA...\n");

    int deviceCount;
    cudaGetDeviceCount(&deviceCount);
    if (deviceCount == 0) {
        printf("No CUDA devices found!\n");
        return -1;
    }

    float* h_field = (float*)malloc(fieldSize);
    Particle* d_particles;
    float* d_field;

    cudaMalloc(&d_particles, numParticles * sizeof(Particle));
    cudaMalloc(&d_field, fieldSize);

    cudaMemset(d_field, 0, fieldSize);

    dim3 particleBlock(256);
    dim3 particleGrid((numParticles + particleBlock.x - 1) / particleBlock.x);

    dim3 fieldBlock(16, 16);
    dim3 fieldGrid((WIDTH + fieldBlock.x - 1) / fieldBlock.x, 
                   (HEIGHT + fieldBlock.y - 1) / fieldBlock.y);

    printf("Initializing lava particles...\n");
    unsigned int seed = (unsigned int)time(NULL);
    initParticles<<<particleGrid, particleBlock>>>(d_particles, numParticles, seed);
    cudaDeviceSynchronize();

    cudaError_t error = cudaGetLastError();
    if (error != cudaSuccess) {
        printf("CUDA error: %s\n", cudaGetErrorString(error));
        return -1;
    }

    printf("🌋 Starting Lava Lamp Simulation...\n");
    printf("Watch the hot particles rise and cool particles sink!\n");
    if (IS_WINDOWS) {
        printf("Note: For best visuals, use Windows Terminal\n");
    }
    SLEEP_MS(2000);

    for (int frame = 0; frame < 10000; frame++) {
        // Update particle physics
        updateParticles<<<particleGrid, particleBlock>>>(d_particles, numParticles, WIDTH, HEIGHT, frame);

        // Render temperature field
        renderField<<<fieldGrid, fieldBlock>>>(d_particles, numParticles, d_field, WIDTH, HEIGHT);

        // Display every few frames
        if (frame % 3 == 0) {
            cudaMemcpy(h_field, d_field, fieldSize, cudaMemcpyDeviceToHost);
            renderLavaLamp(h_field, WIDTH, HEIGHT, frame);
            SLEEP_MS(120);
        }

        // Occasionally add some thermal disturbance
        if (frame % 300 == 0) {
            initParticles<<<1, 20>>>(d_particles, 20, seed + frame);
        }
    }

    free(h_field);
    cudaFree(d_particles);
    cudaFree(d_field);

    return 0;
}
