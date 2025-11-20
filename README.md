# GPT-OSS-120B on Intel MAX GPU 1550

This repository contains everything needed to build and run OpenAI's GPT-OSS-120B model on **a single Intel Data Center GPU Max 1550** (Ponte Vecchio) using llama.cpp with SYCL backend.

## Overview

GPT-OSS-120B is a 116.8 billion parameter Mixture of Experts (MoE) model released by OpenAI. Despite its massive size (60 GB), this setup enables efficient inference on a **single Intel GPU** using memory mapping and the SYCL programming model.

**Key Features**:
- ✅ **Single GPU** operation (no multi-GPU required!)
- ✅ 100% GPU offloading (all 37 layers)
- ✅ ~22 tokens/second generation speed
- ✅ Only ~1.6 GB GPU VRAM used
- ✅ Support for 131K context length
- ✅ MoE with 128 experts, 4 active per token

## Hardware Requirements

### Minimum
- Intel Data Center GPU Max 1550 (Ponte Vecchio)
- 64 GB System RAM (for memory-mapped model)
- x86_64 Linux system

### Recommended
- Intel Data Center GPU Max 1550 with 64 GB HBM
- 128+ GB System RAM
- NVMe SSD for fast model loading

## Software Requirements

- Intel oneAPI Base Toolkit 2025.2.1 or later
- Vulkan SDK 1.4.321.1 or later
- CMake 3.18+
- GCC 7+ or Intel C++ Compiler (icx/icpx)
- Git
- ~60 GB free disk space for model


    On Aurora, it looks like oneAPI is at 2025.2.0
    On Aurora, need to module load cmake

## Quick Start

### 1. Setup Vulkan SDK

```bash
cd scripts
./setup-vulkan-sdk.sh
```


    chmod u+x 1.4.328.1/setup-env.sh 
    source 1.4.328.1/setup-env.sh


### 2. Build llama.cpp with SYCL

    inside build-llama-cpp.sh, set VULKAN_SDK_DIR="./1.4.328.1"


```bash
./build-llama-cpp.sh
```

This script will:
- Clone llama.cpp from GitHub
- Apply necessary patches for Intel GPU compatibility
- Build with SYCL backend using Intel compilers

### 3. Download GPT-OSS-120B Model

    URLs inside download-gpt-oss-120b.sh are wrong. This worked for part 2 of 2:
    https://huggingface.co/unsloth/gpt-oss-120b-GGUF/resolve/main/Q4_K_M/gpt-oss-120b-Q4_K_M-00002-of-00002.gguf


```bash
./download-gpt-oss-120b.sh
```

Downloads the Q4_K_M quantized model in 2 parts (~60 GB total):
- Part 1: ~47 GB
- Part 2: ~13 GB

**Download time**: 20-60 minutes depending on connection

### 4. Run Inference

```bash
./run-inference.sh "What is the meaning of life?"
```

**Note**: First load takes 60-90 seconds as the model initializes.

## Model Specifications

### GPT-OSS-120B Details
- **Parameters**: 116.83 billion
- **Architecture**: 36 layers
- **Experts**: 128 total, 4 active per token
- **Size**: 58.45 GB (Q4_K_M)
- **Context**: Up to 131K tokens
- **Quantization**: Q4_K_M with MXFP4 for FFN layers

### Memory Usage
- **GPU VRAM**: ~1.6 GB (active layers only)
- **Host RAM**: ~59 GB (memory-mapped model)
- **Total**: ~60 GB combined

This memory-efficient design allows a 120B model to run on a **single GPU**!

## Performance Benchmarks

**Test System**: Intel Data Center GPU Max 1550

| Metric | Value |
|--------|-------|
| Prompt Processing | 72-73 tok/s |
| Token Generation | 21-22 tok/s |
| First Token Latency | ~180 ms |
| Model Load Time | 60-90 seconds |
| GPU VRAM Usage | 1.6 GB |
| Host RAM Usage | 59 GB |
| Layers on GPU | 37/37 (100%) |

## How It Works: Single GPU for 120B Model

The key to running a 60 GB model on a single GPU:

1. **Memory Mapping**: Model stays in host RAM, streamed to GPU as needed
2. **Layer Offloading**: All 37 layers execute on GPU for performance
3. **Efficient Quantization**: Q4_K_M + MXFP4 minimizes memory footprint
4. **High Bandwidth**: Intel MAX GPU 1550's 1.6 TB/s HBM enables fast transfers

Result: **Full 120B model inference on one GPU!**

## Comparison: 120B vs 20B

