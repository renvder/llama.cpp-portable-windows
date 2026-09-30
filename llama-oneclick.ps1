# =====================================================================
#  llama.cpp One-Click Portable Launcher (Windows 11 / PowerShell 5.1+)
#
#  First run:
#    1. Detect Windows architecture + GPU + NVIDIA driver/CUDA capability.
#    2. Select the best official llama.cpp Windows backend.
#    3. Download the latest stable release directly from ggml-org/llama.cpp.
#    4. Install it under THIS SCRIPT'S directory (portable; no winget/CUDA toolkit required).
#
#  Later runs:
#    - Reuse the locally installed runtime when it matches the detected hardware.
#    - If the PC/backend changes, automatically install the appropriate runtime.
#
#  Backends:
#    NVIDIA + driver >= 580  -> CUDA 13
#    NVIDIA + driver >= 525  -> CUDA 12
#    AMD / Intel             -> Vulkan
#    Otherwise               -> CPU
#
#  The script keeps the existing model/router/VRAM/preset logic below.
# =====================================================================

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ROOT       = (Resolve-Path $PSScriptRoot).Path
$MODELS_DIR = Join-Path $ROOT "models"
$RUNTIME_DIR = Join-Path $ROOT "runtime"
$PORT_PREF  = 8080
$MAX_PREDICT = 16384
$THINKING = "off"
$YARN_CTX = 0
$YARN_ORIG_CTX = 32768

function Say($msg, $color = "White") { Write-Host $msg -ForegroundColor $color }
function Fail($msg) { Say ""; Say "  $msg" Red; Read-Host "  Press Enter to exit"; exit 1 }

Set-Location $ROOT

Say ""
Say "  llama.cpp Portable One-Click Launcher" Cyan
Say "  ---------------------------------------------" DarkGray

# ---------------------------------------------------------------------
# 0. Windows / architecture detection
# ---------------------------------------------------------------------
$osArch = $env:PROCESSOR_ARCHITECTURE
if ($env:PROCESSOR_ARCHITEW6432) { $osArch = $env:PROCESSOR_ARCHITEW6432 }
if ($osArch -notmatch "AMD64|x64") {
    Fail "This portable package currently targets Windows x64. Detected architecture: $osArch"
}

# ---------------------------------------------------------------------
# 1. Hardware detection + automatic backend selection
# ---------------------------------------------------------------------
$gpuName = "No supported discrete GPU"
$vramGB = 0
$vendor = "cpu"
$driverVersion = $null
$cudaReported = $null

if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
    try {
        $line = (& nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader,nounits 2>$null | Select-Object -First 1)
        if ($line) {
            $parts = $line -split ","
            $gpuName = $parts[0].Trim()
            $vramGB = [math]::Round([double]$parts[1].Trim() / 1024, 1)
            $driverVersion = $parts[2].Trim()
            $vendor = "cuda"
            try {
                $smi = (& nvidia-smi 2>$null | Out-String)
                if ($smi -match "CUDA Version:\s*([0-9]+\.[0-9]+)") { $cudaReported = $Matches[1] }
            } catch { }
        }
    } catch { }
}

# AMD / Intel: Vulkan is the portable Windows GPU fallback.
if ($vendor -eq "cpu") {
    $cards = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
             Where-Object { $_.Name -notmatch "Basic Display|Remote|Meta|Parsec|Virtual" }
    foreach ($c in $cards) {
        $n = $c.Name
        if ($n -match "Radeon|AMD|Intel\s+Arc|Intel\(R\)\s+Arc") {
            $gpuName = $n
            if ($n -match "Radeon|AMD") { $vendor = "vulkan" }
            elseif ($n -match "Arc") { $vendor = "vulkan" }
            break
        }
    }
    if ($vendor -eq "vulkan") {
        $key = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
        Get-ChildItem $key -ErrorAction SilentlyContinue | ForEach-Object {
            $sz = (Get-ItemProperty $_.PSPath -Name "HardwareInformation.qwMemorySize" -ErrorAction SilentlyContinue)."HardwareInformation.qwMemorySize"
            if ($sz -and ($sz / 1GB) -gt $vramGB) { $vramGB = [math]::Round($sz / 1GB, 1) }
        }
    }
}

$ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
$cores = (Get-CimInstance Win32_Processor | Measure-Object -Property NumberOfCores -Sum).Sum
if (-not $cores) { $cores = [Environment]::ProcessorCount / 2 }
$threads = [math]::Max(4, [math]::Min($cores, 16))

# NVIDIA driver major determines CUDA family. CUDA 13.x requires R580+;
# CUDA 12.x supports R525+ under NVIDIA's minor-version compatibility rules.
if ($vendor -eq "cuda") {
    $driverMajor = 0
    if ($driverVersion -match "^(\d+)") { $driverMajor = [int]$Matches[1] }
    if ($driverMajor -ge 580) {
        $backend = "cuda13"
        $backendLabel = "NVIDIA CUDA 13"
    } elseif ($driverMajor -ge 525) {
        $backend = "cuda12"
        $backendLabel = "NVIDIA CUDA 12"
    } else {
        $backend = "vulkan"
        $backendLabel = "NVIDIA Vulkan fallback (driver too old for CUDA 12)"
        $vendor = "vulkan"
    }
} elseif ($vendor -eq "vulkan") {
    $backend = "vulkan"
    $backendLabel = "Vulkan"
} else {
    $backend = "cpu"
    $backendLabel = "CPU"
}

Say ""
Say "  GPU          : $gpuName" White
Say "  VRAM         : $(if ($vramGB -gt 0) { "$vramGB GB" } else { "-" })" White
Say "  RAM          : $ramGB GB" White
Say "  CPU cores    : $cores" White
if ($driverVersion) { Say "  NVIDIA driver: $driverVersion (nvidia-smi CUDA $cudaReported)" White }
Say "  Selected     : $backendLabel" Green

# ---------------------------------------------------------------------
# 2. Portable llama.cpp runtime installation / reuse
# ---------------------------------------------------------------------
function Get-LocalRuntime {
    $preferred = @(
        (Join-Path $RUNTIME_DIR $backend),
        (Join-Path $ROOT "llama-$backend"),
        (Join-Path $ROOT "llama.cpp")
    )
    foreach ($d in $preferred) {
        $e = Join-Path $d "llama-server.exe"
        if (Test-Path $e) { return $e }
    }
    # Preserve compatibility with an existing llama-server.exe directly under the package.
    $rootExe = Join-Path $ROOT "llama-server.exe"
    if (Test-Path $rootExe) { return $rootExe }
    return $null
}

function Get-ReleasesWithAssets {
    $headers = @{ "User-Agent" = "llama.cpp-portable-launcher"; "Accept" = "application/vnd.github+json" }
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        # The newest stable release may not carry binary assets.  Search the
        # official release list and select the newest release that actually
        # contains the required Windows x64 backend.
        return Invoke-RestMethod -Uri "https://api.github.com/repos/ggml-org/llama.cpp/releases?per_page=100" -Headers $headers -UseBasicParsing
    } catch {
        throw "Cannot query the official llama.cpp GitHub release API: $($_.Exception.Message)"
    }
}

function Find-Asset($assets, $pattern) {
    return $assets | Where-Object { $_.name -match $pattern } | Select-Object -First 1
}

# GitHub exposes "sha256:<hex>" in asset.digest. Verify the download when it is available.
function Test-AssetHash($asset, $path) {
    if ($asset.digest -and ($asset.digest -match '^sha256:([0-9a-fA-F]{64})$')) {
        $actual = (Get-FileHash -Path $path -Algorithm SHA256).Hash
        if ($actual -ne $Matches[1]) {
            throw "SHA-256 mismatch for $($asset.name). The download may be corrupted; please run again."
        }
    }
}

