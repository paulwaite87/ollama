FROM ubuntu:26.04

# Prevent apt from prompting for timezones during installation
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary build tools, Vulkan dependencies, headers, and the shader compiler
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libvulkan-dev \
    vulkan-tools \
    spirv-headers \
    glslc \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /llama.cpp

# Clone the fresh source code directly from the official repo
RUN git clone --depth 1 https://github.com/ggml-org/llama.cpp.git .

# Build with Vulkan enabled and the massive context limit
RUN cmake -B build \
    -DGGML_VULKAN=ON \
    -DGGML_MAX_N_CTX=131072 \
    -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build --target llama-server -j$(nproc)

# The resulting binary is placed in build/bin/
ENTRYPOINT ["./build/bin/llama-server"]

