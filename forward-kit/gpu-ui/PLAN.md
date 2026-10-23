# GPU-accelerated UI — implementation plan

Goal: make the iOS interface smooth by moving it off the CPU. **No Metal, no games** — this accelerates
only the UI, using iOS's own OpenGL-ES renderer over an open Adreno driver. Based on the research in
`../../../GPU_GAMES_RESEARCH.md` (sections 1 and 2).

**Status:** plan only. This is kernel + driver work that must be built and tested on the device.
Stage 2 is a multi-person-year core. Do stage 1 first — it's the biggest win for the least work.

## Background (ios-sweet today)

CoreAnimation renders in software → backboardd → kernel IOSurface (ios-sweet patch **0046**,
IOCoreSurfaceRoot + AppleCLCD/IOMobileFramebuffer) → **AppleCLCD CPU-memcpies the whole ~10 MB frame**
into the bootloader's framebuffer every swap. To stop that starving one CPU, ios-sweet throttles panel
copies to a 10 Hz vsync (patch **0056**). That memcpy is the first thing to kill.

## Stage 1 — Direct display scanout (no GPU; biggest win)

- Instead of memcpying each frame, program the display controller (Qualcomm **MDP/DPU**) to scan out
  iOS's IOSurface **directly** (point the panel's source plane at the surface's physical pages).
- Where: the AppleCLCD/IOMobileFramebuffer present path in ios-sweet patch **0046/0056** — replace the
  CPU copy with a plane-flip to the current IOSurface.
- Reference: the display controller registers are documented in the Linux `mdp5`/`dpu` driver (GPL — read
  as reference, don't copy into the kernel).
- **Gate:** SpringBoard scroll at full panel rate with the per-frame memcpy gone; measure fps and CPU vs
  the current 10 Hz copy.

## Stage 2 — Kernel GPU driver + Mesa turnip (the hard core)

- Write one **XNU kernel GPU driver** exposing a **KGSL-shaped ioctl interface** (self-contained, no Linux
  DRM/KMS needed): GPU address space via SMMU, power/clock/GMU, SQE firmware load, ringbuffer + buffer
  objects, submit queue, fences/IRQ. This is the irreducible multi-person-year part.
- Userspace: **Mesa turnip** (MIT), Adreno **6xx only**. Build only its `kgsl` `tu_knl` backend (it can
  build without libdrm) and port Mesa's platform shims to Darwin. No shader compiler or command-stream RE
  needed — turnip provides them.
- References: freedreno KGSL interface https://github.com/freedreno/freedreno/wiki/kgsl-kernel ;
  Mesa `src/freedreno/vulkan/tu_knl.c`. Linux `drm/msm` + downstream KGSL are GPL references only.
- **Gate:** a GPU-filled/blitted buffer, timed against the CPU doing the same.

## Stage 3 — Point CoreAnimation's GLES renderer at the GPU

- iOS's QuartzCore ships a GLES renderer (`CA::OGL::GLContext`) beside the software one
  (`CA::OGL::SW`) ios-sweet uses. Make the render server select GLES, backed by an **EGL/GLES context**
  on the Adreno driver (GLES via freedreno/`gallium`, or layered on turnip).
- Render into the **existing IOSurface/IOMobileFramebuffer** plumbing (patch 0046) + stage-1 scanout —
  zero-copy, since CPU and GPU share RAM.
- Proven in spirit by Columbia's Cycada (redirect iOS graphics to the host GLES driver) and the xios
  project (GLES client → IOSurface → compositor, software fallback).
- **Gate:** SpringBoard composited on the GPU — scroll fps up, CPU down, no corruption.

## What this is not
- Not Metal, not a Metal→Vulkan layer, not games (see `GPU_GAMES_RESEARCH.md` §3 — team-sized, separate).
- Adreno **5xx** (e.g. Adreno 506) gets GLES only, never turnip Vulkan — another reason to use a 6xx device.
