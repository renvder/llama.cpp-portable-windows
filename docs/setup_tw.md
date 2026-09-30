<p align="right">
  🌐 <b></b>
  <a href="./setup.md"><b>EN</b></a> | 
  <b>漢</b></a>
</p>

# llama.cpp Windows 一鍵安裝與使用指南

用「啟動腳本 + 模型」在任何 Windows 11 x64 電腦上跑本地大模型。**第一次啟動時，腳本會自動檢測硬件、選擇合適的官方 llama.cpp Windows 版本並安裝；之後直接使用本機已安裝的版本。**

> 適用：Windows 11 x64（Windows 10 x64 理論上也可以，但尚未測試）、Windows PowerShell 5.1 及以上。
> 需要：`start.bat`、`llama-oneclick.ps1` 和至少一個 `.gguf` 模型文件。
> 不需要：手動安裝 CUDA Toolkit、CMake、Git 或 llama.cpp。腳本會直接下載官方 Windows binary。

---

## 文件夾結構

所有東西都放在**啟動腳本所在的文件夾**，位置可以任意：

```text
<啟動腳本文件夾>\
├─ start.bat                 ← 雙擊啟動
├─ llama-oneclick.ps1        ← 主啟動腳本
├─ presets.ini               ← 可選：你自己的單個模型配置（不會提交到 Git）
├─ presets.example.ini       ← 範本：複製為 presets.ini 後修改
├─ runtime\                  ← 自動生成：llama.cpp 運行環境
│  ├─ cuda13\
│  ├─ cuda12\
│  ├─ vulkan\
│  └─ cpu\
└─ models\
   └─ MyModel\               ← 模型文件夾
      ├─ MyModel-Q4_K_M.gguf
      └─ mmproj-F16.gguf     ← 可選：多模態模型投影文件
```

`runtime\` 不需要手動創建。第一次運行 `start.bat` 時，如果找不到適合當前硬件的 llama.cpp，腳本會自動創建並下載。

整個文件夾可以直接拷貝到另一台 Windows 電腦。啟動時腳本會重新檢測硬件；如果當前電腦需要不同的 backend，會自動安裝對應版本。

---

## 快速安裝

### 1. 放好文件

把 `start.bat`、`llama-oneclick.ps1` 和 `presets.ini`（如果需要）放在同一個文件夾。

模型放進 `models\`，規則見下方「放模型」。

### 2. 第一次啟動：自動安裝 llama.cpp

**不需要再創建 `install-llama.ps1`。**

直接雙擊：

```text
start.bat
```

腳本會自動：

1. 檢查 Windows 是否為 x64。
2. 檢測 NVIDIA / AMD / Intel GPU。
3. 讀取 NVIDIA 驅動版本。
4. 判斷應使用 CUDA 13、CUDA 12、Vulkan 還是 CPU。
5. 檢查當前文件夾是否已有合適的 llama.cpp。
6. 如果沒有，從官方 `ggml-org/llama.cpp` GitHub Releases 搜索最新的可用 Windows x64 build。
7. NVIDIA CUDA 版本會同時下載對應的 CUDA runtime DLL。
8. 將文件安裝到當前文件夾的 `runtime\`。
9. 驗證 `llama-server.exe`。
10. 繼續啟動 llama.cpp。

官方 llama.cpp 目前提供 Windows x64 的 CPU、CUDA 12、CUDA 13、Vulkan 等構建；CUDA 13 的 Windows x64 binary 與對應 DLL 是分開的 release asset。腳本會根據實際存在的官方 asset 選擇可用版本，而不是假設最新 stable release 一定包含所有 Windows binary。

### 硬件與 backend 判斷

| 檢測結果 | 自動選擇 | 說明 |
|---|---|---|
| NVIDIA，驅動 R580 或更新 | CUDA 13 | 優先使用 CUDA 13 |
| NVIDIA，驅動 R525～R579 | CUDA 12 | 使用 CUDA 12 |
| NVIDIA，驅動低於 R525 | Vulkan | 避免使用不兼容的 CUDA 版本 |
| AMD Radeon | Vulkan | Windows GPU backend |
| Intel Arc | Vulkan | Windows GPU backend |
| 沒有支持的 GPU | CPU | CPU backend |

NVIDIA 顯卡的電腦上，畫面會類似：

```text
GPU          : <你的顯卡>
VRAM         : <容量> GB
NVIDIA driver: <驅動版本>
Selected     : NVIDIA CUDA 13
```

### 已經安裝過怎麼辦？

第二次運行 `start.bat` 時，如果：

```text
runtime\<當前需要的 backend>\llama-server.exe
```

已經存在，就不會重新下載，直接使用本機版本。

因此它的工作方式就是：

```text
沒有 llama.cpp
    ↓
