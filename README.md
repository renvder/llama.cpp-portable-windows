<p align="right">
  🌐 <b>EN</b> |
  <a href="./README_tw.md"><b>漢</b></a>
</p>

# llama.cpp Portable Launcher for Windows

Double-click `start.bat` and chat with a local LLM in your browser. On the first run the launcher **detects your hardware, downloads the matching official [llama.cpp](https://github.com/ggml-org/llama.cpp) build** (CUDA 13 / CUDA 12 / Vulkan / CPU) into the same folder, and starts the server. Nothing to install: no CUDA Toolkit, CMake, Git or winget.

> **Requirements:** Windows 11 x64 (Windows 10 x64 should also work but is untested), Windows PowerShell 5.1 (built in), an internet connection for the first run, and at least one `.gguf` model.

## Quick start

1. Download this repository (Code -> Download ZIP) and unzip it anywhere.
2. Put your model in `models\` (see `models\README.txt`).
3. Double-click **`start.bat`**. Your browser opens automatically; pick the model from the drop-down at the top-left.

## What you get

- Automatic backend selection from your GPU and NVIDIA driver version
- Everything stays in one folder: copy it to another PC and it re-detects the hardware
- Router mode: switch models from the Web UI without restarting
- Sensible defaults for context, KV cache and GPU offload based on your VRAM
- Optional per-model settings via `presets.ini` (template: `presets.example.ini`)

## Updating

Double-click **`update.bat`** to update the installed runtime to the latest official release. It compares the installed release in `runtime\<backend>\runtime-info.json` with the newest release for your hardware, downloads and verifies it first, then swaps it in — a failed download never leaves you with no runtime. If it is already up to date, nothing is downloaded. Downloads use `curl.exe` (built into Windows 11) with 16 parallel Range requests per file (32 connections in total when a CUDA runtime is also downloaded), with a progress bar showing MB, percent, speed and ETA; if `curl.exe` is missing, it falls back to a single-threaded download. Launching with `start.bat` never checks for updates, so it also works offline. Note: `update.bat` is not shipped in the source tree — `start.bat` generates it in the package root on first launch.

## Documentation

- Setup Guide: [EN](docs/setup.md) | [漢](docs/setup_tw.md)
- Blog Post: [EN](https://renvder.com/en/blog/llama-cpp-windows-one-click-setup/) | [漢](https://renvder.com/blog/llama-cpp-windows-one-click-setup/)

## Notes

- The server listens on `127.0.0.1` only. Do not expose llama.cpp router mode to untrusted networks.
- The launcher downloads binaries from the official [ggml-org/llama.cpp releases](https://github.com/ggml-org/llama.cpp/releases) and checks their SHA-256 when GitHub provides it. llama.cpp is not bundled in this repository.
- Models are not included. Follow each model's own license.
- This project is not affiliated with the llama.cpp project.

## License

[MIT](LICENSE)
## presets.ini (auto-generated)

If `presets.ini` does not exist next to `start.bat`, the launcher generates it once — at first install, after an update, or on the next launch — from the detected hardware (GPU, VRAM, RAM, pagefile, CUDA backend) and the models in `models\`. Per-model `ctx-size` is a fixed number measured by llama.cpp's own `llama-fit-params` tool for that GPU and model, with the `mmproj` file size added to the fit reserve (auto-fit does not count `mmproj` VRAM). Sampling comes from the model family's official table (Qwen3 non-thinking: temp 0.7, top-p 0.8, top-k 20, min-p 0, presence-penalty 1.5); unknown families get no sampling lines. The file is never overwritten afterwards — edit it freely, or delete it to regenerate. Launching never recalculates it.
