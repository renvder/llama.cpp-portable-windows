<p align="right">
  🌐 <b>EN</b> |
  <a href="./Vision_Multimodal_Setup_tw.md"><b>漢</b></a>
</p>

# Model Folder Layout: Vision Models and Auto-Generated presets.ini

**Short version: put every model in its own subfolder under `models\`.** This one rule fixes two separate problems:

1. Vision (multimodal) models silently falling back to text-only.
2. A model getting no entry in the auto-generated `presets.ini` (no measured `ctx-size`, no sampling settings).

## Problem 1: Vision models fall back to text-only

If you run `llama-server` in **router mode** (started with `--models-dir`, which is what this launcher uses so you can hot-swap models), a vision/multimodal GGUF model will silently fall back to **text-only** unless it is set up correctly. There is no error message: the server just won't accept images, and `/props` reports `"modalities": { "vision": false }` for that model.

This is **not a bug in the launcher script**. It is how llama-server's router mode discovers multimodal projector files.

### Root cause

A vision-capable model in llama.cpp is actually **two separate GGUF files**:

1. The main language model (e.g. `Qwen3-VL-8B-Q4_K_M.gguf`)
2. A multimodal projector, or **mmproj**, file that encodes images into embeddings (e.g. `mmproj-Qwen3-VL-8B-F16.gguf`)

In router mode, llama-server scans the `models` directory and pairs these two files automatically, **but only if both conditions are met**:

- The model file and its mmproj file are **together in their own dedicated subfolder** (not loose in the root of `models`, and not mixed with other models' files)
- The projector file's name **starts with `mmproj`**

If either condition isn't met, the mmproj file is either ignored or picked up as an unrelated, unusable "model" of its own, and the actual language model loads as text-only.

## Problem 2: Models in the root get no auto-generated presets.ini entry

The launcher generates `presets.ini` for you: it measures the largest `ctx-size` that fits your GPU and fills in the sampling settings for the model family. But the generator **only scans subfolders of `models\`**. In each subfolder it takes the largest non-mmproj `.gguf` as the model and pairs the `mmproj*.gguf` next to it.

So a single-file model placed **directly in `models\`** behaves like this:

| | Model in its own subfolder | Model loose in `models\` |
|---|---|---|
| Shows up in the Web UI model list | Yes | Yes |
| Gets a section in `presets.ini` | Yes | **No** |
| Measured `ctx-size` | Yes | **No** (falls back to the VRAM-tier value or `--fit`) |
| Family sampling settings | Yes | **No** (server defaults) |
| mmproj paired (vision) | Yes | **No** |

If `models\` contains only loose files, no `presets.ini` is generated at all. The model still runs, which is why this is easy to miss: it just doesn't get the tuned settings.

## Correct directory structure

```
models/
├─ Qwen3-14B/                                    ← text model: own folder too, so it gets a presets.ini entry
│  └─ Qwen3-14B-Instruct-Q4_K_M.gguf
│
├─ Qwen3.8-27B/                                  ← vision model: own folder is required
│  ├─ Qwen3.8-27B-Q4_K_M.gguf
│  └─ mmproj-Qwen3.8-27B-F16.gguf
│
└─ Qwen3-VL-8B/                                  ← another vision model, its own folder too
   ├─ Qwen3-VL-8B-Q4_K_M.gguf
   └─ mmproj-Qwen3-VL-8B-F16.gguf
```

The folder name becomes the section name in `presets.ini` and the model name in the Web UI.

## Common mistakes

| Mistake | Result |
|---|---|
| Model `.gguf` and `mmproj-*.gguf` both dropped loose in `models/` root | Not paired: model loads text-only, and no `presets.ini` section is generated |
| Text-only model loose in `models/` root | Loads and runs, but gets no measured `ctx-size` or sampling settings |
| Two different models (or two quantizations of one model) in one folder | The generator takes only the largest non-mmproj `.gguf` as that folder's model, so the other is skipped; the router may also pair the mmproj with the wrong file |
| Projector file renamed to something that doesn't start with `mmproj` (e.g. `vision-encoder.gguf`) | Not recognized as a projector at all |
| Model and mmproj files in separate subfolders | No pairing across folders: the router only looks *within* the same folder |

## How to verify it worked

1. Restart the launcher and watch the startup log. `Loaded N custom model presets` should show N of at least 1 (N=0 means no section name matched a model).
2. Open the generated `presets.ini`: there should be a `[folder-name]` section for each model, with `model =` and (for vision models) `mmproj =` lines.
3. Once a vision model is loaded, check the router's `/props` (or `/props?model=<name>`) endpoint and look for:
   ```json
   "modalities": { "vision": true }
   ```
4. In the Web UI, an image-upload / attachment icon should appear next to the chat input once a vision-capable model is selected. If it's missing, the pairing failed.

If you moved or replaced models, the launcher regenerates `presets.ini` on the next start (the old file is saved as `presets.ini.bak`).

## Quick checklist

- [ ] Every model has its **own subfolder** under `models/`, vision or not
- [ ] Each subfolder contains **exactly** that model's file plus its mmproj file (no other model's files mixed in)
- [ ] The projector filename **starts with `mmproj`**
- [ ] `presets.ini` has a `[folder-name]` section for each model
- [ ] After restarting, `/props` shows `"vision": true` for vision models
