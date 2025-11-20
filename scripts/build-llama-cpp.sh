#!/bin/bash
# Build script for llama.cpp with SYCL support on Intel MAX GPU 1550

set -e

# Configuration
LLAMA_CPP_REPO="https://github.com/ggml-org/llama.cpp"
LLAMA_CPP_DIR="llama.cpp"
PATCHES_DIR="/lus/flare/projects/candle_aesp_CNDA/brettin/Aurora-Inferencing/ollama/gpt-oss-120b-intel-max-gpu/patches"
VULKAN_SDK_DIR="$(pwd -P)/1.4.328.1"

echo "=== Building llama.cpp with SYCL support for Intel MAX GPU 1550 ==="

# Check if Intel oneAPI is available
if [ -z "$ONEAPI_ROOT" ]; then
    if [ -f "/opt/intel/oneapi/setvars.sh" ]; then
        echo "Sourcing Intel oneAPI environment..."
        source /opt/intel/oneapi/setvars.sh
    else
        echo "ERROR: Intel oneAPI not found. Please install Intel oneAPI."
        exit 1
    fi
fi

# Check if Vulkan SDK is available
if [ ! -d "$VULKAN_SDK_DIR" ]; then
    echo "WARNING: Vulkan SDK not found at $VULKAN_SDK_DIR"
    echo "Run ./setup-vulkan-sdk.sh first"
    exit 1
fi

# Source Vulkan SDK environment
echo "Setting up Vulkan SDK environment..."
source "$VULKAN_SDK_DIR/setup-env.sh"

# Clone llama.cpp if not present
if [ ! -d "$LLAMA_CPP_DIR" ]; then
    echo "Cloning llama.cpp..."
    git clone "$LLAMA_CPP_REPO" "$LLAMA_CPP_DIR"
fi

cd "$LLAMA_CPP_DIR"

# Apply patches
echo "current working dir: $(pwd -P)"
echo "Applying patches from ${PATCHES_DIR} ..."
if [ ! -f ".patches_applied" ]; then
    patch -p1 < "$PATCHES_DIR/001-fix-tokenization-byte-fallback.patch"
    patch -p1 < "$PATCHES_DIR/002-link-stdc++fs.patch"
    patch -p1 < "$PATCHES_DIR/003-experimental-filesystem-support.patch"
    touch .patches_applied
    echo "Patches applied successfully"
else
    echo "Patches already applied, skipping..."
fi

# Clean previous build
if [ -d "build" ]; then
    echo "Cleaning previous build..."
    rm -rf build
fi

# Configure build
echo "Configuring build with CMake..."
cmake -B build \
    -DGGML_SYCL=ON \
    -DCMAKE_C_COMPILER=icx \
    -DCMAKE_CXX_COMPILER=icpx \
    -DLLAMA_CURL=OFF \
    -DCMAKE_BUILD_TYPE=Release

# Build
echo "Building llama.cpp..."
NUM_CORES=$(nproc)
cmake --build build --config Release -j $NUM_CORES

echo ""
echo "=== Build complete! ==="
echo ""
echo "Binary location: $(pwd)/build/bin/llama-cli"
echo ""
echo "To test the build:"
echo "  export ONEAPI_DEVICE_SELECTOR=\"level_zero:0\""
echo "  ./build/bin/llama-cli -m /path/to/model.gguf -p \"Hello\" -ngl 25"
echo ""
