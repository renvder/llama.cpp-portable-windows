<p align="right">
  🌐 <b>EN</b> |
  <a href="./setup_tw.md"><b>漢</b></a>
</p>

# llama.cpp Windows One-Click Setup Guide

Run local LLMs on any Windows 11 x64 PC with just a **launcher and your models**. **On the first run, the launcher detects your hardware, picks the right official llama.cpp Windows build, installs it, and starts the server.** After that, it reuses the local runtime.

> **Works with:** Windows 11 x64 (Windows 10 x64 should also work but is untested), Windows PowerShell 5.1+
> **You need:** `start.bat`, `llama-oneclick.ps1`, and at least one `.gguf` model
> **You don't need:** CUDA Toolkit, CMake, Git, winget, or a separate llama.cpp install

---

## Folder Structure

Put everything in the **same folder as the launcher**. The location doesn't matter:

```text
<launcher folder>\
├─ start.bat                 ← Double-click to start
├─ llama-oneclick.ps1        ← Main launcher
├─ presets.ini               ← Optional: your own per-model settings (not committed to Git)
├─ presets.example.ini       ← Template: copy to presets.ini and edit
├─ runtime\                  ← Created automatically
│  ├─ cuda13\
│  ├─ cuda12\
│  ├─ vulkan\
│  └─ cpu\
└─ models\
   └─ MyModel\               ← Model folder
      ├─ MyModel-Q4_K_M.gguf
      └─ mmproj-F16.gguf     ← Optional: multimodal projector
```

You don't need to create `runtime\` yourself. On the first run, the launcher creates it and installs a llama.cpp build if none is available.

You can copy the whole folder to another Windows PC. The launcher rechecks the hardware and installs a different backend if needed.

---

## Quick Setup

### 1. Put the files in one folder

Keep `start.bat`, `llama-oneclick.ps1`, and `presets.ini` (if you use it) together.

Put your models in `models\`. See "Adding Models" below.

### 2. First run: automatic llama.cpp install

**You no longer need to create `install-llama.ps1`.**

Just double-click:

```text
start.bat
```

The launcher will:

1. Check that Windows is x64.
2. Detect NVIDIA, AMD, or Intel GPUs.
3. Read the NVIDIA driver version, if applicable.
4. Choose CUDA 13, CUDA 12, Vulkan, or CPU.
5. Look for a suitable local llama.cpp runtime.
6. If it finds none, search the official `ggml-org/llama.cpp` GitHub Releases for the newest Windows x64 build that fits.
7. Download the matching CUDA runtime DLLs for CUDA builds.
8. Install everything under the local `runtime\` folder.
9. Verify `llama-server.exe`.
10. Start the server.

The official project currently publishes Windows x64 builds for CPU, CUDA 12, CUDA 13, Vulkan, and other backends. CUDA builds ship with their runtime DLLs as separate assets. The launcher checks the actual release assets rather than assuming the latest stable tag includes every Windows binary.

### Hardware selection

| Detected hardware | Backend | Notes |
|---|---|---|
| NVIDIA, driver R580 or newer | CUDA 13 | Preferred CUDA backend |
| NVIDIA, driver R525–R579 | CUDA 12 | Uses CUDA 12 |
| NVIDIA, driver below R525 | Vulkan | Driver too old for CUDA |
| AMD Radeon | Vulkan | Windows GPU backend |
| Intel Arc | Vulkan | Windows GPU backend |
| No supported GPU | CPU | CPU backend |

On an NVIDIA system the console shows something like:

```text
GPU          : <your GPU>
VRAM         : <size> GB
NVIDIA driver: <driver version>
Selected     : NVIDIA CUDA 13
```

### What happens on later runs?

If this file already exists:

```text
runtime\<selected backend>\llama-server.exe
```

the launcher uses it and skips the download.

The flow looks like this:

```text
No llama.cpp
    ↓
Detect hardware
    ↓
Choose backend
    ↓
Download
    ↓
Install
    ↓
Start

Suitable llama.cpp already installed
    ↓
