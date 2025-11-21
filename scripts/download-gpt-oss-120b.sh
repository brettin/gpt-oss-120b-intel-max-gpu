#!/bin/bash
# Download GPT-OSS-120B model from HuggingFace

set -e

MODEL_NAME="gpt-oss-120b-Q4_K_M"
MODEL_URL_PART1="https://huggingface.co/unsloth/gpt-oss-120b-GGUF/resolve/main/Q4_K_M/gpt-oss-120b-Q4_K_M-00001-of-00002.gguf"
MODEL_URL_PART2="https://huggingface.co/unsloth/gpt-oss-120b-GGUF/resolve/main/Q4_K_M/gpt-oss-120b-Q4_K_M-00002-of-00002.gguf"
MODELS_DIR="../models"

echo "=== Downloading GPT-OSS-120B model ==="
echo "Note: This model is split into 2 files (total ~60 GB)"
echo ""

# Create models directory
mkdir -p "$MODELS_DIR"
cd "$MODELS_DIR"

# Check if files already exist
if [ -f "${MODEL_NAME}-00001-of-00002.gguf" ] && [ -f "${MODEL_NAME}-00002-of-00002.gguf" ]; then
    echo "Model files already exist:"
    ls -lh ${MODEL_NAME}*.gguf
    exit 0
fi

# Download part 1
if [ ! -f "${MODEL_NAME}-00001-of-00002.gguf" ]; then
    echo "Downloading part 1 of 2 (~47 GB)..."
    wget --show-progress -O "${MODEL_NAME}-00001-of-00002.gguf" "$MODEL_URL_PART1"
else
    echo "Part 1 already downloaded"
fi

# Download part 2
if [ ! -f "${MODEL_NAME}-00002-of-00002.gguf" ]; then
    echo "Downloading part 2 of 2 (~13 GB)..."
    wget --show-progress -O "${MODEL_NAME}-00002-of-00002.gguf" "$MODEL_URL_PART2"
else
    echo "Part 2 already downloaded"
fi

echo ""
echo "=== Download complete! ==="
echo "Model location: $(pwd)"
ls -lh ${MODEL_NAME}*.gguf
echo ""
echo "Total size: $(du -sh ${MODEL_NAME}*.gguf | awk '{sum+=$1} END {print sum}') GB"
