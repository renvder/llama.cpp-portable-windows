<p align="right">
  🌐 <a href="./README.md"><b>EN</b></a> |
  <b>漢</b>
</p>

# llama.cpp Windows 便攜啟動器

雙擊 `start.bat`，就能在瀏覽器裡和本地大模型對話。第一次啟動時，啟動器會**自動偵測你的硬件，下載對應的官方 [llama.cpp](https://github.com/ggml-org/llama.cpp) 版本**（CUDA 13 / CUDA 12 / Vulkan / CPU）到同一個資料夾，然後啟動伺服器。不需要另外安裝任何東西：不用 CUDA Toolkit、CMake、Git 或 winget。

> **需求：** Windows 11 x64（Windows 10 x64 理論上也可以，但尚未測試）、Windows PowerShell 5.1（系統內建）、第一次啟動時需要網路，以及至少一個 `.gguf` 模型。

## 快速開始

1. 下載本倉庫（Code -> Download ZIP），解壓到任意位置。
2. 把模型放進 `models\`（詳見 `models\README.txt`）。
3. 雙擊 **`start.bat`**。瀏覽器會自動打開，在左上角的下拉選單選擇模型即可。

## 特色

- 依顯卡與 NVIDIA 驅動版本，自動選擇合適的後端
- 所有東西都在同一個資料夾：整個複製到另一台電腦，會重新偵測硬件
- Router 模式：不用重啟，直接在網頁切換模型
- 依顯存自動設定上下文長度、KV 快取與 GPU 卸載等合理的預設值
- 可透過 `presets.ini` 做單個模型的進階設定（範本：`presets.example.ini`）

## 文檔

- 安裝指南: [漢](docs/setup_tw.md) | [EN](docs/setup.md)
- 博客文章: [漢](https://renvder.com/blog/llama-cpp-windows-one-click-setup/) | [EN](https://renvder.com/en/blog/llama-cpp-windows-one-click-setup/)

## 注意事項

- 伺服器只監聽 `127.0.0.1`。請勿把 llama.cpp 的 router 模式暴露給不受信任的網路。
- 啟動器會從官方 [ggml-org/llama.cpp releases](https://github.com/ggml-org/llama.cpp/releases) 下載執行檔，並在 GitHub 提供 SHA-256 時進行校驗。本倉庫不內含 llama.cpp。
- 本倉庫不含任何模型。使用模型時請遵守各模型自己的授權條款。
- 本專案與 llama.cpp 專案沒有隸屬關係。

## 授權

[MIT](LICENSE)