Start directly
```

---

### 3. Adding Models

llama.cpp router mode scans a local model directory using `--models-dir`. The official server supports single-file GGUF models, multi-shard GGUF models, and multimodal models with `mmproj` files in a subfolder.

- **Single-file model:** Put the `.gguf` directly in `models\`.
- **Multimodal model:** Put the model and `mmproj*.gguf` together in `models\<model name>\`.
- **Multi-shard model:** Keep all the `-00001-of-xxxxx.gguf`, `-00002-of-xxxxx.gguf`, etc. files in one model folder.
- The projector filename must start with `mmproj`.
- Don't nest models in extra subfolders, or the router may not recognize them.

Example:

```text
models\
├─ Qwen3-14B-Q4_K_M.gguf
│
├─ Gemma-3-12B\
│  ├─ Gemma-3-12B-Q4_K_M.gguf
│  └─ mmproj-F16.gguf
│
└─ Kimi-K2\
   ├─ Kimi-K2-00001-of-00006.gguf
   ├─ Kimi-K2-00002-of-00006.gguf
   ├─ Kimi-K2-00003-of-00006.gguf
   ├─ Kimi-K2-00004-of-00006.gguf
   ├─ Kimi-K2-00005-of-00006.gguf
   └─ Kimi-K2-00006-of-00006.gguf
```

A model doesn't have to fit entirely in VRAM. llama.cpp can offload part of it to system RAM, but that usually slows things down.

---

### 4. Optional: `presets.ini`

The launcher runs fine without `presets.ini`.

Use it to set per-model context size, sampling, or other llama.cpp options. Keep it next to `start.bat`.

A template is included: copy `presets.example.ini` to `presets.ini` and edit it. Your own `presets.ini` is listed in `.gitignore`, so it is never committed.

The launcher uses:

```text
models-dir    → models\
models-preset → presets.ini
```

llama.cpp presets use INI syntax. Command-line options override model-specific settings, which override the global `[*]` section.

Use **relative paths** to keep the folder portable:

```ini
version = 1

[*]
ctx-size = 0

