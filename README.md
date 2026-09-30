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

## Documentation

- [EN](docs/setup.md) | [漢](docs/setup_tw.md)
- Blog: [EN](https://renvder.com/en/blog/llama-cpp-windows-one-click-setup/) | [漢](https://renvder.com/blog/llama-cpp-windows-one-click-setup/)

## Notes

- The server listens on `127.0.0.1` only. Do not expose llama.cpp router mode to untrusted networks.
- The launcher downloads binaries from the official [ggml-org/llama.cpp releases](https://github.com/ggml-org/llama.cpp/releases) and checks their SHA-256 when GitHub provides it. llama.cpp is not bundled in this repository.
- Models are not included. Follow each model's own license.
- This project is not affiliated with the llama.cpp project.

## License

[MIT](LICENSE)
