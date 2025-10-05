# Patches for llama.cpp SYCL Support on Intel MAX GPU 1550

This directory contains patches required to build llama.cpp with SYCL support for Intel Data Center GPU Max 1550 (Ponte Vecchio).

## Required Patches

### 001-fix-tokenization-byte-fallback.patch
**Purpose**: Fix tokenization crashes when byte tokens are missing from vocabulary

**Issue**: The original code used `.at()` method which throws `std::out_of_range` exception when byte tokens (like `<0x0A>`) don't exist in the model's vocabulary. This caused crashes with models like TinyLlama and GPT-OSS-20B.

**Solution**: Replace `.at()` calls with `.find()` and check if tokens exist before accessing them. Falls back to `special_unk_id` when byte tokens are not found.

**Files Modified**: `src/llama-vocab.cpp`

---

### 002-link-stdc++fs.patch
**Purpose**: Link experimental filesystem library for GCC 7 compatibility

**Issue**: Intel oneAPI compilers use older GCC 7 libstdc++ which doesn't have `<filesystem>` header, only `<experimental/filesystem>`. The experimental filesystem requires explicit linking with `libstdc++fs.a`.

**Solution**: Add conditional linking of `/usr/lib64/gcc/x86_64-suse-linux/7/libstdc++fs.a` to the ggml library on Linux systems.

**Files Modified**: `ggml/src/CMakeLists.txt`

---

### 003-experimental-filesystem-support.patch
**Purpose**: Add fallback to experimental filesystem for older GCC versions

**Issue**: GCC 7 only provides `<experimental/filesystem>` instead of the standard `<filesystem>` header.

**Solution**: Use `__has_include` preprocessor directive to detect filesystem header availability and create a `fs` namespace alias that works with both standard and experimental filesystem.

**Files Modified**:
- `ggml/src/ggml-backend-reg.cpp`
- `common/common.cpp`
- `common/arg.cpp`
- `tools/run/run.cpp`
- `tools/rpc/rpc-server.cpp`
- `ggml/src/ggml-rpc/ggml-rpc.cpp`
- `examples/model-conversion/logits.cpp`

**Changes**:
```cpp
#if __has_include(<filesystem>)
#include <filesystem>
namespace fs = std::filesystem;
#else
#include <experimental/filesystem>
namespace fs = std::experimental::filesystem;
#endif
```

Also updated `entry.is_regular_file()` to `fs::is_regular_file(entry.status())` for experimental filesystem compatibility.

---

## Applying Patches

To apply these patches to a fresh llama.cpp clone:

```bash
cd llama.cpp
patch -p1 < ../patches/001-fix-tokenization-byte-fallback.patch
patch -p1 < ../patches/002-link-stdc++fs.patch
patch -p1 < ../patches/003-experimental-filesystem-support.patch
```

## Testing

After applying patches, verify the build works:
```bash
source /opt/intel/oneapi/setvars.sh
cmake -B build -DGGML_SYCL=ON -DCMAKE_C_COMPILER=icx -DCMAKE_CXX_COMPILER=icpx -DLLAMA_CURL=OFF
cmake --build build --config Release -j $(nproc)
```

Test tokenization and inference:
```bash
export ONEAPI_DEVICE_SELECTOR="level_zero:0"
./build/bin/llama-cli -m model.gguf -p "Hello" -ngl 25
```