[MyModel]
model = ./models/MyModel/MyModel-Q4_K_M.gguf
mmproj = ./models/MyModel/mmproj-F16.gguf
ctx-size = 32768
temp = 0.7
top-p = 0.8
top-k = 20
min-p = 0
presence-penalty = 1.0
```

Notes:

- `[MyModel]` should match the model name the llama.cpp router shows.
- Every model section should have a `model =` line (plus `mmproj =` for vision models). Without it, the model may fail to load or may not show up in the Web UI.
- `model` and `mmproj` can use relative paths. They are resolved from the launcher folder, which the launcher sets as its working directory.
- Use forward slashes (`/`) in paths to avoid escape-character problems.
- `ctx-size = 0` leaves the choice to llama.cpp.
- With 16 GB or more of VRAM, the launcher usually doesn't override the context size from the command line. It leaves that to `presets.ini` and `--fit`.
- With less than 16 GB of VRAM or RAM, the launcher uses a more conservative context size so it doesn't fill up memory right away.

---

### 5. Start llama.cpp

Double-click:

```text
start.bat
```

The launcher tries this port first:

```text
8080
```

If 8080 is in use or reserved by Windows, it tries these in order:

```text
8090
8081
8188
11434
18080
```

Your browser opens automatically to:

```text
http://127.0.0.1:<actual port>
```

Pick a model from the dropdown in the upper-left corner of the Web UI.

Router mode loads and unloads models on the fly, so you usually don't need to restart the server to switch models.

---

## What the Launcher Does

- Detects your GPU, VRAM, RAM, and CPU core count.
- Reads the NVIDIA driver version and picks CUDA 13 or CUDA 12.
- Uses Vulkan for AMD and Intel Arc.
- Falls back to CPU when no supported GPU is available.
- On the first run, finds the matching Windows x64 build in the official `ggml-org/llama.cpp` Releases.
- Downloads the matching CUDA runtime DLLs for CUDA builds.
- Verifies the SHA-256 of each download when GitHub provides it.
- Installs all runtime files under the local `runtime\` folder.
- Doesn't use winget or require the CUDA Toolkit.
- Reuses an existing suitable runtime instead of downloading it again.
- Rechecks the hardware when you move to another PC.
- Scans `models\` automatically.
- Uses router mode with `--models-dir` and `--models-preset`.
- Picks an available port automatically.
- Adjusts context, KV cache, and batch settings to match your VRAM tier.
- Prefers llama.cpp's `--fit` for GPU memory allocation.
- Enables Flash Attention when supported.
- Uses q8_0 KV-cache quantization when appropriate.
- Uses `--jinja` to apply the model's built-in chat template.
- Turns thinking off by default. To turn it on, change `$THINKING = "off"` to `"on"` at the top of the script.
- Sets the default maximum generation length to `$MAX_PREDICT = 16384`.
- Opens the Web UI automatically.

---

## Adjusting Context Length

A larger context lets the model handle more text at once, but the KV cache uses more VRAM.

### Method 1: `presets.ini`

For example:

```ini
[MyModel]
model = ./models/MyModel/MyModel-Q4_K_M.gguf
ctx-size = 32768
```

Try these values in order:

```text
16384
32768
49152
65536
```

Restart the launcher after each change.

### Method 2: Check NVIDIA VRAM usage

```powershell
nvidia-smi --query-gpu=memory.used,memory.total --format=csv
```

For non-NVIDIA GPUs, use:

```text
Task Manager → Performance → GPU
```

If a larger context pushes VRAM close to full or noticeably slows generation, go back to the previous value.

With 16 GB or more of VRAM the launcher does not force a context size: it comes from `presets.ini` or, if unset, from llama.cpp's `--fit`. The practical limit depends on model size, KV cache, other GPU workloads, and `--fit`.

---

## Common Issues

| Symptom | Fix |
|---|---|
| llama.cpp starts downloading on the first run | Normal. The launcher is installing the official Windows build for your hardware |
| `Selected : NVIDIA CUDA 13` | Normal. Your NVIDIA driver meets the CUDA 13 requirement |
| `No suitable local llama.cpp runtime found.` | Normal on the first run. The launcher will download the runtime it needs |
| No Windows x64 build found | The launcher checks the latest 100 official releases. If none has a matching build, it stops with an error |
| No models in the Web UI | Check the `models\` layout and make sure the GGUF and mmproj files are in the right folders |
| A model shows up but won't load | Check the `presets.ini` section name and the `model`/`mmproj` paths. To test without presets, temporarily rename it to `presets.ini.bak` |
| `Executable` points to `runtime\cuda13\llama-server.exe` | Correct for NVIDIA CUDA 13 |
| `Executable` points to `runtime\vulkan\llama-server.exe` | Correct for Vulkan mode |
| Generation is slow | The model may be spilling into system RAM. Try a smaller quantization or a lower context size |
| Port 8080 won't work | The launcher picks another port. Use the URL shown in the console |
| You want to update llama.cpp | Delete or move the matching `runtime\<backend>\` folder, then run `start.bat` again |
| No internet / GitHub is blocked on the first run | Download the main zip (plus the `cudart` zip for CUDA builds) manually from the llama.cpp Releases page and extract both into `runtime\<backend>\` (e.g. `runtime\cuda13\`). The launcher will use them |
| Moving to a new PC | Copy the whole folder. On the first run, the launcher detects the new hardware and installs the right backend |

---

## Portable Use

The idea is to keep these together as one portable folder:

```text
start.bat
llama-oneclick.ps1
presets.ini
models\
runtime\
```

For example, you can move:

```text
C:\Tools\llama\
```

to:

```text
D:\AI\llama\
```

or copy it to another Windows 11 PC.

If `presets.ini` uses relative paths, you don't need to reorganize your models or rewrite any paths.

The launcher uses its own folder as the working directory and keeps the runtime under `runtime\`.

If the new PC has a different GPU, NVIDIA driver, or backend, the launcher detects that and installs the right runtime automatically.

That's the main advantage of this setup: **the llama.cpp runtime travels with the folder instead of being tied to a system-wide install.**