function Install-PortableRuntime {
    if (-not (Test-Path $RUNTIME_DIR)) { New-Item -ItemType Directory -Path $RUNTIME_DIR | Out-Null }

    Say ""
    Say "  No suitable local llama.cpp runtime found." Yellow
    Say "  Selecting the official Windows x64 build for: $backendLabel" Yellow
    Say "  Downloading from ggml-org/llama.cpp ..." Cyan

    # Do not assume /releases/latest contains binaries.  Since v0.5.0 the
    # newest stable release can point to a nightly build while carrying only
    # a marker asset.  Search the official release list for the newest release
    # that actually contains the backend we need.
    $releases = Get-ReleasesWithAssets
    $main = $null
    $cudart = $null
    $release = $null

    switch ($backend) {
        "cuda13" {
            $mainPattern = '^llama-.*-bin-win-cuda-13\.\d+-x64\.zip$'
            $cudartPattern = '^cudart-llama-bin-win-cuda-13\.\d+-x64\.zip$'
        }
        "cuda12" {
            $mainPattern = '^llama-.*-bin-win-cuda-12\.\d+-x64\.zip$'
            $cudartPattern = '^cudart-llama-bin-win-cuda-12\.\d+-x64\.zip$'
        }
        "vulkan" { $mainPattern = '^llama-.*-bin-win-vulkan-x64\.zip$' }
        default   { $mainPattern = '^llama-.*-bin-win-cpu-x64\.zip$' }
    }

    foreach ($r in ($releases | Where-Object { -not $_.draft } | Sort-Object { [datetime]$_.published_at } -Descending)) {
        $assets = @($r.assets)
        $candidate = Find-Asset $assets $mainPattern
        if (-not $candidate) { continue }

        if ($backend -eq "cuda13" -or $backend -eq "cuda12") {
            $candidateCudart = Find-Asset $assets $cudartPattern
            if (-not $candidateCudart) { continue }
            $cudart = $candidateCudart
        }

        $release = $r
        $main = $candidate
        break
    }

    if (-not $release -or -not $main) {
        throw "No official Windows x64 build for $backend was found in the latest 100 llama.cpp releases."
    }

    $tag = $release.tag_name

    $target = Join-Path $RUNTIME_DIR $backend
    $temp = Join-Path $env:TEMP ("llama-cpp-portable-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $temp | Out-Null

    try {
        $mainZip = Join-Path $temp $main.name
        Say "  Release      : $tag" White
        Say "  Binary       : $($main.name)" White
        Invoke-WebRequest -Uri $main.browser_download_url -OutFile $mainZip -UseBasicParsing
        Test-AssetHash $main $mainZip

        $allZips = @($mainZip)
        if ($cudart) {
            $cudaZip = Join-Path $temp $cudart.name
            Say "  CUDA runtime : $($cudart.name)" White
            Invoke-WebRequest -Uri $cudart.browser_download_url -OutFile $cudaZip -UseBasicParsing
            Test-AssetHash $cudart $cudaZip
            $allZips += $cudaZip
        }

        if (Test-Path $target) { Remove-Item $target -Recurse -Force }
        New-Item -ItemType Directory -Path $target | Out-Null

        foreach ($z in $allZips) {
            Expand-Archive -Path $z -DestinationPath $target -Force
        }

        # Some releases put binaries in a nested directory. Flatten one level when needed.
        $found = Get-ChildItem $target -Recurse -Filter "llama-server.exe" -File | Select-Object -First 1
        if (-not $found) { throw "Download completed, but llama-server.exe was not found after extraction." }

        # If nested, move the extracted contents to the backend root.
        if ($found.Directory.FullName -ne $target) {
            $nested = $found.Directory.FullName
            Get-ChildItem $nested -Force | Move-Item -Destination $target -Force
            if (Test-Path $nested) { Remove-Item $nested -Recurse -Force -ErrorAction SilentlyContinue }
        }

        $info = [ordered]@{
            backend = $backend
            backend_label = $backendLabel
            release = $tag
            asset = $main.name
            cuda_runtime_asset = if ($cudart) { $cudart.name } else { $null }
            installed_at = (Get-Date).ToString("o")
        }
        $info | ConvertTo-Json | Set-Content -Path (Join-Path $target "runtime-info.json") -Encoding UTF8
        return (Join-Path $target "llama-server.exe")
    } finally {
        if (Test-Path $temp) { Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

$exe = Get-LocalRuntime
if (-not $exe) {
    try { $exe = Install-PortableRuntime }
    catch { Fail "Automatic llama.cpp installation failed.`n`n$($_.Exception.Message)" }
}

if (-not $exe -or -not (Test-Path $exe)) {
    Fail "llama-server.exe was not found after installation."
}

Say ""
Say "  llama.cpp    : $exe" Green

# ---------------------------------------------------------------------
# 3. Choose port
#    On Windows, 8080 is frequently inside Hyper-V / WSL reserved ranges
#    (visible via netsh). Binding then fails with an obscure error,
#    so we probe first and fall back.
# ---------------------------------------------------------------------
$reserved = @()
try {
    $out = & netsh int ipv4 show excludedportrange protocol=tcp 2>$null
    foreach ($l in $out) {
        if ($l -match "^\s*(\d+)\s+(\d+)\s*$") { $reserved += ,@([int]$Matches[1], [int]$Matches[2]) }
    }
} catch { }

function Test-PortFree($p) {
    foreach ($r in $reserved) { if ($p -ge $r[0] -and $p -le $r[1]) { return $false } }
    if (Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue) { return $false }
    return $true
}

$PORT = $null
foreach ($cand in @($PORT_PREF, 8090, 8081, 8188, 11434, 18080)) {
    if (Test-PortFree $cand) { $PORT = $cand; break }
}
if (-not $PORT) { $PORT = 18080 }
if ($PORT -ne $PORT_PREF) { Say ""; Say "  Port $PORT_PREF is occupied or system-reserved, using $PORT instead" Yellow }


# ---------------------------------------------------------------------
# 4. Probe which flags the current version supports
#    (flag names change between versions; probe first to avoid immediate crash)
# ---------------------------------------------------------------------
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = "Continue"     # PS 5.1: native stderr + Stop would abort here
$help = (& $exe --help 2>&1 | ForEach-Object { "$_" }) -join "`n"
$ErrorActionPreference = $prevEAP
function Has($flag) { return $help -match [regex]::Escape($flag) }

if (-not (Has "--models-dir")) {
    Say ""
    Say "  Your llama.cpp version is too old and does not support router mode (hot model switching)." Red
    Say "  Delete the runtime\$backend folder and run start.bat again to download the latest build." Yellow
    Read-Host "  Press Enter to exit"; exit 1
}

# Flash Attention: new syntax is -fa on/off/auto, old syntax is a pure flag
$faMode = "none"
if (Has "--flash-attn") {
    if ($help -match "flash-attn.*\[on\|off\|auto\]") { $faMode = "value" } else { $faMode = "flag" }
}

# ---------------------------------------------------------------------
# 5. Calculate parameters according to VRAM tier
#    Note: -ngl / layer offloading is left to llama.cpp's own --fit,
#    which measures free VRAM before loading and automatically drops layers
#    / offloads MoE experts to system RAM. Far more accurate than manual -ngl.
#    Here we only decide the strategy: context length and whether to quantize KV.
# ---------------------------------------------------------------------
if ($vramGB -ge 32)     { $ctx = 32768; $kvq = $false; $maxModels = 2; $tier = "32G+ (5090 / pro cards)" }
elseif ($vramGB -ge 24) { $ctx = 32768; $kvq = $true;  $maxModels = 1; $tier = "24G tier (4090 / 3090)" }
elseif ($vramGB -ge 16) { $ctx = 32768; $kvq = $true;  $maxModels = 1; $tier = "16G tier (4080 / 5070Ti / 7900XT)" }
elseif ($vramGB -ge 11) { $ctx = 16384; $kvq = $true;  $maxModels = 1; $tier = "12G tier (3060 12G / 4070)" }
elseif ($vramGB -ge 7)  { $ctx = 8192;  $kvq = $true;  $maxModels = 1; $tier = "8G tier (3060Ti / 4060)" }
elseif ($vramGB -ge 4)  { $ctx = 4096;  $kvq = $true;  $maxModels = 1; $tier = "6G and below (entry / laptop)" }
else                    { $ctx = 4096;  $kvq = $true;  $maxModels = 1; $tier = "Pure CPU mode (will be slow)" }

# Cap context if system RAM is low
if ($ramGB -lt 16 -and $ctx -gt 8192) { $ctx = 8192 }

# V-cache quantization requires Flash Attention; without it we only quantize K
$kvqV = $kvq -and ($faMode -ne "none")

# YaRN: if enabled, override the tier-calculated ctx with the target length
$yarnOn = $false
if ($YARN_CTX -gt $YARN_ORIG_CTX) {
    if (Has "--rope-scaling") {
        $yarnOn = $true
        $ctx    = $YARN_CTX
        $yarnScale = [math]::Round($YARN_CTX / $YARN_ORIG_CTX, 2)
        Say ""
        Say "  YaRN enabled: $YARN_ORIG_CTX -> $YARN_CTX (scale $yarnScale)" Yellow
        Say "  KV cache will grow proportionally; if VRAM is insufficient a large amount will spill to RAM and speed will drop noticeably." Yellow
        Say "  Short-conversation quality is also affected. Set YARN_CTX back to 0 when you do not need long context." Yellow
    } else {
        Say ""
        Say "  This version does not support --rope-scaling; YaRN setting ignored." Yellow
    }
}

# Thinking mode interaction: raise generation limit when thinking is on so <think> has room
if ($THINKING -ne "off" -and $MAX_PREDICT -lt 16384) { $MAX_PREDICT = 16384 }

Say ""
Say "  Matched tier : $tier" Green
Say "  Backend      : $backendLabel" Green
Say "  Port         : $PORT" Green
Say "  Thinking     : $(switch ($THINKING) { 'off' { 'off (answer directly)' } 'on' { 'on' } default { 'follow model default' } })" Green
Say "  Max predict  : $MAX_PREDICT tokens" Green

# ---------------------------------------------------------------------
# 6. Models directory
# ---------------------------------------------------------------------
if (-not (Test-Path $MODELS_DIR)) { New-Item -ItemType Directory -Path $MODELS_DIR | Out-Null }
$ggufs = Get-ChildItem $MODELS_DIR -Recurse -Filter "*.gguf" -ErrorAction SilentlyContinue

Say ""
if ($ggufs.Count -eq 0) {
    Say "  models folder is empty." Yellow
    Say "  Recommended models for your VRAM (place them into the models folder):" Yellow
    if     ($vramGB -ge 24) { Say "    - Qwen3 32B Instruct  Q4_K_M   (~20 GB)" }
    elseif ($vramGB -ge 16) { Say "    - Qwen3 14B Instruct  Q4_K_M   (~9 GB)" }
    elseif ($vramGB -ge 11) { Say "    - Qwen3 14B Instruct  Q4_K_M   (~9 GB)" }
    elseif ($vramGB -ge 7)  { Say "    - Qwen3 8B Instruct   Q4_K_M   (~5 GB)" }
    else                    { Say "    - Qwen3 4B Instruct   Q4_K_M   (~2.5 GB)" }
    Say ""
    Say "  Multi-part GGUFs or multimodal models with mmproj should each go into their own sub-folder." DarkGray
    Say "  After placing the files, re-run this script." DarkGray
    Read-Host "  Press Enter to exit"; exit 0
}

Say "  Found $($ggufs.Count) model(s):" Green
$ggufs | Select-Object -First 8 | ForEach-Object {
    Say ("    - {0}  ({1} GB)" -f $_.Name, [math]::Round($_.Length / 1GB, 1)) DarkGray
}
if ($ggufs.Count -gt 8) { Say "    - ...and $($ggufs.Count - 8) more" DarkGray }

# ---------------------------------------------------------------------
# 7. presets.ini (optional)
#    Precedence in llama-server: CLI args > per-model section > [*] global section.
#    Anything passed on the CLI therefore overrides presets.ini, so this launcher
#    does NOT pass ctx-size (>=16 GB VRAM) or sampling params on the CLI.
#    Put those in presets.ini instead.
# ---------------------------------------------------------------------
$presets    = Join-Path $PSScriptRoot "presets.ini"
$usePresets = (Test-Path $presets) -and (Has "--models-preset")

if ($usePresets) {
    Say ""
    Say "  presets.ini loaded (per-model ctx-size / sampling live here)" Green
    Say "  Note: [Section] names must equal the model names shown in 'Available models' in the log." DarkGray
    Say "  Check the log for 'Loaded N custom model presets'; N=0 means no section name matched." DarkGray
} elseif (Test-Path $presets) {
    Say ""
    Say "  presets.ini detected, but this version does not support --models-preset; ignored." Yellow
}


# ---------------------------------------------------------------------
# 8. Assemble launch arguments
# ---------------------------------------------------------------------
$srvArgs = @(
    "--models-dir", $MODELS_DIR
    "--host", "127.0.0.1"
    "--port", "$PORT"
    "-t", "$threads"
)
if (Has "--ctx-shift") { $srvArgs += "--ctx-shift" }

if ($usePresets) { $srvArgs += @("--models-preset", $presets) }

# ctx-size: only forced from the CLI when needed (YaRN, or <16 GB VRAM / <16 GB RAM safety cap).
# Otherwise presets.ini decides; with ctx-size = 0 (native) llama.cpp's --fit shrinks it to fit VRAM.
$cliCtx = $yarnOn -or ($vramGB -lt 16) -or ($ramGB -lt 16)
if ($cliCtx) { $srvArgs += @("-c", "$ctx") }
if ($yarnOn) {
    $srvArgs += @("--rope-scaling", "yarn", "--rope-scale", "$yarnScale")
    if (Has "--yarn-orig-ctx") { $srvArgs += @("--yarn-orig-ctx", "$YARN_ORIG_CTX") }
    Say "  Context    : $ctx tokens (YaRN extrapolated)" Green
} elseif ($cliCtx) {
    Say "  Context    : $ctx tokens (from launcher)" Green
} else {
    Say "  Context    : decided by presets.ini / --fit (see 'fit' lines in the log)" Green
}

if (Has "--models-max") { $srvArgs += @("--models-max", "$maxModels") }

# Single-user setup: one slot; larger physical batch speeds up prompt processing (uses a bit more VRAM)
if (Has "--parallel")     { $srvArgs += @("-np", "1") }
if ($vendor -ne "cpu") {
    if (Has "--ubatch-size") { $srvArgs += @("-ub", "1024") }
    if (Has "--batch-size")  { $srvArgs += @("-b", "2048") }
}

# * Generation limit: llama-server defaults to --predict -1 (unlimited).
#   Once the model starts repeating it will fill the entire context and hang at 0 remaining.
#   We therefore impose a hard ceiling.
#   Note that the max-tokens setting in the web UI overrides this; set both.
if     (Has "--predict")   { $srvArgs += @("-n", "$MAX_PREDICT") }
elseif (Has "--n-predict") { $srvArgs += @("--n-predict", "$MAX_PREDICT") }

# Flash Attention (also required for V-cache quantization to take effect)
if     ($faMode -eq "value") { $srvArgs += @("-fa", "on") }
elseif ($faMode -eq "flag")  { $srvArgs += "-fa" }

# KV quantization
if ($kvq -and (Has "--cache-type-k")) {
    $srvArgs += @("--cache-type-k", "q8_0")
    if ($kvqV) { $srvArgs += @("--cache-type-v", "q8_0") }
}
Say "  KV cache   : $(if ($kvq) { if ($kvqV) { 'K+V q8_0 quantized' } else { 'K only q8_0 (no FA, V stays f16)' } } else { 'f16 full precision' })" Green

if (Has "--jinja") { $srvArgs += "--jinja" }          # Correctly apply the model's built-in chat template + tool calling

# Thinking-mode switch. Different llama.cpp versions implement it differently; probe in priority order:
#   1) --reasoning-budget 0   most direct (newer versions)
#   2) --chat-template-kwargs via template variable enable_thinking
# If neither is available the only way is to append /no_think in the chat itself.
if ($THINKING -eq "off") {
    if (Has "--reasoning-budget") {
        $srvArgs += @("--reasoning-budget", "0")
    } elseif (Has "--chat-template-kwargs") {
        $srvArgs += @("--chat-template-kwargs", '{"enable_thinking":false}')
    } else {
        Say "  This version cannot disable thinking from the server side; append /no_think to your prompts" Yellow
    }
} elseif ($THINKING -eq "on") {
    if (Has "--reasoning-budget") { $srvArgs += @("--reasoning-budget", "-1") }
    # Put thinking content into a separate field so the web UI can collapse it
    if (Has "--reasoning-format") { $srvArgs += @("--reasoning-format", "auto") }
}

# Sampling (temp / top-p / top-k / min-p / presence-penalty) is intentionally NOT passed here:
# CLI args would override per-model values in presets.ini. Set them per model there.
# Qwen3 reference: thinking on  -> temp 0.6, top-p 0.95, presence 0.5
#                  thinking off -> temp 0.7, top-p 0.8,  presence 1.0   (top-k 20, min-p 0)

# VRAM allocation: prefer --fit auto-calculation; fall back to full offload if the version lacks it
if (Has "--fit-target") {
    $srvArgs += @("--fit-target", $(if ($vramGB -ge 16) { "2048" } else { "1024" }))
} elseif ($vendor -ne "cpu") {
    $srvArgs += @("-ngl", "99")
    Say "  VRAM alloc : this version has no --fit, fell back to -ngl 99 (full offload)" Yellow
}

if ($vendor -eq "cpu" -and (Has "--no-warmup")) { $srvArgs += "--no-warmup" }

Say ""
Say "  Launch command:" DarkGray
Say "  $exe $($srvArgs -join ' ')" DarkGray
Say ""
Say "  Starting... Browser will open automatically at http://127.0.0.1:$PORT" Cyan
Say "  You can switch models any time from the drop-down in the top-left of the web UI; no restart needed." Cyan
Say "  Tip: also set max tokens to $MAX_PREDICT in the web UI settings (top-right); do not leave it at -1." Yellow
Say "  Closing this black window stops the server." DarkGray
Say ""

# Probe the TCP port directly instead of /health -
# in router mode /health returns 503 while no model is loaded,
# which makes Invoke-WebRequest throw and the browser never opens.
Start-Job -ScriptBlock {
    param($p)
    for ($i = 0; $i -lt 90; $i++) {
        Start-Sleep -Seconds 1
        try {
            $c = New-Object Net.Sockets.TcpClient
            $c.Connect("127.0.0.1", $p)
            $c.Close()
            Start-Process "http://127.0.0.1:$p"
            break
        } catch { }
    }
} -ArgumentList $PORT | Out-Null

# -----------------------------------------------------------------
# Minimize this console window so only the browser is visible
# -----------------------------------------------------------------
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
}
"@
$consolePtr = [Win32]::GetConsoleWindow()
if ($consolePtr -ne [IntPtr]::Zero) {
    [Win32]::ShowWindow($consolePtr, 6)   # 6 = SW_MINIMIZE
}

& $exe @srvArgs
