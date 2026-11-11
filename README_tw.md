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
- 可透過 `presets.ini` 做單個模型的進階設定（第一次啟動時自動生成）

## 更新

雙擊 **`update.bat`**，把已安裝的 runtime 更新到最新官方版。它會比對 `runtime\<backend>\runtime-info.json` 裡的已安裝版本和線上最新版，先下載、校驗完再替換，更新中途失敗也不會讓你沒得用。已經是最新版就不下載。下載用 Windows 11 自帶的 `curl.exe`，每個文件 16 個並行 Range 請求（有 CUDA 包時共 32 個連接），並顯示進度條（MB、百分比、速度、剩餘時間）；沒有 `curl.exe` 時自動退回單線程下載。雙擊 `start.bat` 啟動時不會檢查更新，斷網也能正常啟動。注意：`update.bat` 不在源碼裡，第一次啟動時由 `start.bat` 自動生成到根目錄。

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
## presets.ini（自動生成）

如果 `start.bat` 旁邊沒有 `presets.ini`，啟動器會生成一次——第一次安裝、更新後、或下次啟動時——依據檢測到的硬件（顯卡、顯存、內存、虛擬內存、CUDA 後端）和 `models\` 裡的模型。每個模型的 `ctx-size` 是固定數字，由 llama.cpp 自帶的 `llama-fit-params` 工具針對這張顯卡和這個模型量出來的，mmproj 文件大小會加進預留量（自動適配不計 mmproj 顯存）。採樣參數按模型家族的官方表填（Qwen3 非思考模式：temp 0.7、top-p 0.8、top-k 20、min-p 0、presence-penalty 1.5），沒見過的家族不填採樣行。生成後文件永遠不會被覆蓋，可以隨便改，刪掉就會重新生成。平時啟動不會重新計算。
## v1.3.1

修復：自動生成的 `presets.ini` 以前總是退回顯存檔位值（16GB 顯存是 32768），而不是量出來的值。原因是 `llama-fit-params` 會把日誌寫到 stderr，在腳本的 `$ErrorActionPreference = "Stop"` 下會中斷調用。現在改為在 `Continue` 下運行，所以會用上量出來的 `ctx-size`。
