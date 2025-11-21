#!/bin/bash
# Complete build script for llama.cpp with SYCL support on Intel MAX GPU 1550
# This script includes all necessary environment setup and error checking

set -e

# Configuration
LLAMA_CPP_REPO="https://github.com/ggml-org/llama.cpp"
LLAMA_CPP_DIR="llama.cpp"
PATCHES_DIR="/lus/flare/projects/candle_aesp_CNDA/brettin/Aurora-Inferencing/ollama/gpt-oss-120b-intel-max-gpu/patches"
VULKAN_SDK_DIR="$(pwd -P)/1.4.328.1"
ENV_FILE="/home/brettin/candle_aesp_CNDA/brettin/Aurora-Inferencing/ollama/env.sh"

echo "============================================================"
echo "Building llama.cpp with SYCL support for Intel MAX GPU 1550"
echo "============================================================"
echo ""

# Step 1: Source environment file for HTTP proxy settings
echo "[1/8] Setting up environment (HTTP proxy, cmake module)..."
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
    echo "✓ Environment file sourced: $ENV_FILE"
    echo "  HTTP_PROXY=$HTTP_PROXY"
    echo "  HTTPS_PROXY=$HTTPS_PROXY"
else
    echo "⚠ Warning: Environment file not found at $ENV_FILE"
fi
echo ""

# Step 2: Check if Intel oneAPI is available
echo "[2/8] Checking Intel oneAPI environment..."
if [ -z "$ONEAPI_ROOT" ]; then
    if [ -f "/opt/intel/oneapi/setvars.sh" ]; then
        echo "  Sourcing Intel oneAPI environment..."
        source /opt/intel/oneapi/setvars.sh
    else
        echo "⚠ WARNING: Intel oneAPI not found. Build may fail."
        echo "  Expected location: /opt/intel/oneapi/setvars.sh"
    fi
fi

if [ -n "$ONEAPI_ROOT" ]; then
    echo "✓ Intel oneAPI found: $ONEAPI_ROOT"
else
    echo "⚠ ONEAPI_ROOT not set, continuing anyway..."
fi
echo ""

# Step 3: Check and setup Vulkan SDK
echo "[3/8] Setting up Vulkan SDK..."
if [ ! -d "$VULKAN_SDK_DIR" ]; then
    echo "✗ ERROR: Vulkan SDK not found at $VULKAN_SDK_DIR"
    echo "  Please run ./setup-vulkan-sdk.sh first"
    exit 1
fi

if [ ! -f "$VULKAN_SDK_DIR/setup-env.sh" ]; then
    echo "✗ ERROR: Vulkan SDK setup script not found"
    echo "  Expected: $VULKAN_SDK_DIR/setup-env.sh"
    exit 1
fi

echo "  Sourcing Vulkan SDK environment..."
source "$VULKAN_SDK_DIR/setup-env.sh"
echo "✓ Vulkan SDK configured: $VULKAN_SDK_DIR"
echo ""

# Step 4: Clone llama.cpp if not present
echo "[4/8] Checking llama.cpp repository..."
if [ ! -d "$LLAMA_CPP_DIR" ]; then
    echo "  Cloning llama.cpp from GitHub..."
    git clone "$LLAMA_CPP_REPO" "$LLAMA_CPP_DIR"
    echo "✓ llama.cpp cloned successfully"
else
    echo "✓ llama.cpp directory already exists"
fi
echo ""

cd "$LLAMA_CPP_DIR"

# Step 5: Apply patches
echo "[5/8] Applying patches for Intel GPU compatibility..."
echo "  Current directory: $(pwd -P)"
echo "  Patches directory: ${PATCHES_DIR}"

if [ ! -d "$PATCHES_DIR" ]; then
    echo "✗ ERROR: Patches directory not found: $PATCHES_DIR"
    exit 1
fi

if [ ! -f ".patches_applied" ]; then
    echo "  Applying patch 001: Fix tokenization byte fallback..."
    patch -p1 < "$PATCHES_DIR/001-fix-tokenization-byte-fallback.patch"
    
    echo "  Applying patch 002: Link stdc++fs library..."
    patch -p1 < "$PATCHES_DIR/002-link-stdc++fs.patch"
    
    echo "  Applying patch 003: Experimental filesystem support..."
    patch -p1 < "$PATCHES_DIR/003-experimental-filesystem-support.patch"
    
    touch .patches_applied
    echo "✓ All patches applied successfully"
else
    echo "✓ Patches already applied (skipping)"
fi
echo ""

# Step 6: Clean previous build (optional)
if [ -d "build" ]; then
    echo "[6/8] Cleaning previous build directory..."
    rm -rf build
    echo "✓ Build directory cleaned"
else
    echo "[6/8] No previous build directory found"
fi
echo ""

# Step 7: Configure build with CMake
echo "[7/8] Configuring build with CMake..."
echo "  This may take a few minutes..."
cmake -B build \
    -DGGML_SYCL=ON \
    -DCMAKE_C_COMPILER=icx \
    -DCMAKE_CXX_COMPILER=icpx \
    -DLLAMA_CURL=OFF \
    -DCMAKE_BUILD_TYPE=Release

if [ $? -eq 0 ]; then
    echo "✓ CMake configuration completed successfully"
else
    echo "✗ ERROR: CMake configuration failed"
    exit 1
fi
echo ""

# Step 8: Build with CMake
echo "[8/8] Building llama.cpp..."
echo "  Using $(nproc) CPU cores for parallel build"
echo "  This will take several minutes (5-10 minutes typically)..."
echo ""

NUM_CORES=$(nproc)
cmake --build build --config Release -j $NUM_CORES

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Build completed successfully!"
else
    echo ""
    echo "✗ ERROR: Build failed"
    exit 1
fi
echo ""

# Verify the binary
echo "============================================================"
echo "Build Verification"
echo "============================================================"

if [ -f "build/bin/llama-cli" ]; then
    echo "✓ llama-cli binary created successfully"
    echo ""
    echo "Binary details:"
    ls -lh build/bin/llama-cli
    echo ""
    file build/bin/llama-cli
    echo ""
    echo "============================================================"
    echo "✓ BUILD SUCCESSFUL!"
    echo "============================================================"
    echo ""
    echo "Next steps:"
    echo "  1. Download the model (if not already done):"
    echo "     cd ../; ./download-gpt-oss-120b.sh"
    echo ""
    echo "  2. Test on a compute node with GPU:"
    echo "     qsub -I -l select=1 -l walltime=01:00:00"
    echo "     source /home/brettin/candle_aesp_CNDA/brettin/Aurora-Inferencing/ollama/env.sh"
    echo "     cd $(pwd -P)"
    echo "     ./run-inference.sh \"What is 2+2?\""
    echo ""
else
    echo "✗ ERROR: llama-cli binary not found after build"
    echo "  Expected location: build/bin/llama-cli"
    exit 1
fi