自動檢測硬件
    ↓
自動選擇 backend
    ↓
自動下載
    ↓
自動安裝
    ↓
啟動

已經有合適的 llama.cpp
    ↓
直接啟動
```

---

### 3. 放模型

llama.cpp router 使用 `--models-dir` 掃描本地模型目錄。官方文檔支持單個 GGUF、分片 GGUF，以及多模態模型的 `mmproj` 子文件夾結構。

- **單文件模型**：`.gguf` 可以直接放在 `models\`。
- **多模態模型**：放進 `models\<模型名>\`，模型 GGUF 和 `mmproj*.gguf` 放在同一層。
- **分片模型**：所有 `-00001-of-xxxxx.gguf`、`-00002-of-xxxxx.gguf` 等文件放在同一個模型子文件夾。
- `mmproj` 文件名必須以 `mmproj` 開頭。
- 不要再多套一層文件夾，否則 router 可能無法按預期識別模型。

例如：

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

模型大小並不是絕對的顯存上限。llama.cpp 可以將部分內容放到系統內存，但通常會降低速度。

---

### 4. （可選）`presets.ini`：單個模型的配置

不創建 `presets.ini` 也可以正常啟動。

如果需要為不同模型指定上下文長度、採樣參數或其他 llama.cpp 參數，可以在啟動腳本旁放置 `presets.ini`。

倉庫附有範本：把 `presets.example.ini` 複製為 `presets.ini` 再修改即可。你自己的 `presets.ini` 已列入 `.gitignore`，不會被提交。

目前腳本會使用：

```text
models-dir   → models\
models-preset → presets.ini
```

官方 llama.cpp 的 preset 是 INI 格式。命令行參數優先於模型專用配置，模型專用配置又優先於 `[*]` 全局配置。

推薦使用**相對路徑**，這樣整個文件夾換電腦或換磁盤也不用修改：

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

注意：

- `[MyModel]` 的名稱應與 llama.cpp router 顯示的模型名稱一致。
- 每個模型區段都應該寫 `model =` 這一行（看圖模型再加 `mmproj =`）；沒有的話，模型可能無法載入，或不會出現在網頁的下拉選單。
- `model` 和 `mmproj` 可以使用相對路徑，以啟動腳本所在的文件夾為基準（腳本會把它設為工作目錄）。
- 路徑使用 `/` 更不容易出現轉義字符問題。
- `ctx-size = 0` 表示交給 llama.cpp 自行決定。
- 對於 16 GB 及以上顯存，腳本通常不會從命令行強制覆蓋 `presets.ini` 的 ctx，而是讓 preset 和 `--fit` 決定。
- 對於顯存或內存低於 16 GB 的電腦，腳本會使用較保守的 ctx，以避免一開始就占滿內存。

---

### 5. 啟動

直接雙擊：

```text
start.bat
```

啟動後，腳本會自動選擇可用端口。默認優先使用：

```text
8080
```

如果 8080 被占用或被 Windows 系統保留，會自動嘗試：

```text
8090
8081
8188
11434
18080
```

瀏覽器會自動打開：

```text
http://127.0.0.1:<實際使用的端口>
```

在 Web UI 左上角的模型菜單中選擇模型。

llama.cpp router 可以在同一個 server 中動態加載和卸載不同模型，因此切換模型通常不需要重啟 server。

---

## 啟動腳本做了什麼

- 自動檢測 GPU、VRAM、內存和 CPU 核心數。
- NVIDIA 會讀取實際 driver version，決定 CUDA 13 / CUDA 12。
- AMD / Intel Arc 自動使用 Vulkan。
- 沒有支持的 GPU 時使用 CPU。
- 第一次運行時，自動從官方 `ggml-org/llama.cpp` Releases 查找對應的 Windows x64 build。
- CUDA 13 / CUDA 12 會同時下載對應的 CUDA runtime DLL。
- 如果 GitHub 提供 SHA-256，會校驗每個下載檔案。
- 所有 runtime 都安裝在啟動腳本旁的 `runtime\`，不使用 winget，也不需要安裝 CUDA Toolkit。
- 已經存在適合當前硬件的 runtime 時直接使用，不重複下載。
- 如果換到硬件不同的另一台電腦，會重新判斷當前需要的 backend。
- 自動掃描 `models\`。
- 使用 llama.cpp router 的 `--models-dir` / `--models-preset`。
- 自動選擇端口。
- 自動根據 VRAM 檔位設置更合適的 context、KV cache 和 batch 參數。
- 優先使用 llama.cpp 的 `--fit` 自動處理 GPU 內存分配。
- 啟用 Flash Attention（當前版本支持時）。
- 根據硬件情況使用 KV cache q8_0。
- 使用 `--jinja` 套用模型內置的 chat template。
- Thinking 默認關閉；腳本開頭的 `$THINKING = "off"` 可以改成 `"on"`。
- 最大生成量默認為 `$MAX_PREDICT = 16384`。
- Web UI 啟動後會自動打開瀏覽器。

---

## 上下文長度（ctx）怎麼調

ctx 越大，一次能處理的內容越多，但 KV cache 也會占用更多內存。

### 方法 1：使用 `presets.ini`

例如：

```ini
[MyModel]
model = ./models/MyModel/MyModel-Q4_K_M.gguf
ctx-size = 32768
```

可以依次嘗試：

```text
16384
32768
49152
65536
```

然後重新啟動。

### 方法 2：觀察 NVIDIA 顯存

```powershell
nvidia-smi --query-gpu=memory.used,memory.total --format=csv
```

非 NVIDIA GPU 可以使用 Windows 任務管理器：

```text
性能 → GPU
```

如果 ctx 增大後顯存接近占滿，或者生成速度明顯下降，可以回退到上一個值。

對於 16 GB 及以上顯存，腳本不會強制指定上下文長度：由 `presets.ini` 決定，沒有設定時交給 llama.cpp 的 `--fit`。實際可用上下文仍會受到模型大小、KV cache、其他占用 GPU 的程序和 `--fit` 的影響。

---

## 常見問題

| 現象 | 處理 |
|---|---|
| 第一次啟動開始下載 llama.cpp | 正常。腳本正在自動安裝適合當前硬件的官方 Windows build |
| 顯示 `Selected : NVIDIA CUDA 13` | 正常，說明當前 NVIDIA driver 滿足 CUDA 13 的選擇條件 |
| 顯示 `No suitable local llama.cpp runtime found.` | 正常，說明當前文件夾還沒有適合當前硬件的 runtime，接下來會自動下載 |
| 顯示沒有 Windows x64 build | 腳本會在官方 release 列表中查找較新的可用 build；如果 100 個 release 都沒有符合條件的版本，才會停止並報錯 |
| 網頁下拉菜單裡沒有模型 | 檢查模型是否放在 `models\` 或正確的模型子文件夾，並確認 GGUF / mmproj 結構 |
| 有模型但加載失敗 | 先檢查 `presets.ini` 的 `[區段名稱]`、`model` 和 `mmproj` 路徑；也可以臨時把 `presets.ini` 改名為 `presets.ini.bak` 進行測試 |
| `Executable` 指向 `runtime\cuda13\llama-server.exe` | NVIDIA CUDA 13 模式，正常 |
| `Executable` 指向 `runtime\vulkan\llama-server.exe` | Vulkan 模式，正常 |
| 速度很慢 | 模型太大或部分內容落到內存；可換更小的量化模型或降低 ctx |
| 8080 無法使用 | 腳本會自動選擇其他可用端口，直接使用界面顯示的 URL |
| 更新 llama.cpp | 刪除或移走對應的 `runtime\<backend>\` 後重新運行 `start.bat`，腳本會重新下載官方 build |
| 第一次運行時沒有網絡 / 無法訪問 GitHub | 從 llama.cpp Releases 頁面手動下載主程序 zip（CUDA 版再加 `cudart` zip），全部解壓到 `runtime\<backend>\`（例如 `runtime\cuda13\`），腳本會直接使用 |
| 換新電腦 | 直接拷貝整個文件夾；第一次在新電腦上運行時會重新檢測硬件並選擇對應 backend |

---

## 便攜使用

這套啟動器的目的，就是讓：

```text
start.bat
llama-oneclick.ps1
presets.ini
models\
runtime\
```

成為一個可以整體移動的文件夾。

例如原本在：

```text
C:\Tools\llama\
```

可以直接移動到：

```text
D:\AI\llama\
```

甚至換到另一台 Windows 11 電腦。

模型和配置不需要重新整理。啟動器以自己所在的文件夾作為工作目錄，使用 `models\` 和 `runtime\` 的相對位置。

如果新電腦的 GPU、NVIDIA driver 或 backend 不同，腳本會重新判斷並安裝新的 runtime。

這也是這套方案和傳統「先安裝 CUDA → 再安裝 llama.cpp → 再配置模型路徑」方式最大的區別：**整個 llama.cpp 運行環境跟著文件夾走。**