| Feature | 20B | 120B |
|---------|-----|------|
| Parameters | 20.91B | 116.83B |
| Layers | 24 | 36 |
| Experts | 32 (4 active) | 128 (4 active) |
| Model Size | 11 GB | 60 GB |
| GPU VRAM | 1.5 GB | 1.6 GB |
| RAM Required | 11 GB | 60 GB |
| Prompt Speed | 118 tok/s | 73 tok/s |
| Gen Speed | 35 tok/s | 22 tok/s |
| Load Time | 1-14s | 60-90s |

## Running Inference

### Basic Usage

```bash
export ONEAPI_DEVICE_SELECTOR="level_zero:0"
./build/bin/llama-cli \
    -m ../models/gpt-oss-120b-Q4_K_M-00001-of-00002.gguf \
    -p "Your prompt here" \
    -ngl 80 \
    -c 2048 \
    -n 200
```

### Parameters
- `-m`: Path to first part of model (second part auto-detected)
- `-p`: Prompt text
- `-ngl`: Number of GPU layers (80 = all layers)
- `-c`: Context size (up to 131072)
- `-n`: Number of tokens to generate

### Tips for 120B Model

1. **Allow time for loading**: First inference takes 60-90 seconds
2. **Sufficient RAM**: Ensure 60+ GB free RAM before starting
3. **SSD recommended**: Faster model loading from NVMe storage
4. **Smaller contexts**: Use `-c 512` or `-c 1024` for faster initial responses

## Directory Structure

```
gpt-oss-120b-intel-max-gpu/
├── README.md              # This file
├── patches/               # Source code patches (same as 20B)
│   ├── 001-fix-tokenization-byte-fallback.patch
│   ├── 002-link-stdc++fs.patch
│   ├── 003-experimental-filesystem-support.patch
│   └── README.md
├── scripts/               # Build and utility scripts
│   ├── setup-vulkan-sdk.sh
│   ├── build-llama-cpp.sh
│   ├── download-gpt-oss-120b.sh  # Downloads 60 GB model
│   └── run-inference.sh
├── docs/                  # Additional documentation
│   ├── INSTALLATION.md
│   ├── TROUBLESHOOTING.md
│   └── PERFORMANCE.md
├── models/                # Model files (downloaded)
│   ├── gpt-oss-120b-Q4_K_M-00001-of-00002.gguf
│   └── gpt-oss-120b-Q4_K_M-00002-of-00002.gguf
└── test-results/          # Test outputs and benchmarks
    ├── test-2plus2.log
    └── README.md
```

## Troubleshooting

### "Out of memory" during model load

**Issue**: Insufficient system RAM

**Solution**:
- Ensure 60+ GB free RAM: `free -h`
- Close other applications
- Consider using smaller quantization (Q2_K ~40 GB)

### Slow loading (>5 minutes)

**Issue**: Slow storage device

**Solution**:
- Move model to SSD/NVMe storage
- Enable mmap: `--mmap` (default)

### Low performance (<10 tok/s)

**Issue**: Not all layers on GPU

**Solution**:
```bash
# Ensure all layers offloaded
-ngl 80  # or higher

# Verify in output:
load_tensors: offloaded 37/37 layers to GPU
```

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for more issues and solutions.

## Patches Explained

Same patches as 20B model (fully compatible):

### Tokenization Fix (001)
Fixes crashes when byte tokens missing from vocabulary by replacing `.at()` with `.find()` and falling back to unknown token.

### Filesystem Library Linking (002)
Links experimental filesystem library (`libstdc++fs.a`) required for GCC 7 compatibility.

### Experimental Filesystem Support (003)
Adds conditional compilation for `<experimental/filesystem>` on older GCC versions.

See [patches/README.md](patches/README.md) for detailed information.

## Citations

```bibtex
@misc{openai2025gptoss,
  title={GPT-OSS: Open Source Language Models},
  author={OpenAI},
  year={2025},
  url={https://openai.com/index/introducing-gpt-oss/}
}
```

## References

- [GPT-OSS Announcement](https://openai.com/index/introducing-gpt-oss/)
- [llama.cpp GitHub](https://github.com/ggml-org/llama.cpp)
- [Intel oneAPI Toolkits](https://www.intel.com/content/www/us/en/developer/tools/oneapi/toolkits.html)
- [Model on HuggingFace](https://huggingface.co/unsloth/gpt-oss-120b-GGUF)

## License

This repository: MIT License

The GPT-OSS-120B model: Apache 2.0

llama.cpp: MIT License

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## Acknowledgments

- OpenAI for releasing GPT-OSS-120B
- ggml-org for llama.cpp
- Intel for oneAPI and SYCL support
- Unsloth for GGUF conversions

---

**Single GPU. 120 Billion Parameters. Full Speed.** 🚀
