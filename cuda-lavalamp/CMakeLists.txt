cmake_minimum_required(VERSION 3.18)

# Set the project name and enable CUDA language
project(LavaLampSimulation LANGUAGES CXX CUDA)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find CUDA
find_package(CUDA REQUIRED)
enable_language(CUDA)

# Set CUDA architecture (adjust based on your GPU)
# Common architectures: 50, 60, 61, 70, 75, 80, 86, 89, 90
set(CMAKE_CUDA_ARCHITECTURES "60;70;75;80;86")

# Set CUDA standard
set(CMAKE_CUDA_STANDARD 17)
set(CMAKE_CUDA_STANDARD_REQUIRED ON)

# Compiler-specific options
if(MSVC)
    # Visual Studio specific settings
    set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -Xcompiler=/W3")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /W3")
else()
    # GCC/Clang specific settings
    set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -Xcompiler=-Wall")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall")
endif()

# Include directories
include_directories(${CMAKE_CUDA_TOOLKIT_INCLUDE_DIRECTORIES})

# Main executable - Lava Lamp Simulation
add_executable(wave src/wave.cu)

# Set target properties for CUDA
set_target_properties(wave PROPERTIES
    CUDA_RUNTIME_LIBRARY Shared
    CUDA_SEPARABLE_COMPILATION ON
)

# Link CUDA libraries
target_link_libraries(wave ${CUDA_LIBRARIES})

# Optional: Build other CUDA files if needed
if(EXISTS "${CMAKE_SOURCE_DIR}/src/2_wave.cu")
    add_executable(2_wave src/2_wave.cu)
    set_target_properties(2_wave PROPERTIES
        CUDA_RUNTIME_LIBRARY Shared
        CUDA_SEPARABLE_COMPILATION ON
    )
    target_link_libraries(2_wave ${CUDA_LIBRARIES})
endif()

if(EXISTS "${CMAKE_SOURCE_DIR}/src/good_wave.cu")
    add_executable(good_wave src/good_wave.cu)
    set_target_properties(good_wave PROPERTIES
        CUDA_RUNTIME_LIBRARY Shared
        CUDA_SEPARABLE_COMPILATION ON
    )
    target_link_libraries(good_wave ${CUDA_LIBRARIES})
endif()

# Set output directory
set_target_properties(wave PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
)

# Platform-specific settings
if(WIN32)
    # Windows-specific settings
    target_compile_definitions(wave PRIVATE _WIN32)
    
    # Ensure console output works properly on Windows
    if(MSVC)
        set_target_properties(wave PROPERTIES
            LINK_FLAGS "/SUBSYSTEM:CONSOLE"
        )
    endif()
endif()

# Optional: Install targets
install(TARGETS wave
    RUNTIME DESTINATION bin
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
)

# Optional: Enable testing
option(BUILD_TESTS "Build tests" OFF)
if(BUILD_TESTS)
    enable_testing()
    # Add test configurations here if needed
endif()

# Print some useful information
message(STATUS "CUDA Version: ${CUDA_VERSION}")
message(STATUS "CUDA Toolkit Root: ${CUDA_TOOLKIT_ROOT_DIR}")
message(STATUS "CUDA Architectures: ${CMAKE_CUDA_ARCHITECTURES}")
