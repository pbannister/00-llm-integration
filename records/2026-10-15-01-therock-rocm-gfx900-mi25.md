# TheRock ROCm on beast.lan — gfx900 (AMD Instinct MI25)

Replaces AMD's ROCm 7.14.1 userspace (which ships **no gfx900 kernels**) with
TheRock's ROCm 10.2.0a build, which **does** build gfx900.

---

## Why this was necessary

The MI25 is `gfx900`. AMD's ROCm 7.14.1 package set covers gfx1010–gfx1250,
gfx908, gfx90a, gfx942, gfx950 — but **not gfx900**:

```
/opt/rocm/core-7.14/lib/rocblas/library/   # before
gfx1010 gfx1011 ... gfx1250 gfx908 gfx90a gfx942 gfx950     <-- no gfx900
```

The kernel driver was *never* the problem — it already supported gfx900 and
`rocminfo` enumerated the agent. The gap was purely the userspace math
libraries, so only those needed replacing.

## What was done

1. **Uninstalled** all 237 `amdrocm*` userspace packages (`EXIT=0`).
   `amdgpu-dkms` `1:6.19.14.31400100-2377056.24.04` was **deliberately kept** —
   it is what makes the GPU usable at all and already supports gfx900.
   A dry-run confirmed 0 DKMS packages would be removed before acting.
2. **Installed TheRock ROCm** into the venv `/home/preston/rocm-therock`
   from `https://nightly.repo.amd.com/rocm/whl-next/`:
   `rocm[libraries,device-gfx900]`
3. **Installed PyTorch** with gfx900 device code:
   `torch[device-gfx900] torchvision[device-gfx900] torchaudio`
4. **Neutralized stale env**: `~/.profile` exported `/opt/rocm/bin` and
   `/opt/rocm/lib`, both dead after the uninstall. Replaced with
   `THEROCK_ROCM` + `$THEROCK_ROCM/bin` on `PATH`. Backup at
   `~/.profile.bak-therock-*`.
5. **Rebuilt host OpenBLAS** (`librocm-openblas.so.0`) because TheRock's
   DYNAMIC_ARCH build SIGILLs on this CPU — see "OpenBLAS rebuild" below.
   This restored AVX and roughly doubled CPU BLAS throughput.

### gfx900 is nightly-only

The **stable** channel (10.0/10.1) publishes **zero** gfx900 artifacts. gfx900
exists only in **nightly** (`therock-dist-linux-gfx900-...`). Native `.deb`
packages are **not** published for this — `packages/deb/ubuntu2604/` returns
HTTP 404 on both channels — so wheels (or tarballs) are the only real options.

---

## Usage

**Plain `import torch` is all you need.** No `rocm_sdk` boilerplate is required.

The TheRock torch wheels do carry a RUNPATH baked to a container build path
(`/opt/_internal/cpython-3.14.0b1/...`, and `/opt/python/cp314-cp314/...`) that
does not exist here, so `libtorch_hip.so` cannot resolve `libMIOpen`/`libhipfft`/…
on its own. Torch works around this itself: `torch/_rocm_init.py` ships in the
wheel and is invoked automatically from `torch/__init__.py`:

```python
def initialize():
    import rocm_sdk
    rocm_sdk.initialize_process(
        preload_shortnames=['amd_comgr', 'amd_smi', 'amdhip64', 'hiprtc', 'hipblas',
                            'hipfft', 'hiprand', 'hipsparse', 'hipsparselt', 'hipsolver',
                            'hipblaslt', 'miopen', 'hipdnn', 'rocm_sysdeps_liblzma',
                            'rocm-openblas', 'rocprofiler-sdk', ...],
        check_version='10.2.0a20261015')
```

That preloads the ROCm libraries with `RTLD_GLOBAL` and wires up the
`rocm_kpack` runtime that serves the gfx900 kernels.

```bash
source ~/rocm-therock/bin/activate
python -c "import torch; print(torch.cuda.get_device_name(0))"
# AMD Radeon Instinct MI25
```

`~/rocm-therock/bin/therock-python` still exists as an optional convenience
wrapper (it calls `initialize_process()` then runs your script), but it is
**not** needed — plain `python` works.

### Verified, and a rejected alternative

This was tested by blocking `torch._rocm_init` with a meta-path finder and
re-running the full suite: full GPU validation passes with **zero** boilerplate,
no env vars, and no symlinks.

Satisfying the hardcoded RUNPATH directly with a symlink **was** also proven to
work — one directory symlink at
`/opt/python/cp314-cp314/lib/python3.14/site-packages/_rocm_sdk_devel` →
`~/rocm-therock/lib/python3.14/site-packages/_rocm_sdk_libraries`, plus the
`_rocm_sdk_core/lib` paths on `LD_LIBRARY_PATH`, lets preload-blocked torch
import and run. It was **deliberately not applied**: it is redundant (torch's
preload wins anyway), it embeds an absolute `cp314` path that silently breaks on
a Python upgrade, and it requires root to create a fake `/opt/python` tree. It
would only matter if something loaded `libtorch.so` outside Python, bypassing
`torch/__init__.py`. The live install remains pristine — no symlinks, `/opt`
untouched.

Affected binaries, for the record — 13 torch objects embed the container path:
`libtorch.so`, `libtorch_cpu.so`, `libtorch_hip.so`, `libtorch_python.so`,
`libc10_hip.so`, `_C.cpython-314-x86_64-linux-gnu.so`, and others.

CLI tools live in the venv: `rocminfo`, `amd-smi`, `hipcc`, `rocprofv3`,
`rocm_agent_enumerator`, `rocm-sdk`.

---

Local copies of the artifacts in this repo:
- `records/2026-10-15-01-therock-rocm-gfx900-mi25.md` (this runbook)
- `records/2026-10-15-01-therock-gfx900-validation.py` (full validation suite)
- `records/2026-10-15-01-therock-python-launcher` (the `therock-python` wrapper)
- `records/beast-rocm-pkgs-before.txt`, `records/beast-apt-sources-before.txt` (rollback)

---

## Verification (all passing)

```
torch 2.14.0+rocm10.2.0a20261015 | hip 7.17.26412
device: AMD Radeon Instinct MI25 | capability (9,0) | VRAM 17.2 GB
matmul: OK 12 cases (fp32/fp16/bf16 @ 512/1024/2048/4096)  <- rocBLAS gfx900 Tensile
conv2d: OK (MIOpen)
train step (fwd+bwd+optimizer): OK
throughput: 9.32 TFLOP/s fp16 (4096^3 x20)
2GB alloc: OK
rocm-sdk test: 19/19 OK
rocm-sdk targets: includes gfx900
```

Expected benign warning — no CK grouped-conv kernels exist for gfx900, so
MIOpen falls back:
```
MIOpen: Warning [OpenRuntimeLibraryForDevice] CK grouped conv library not found
for device gfx900: libMIOpenCKGroupedConv_gfx900.so
```

## CPU SIGILL — diagnosed and FIXED

**Symptom:** any torch CPU GEMM died with `SIGILL` (exit 132) — `a @ b`,
`nn.Linear`, `conv2d`. numpy's BLAS matmul on the same box worked fine.

**It was not torch, not oneDNN, not glibc hwcaps, and not the `-z820-perf`
kernel.** gdb pinned it to ROCm's bundled host BLAS:

```
#0  sgemm_oncopy_SANDYBRIDGE+616  vpermd 0x20(%rbx,%rax,1),%ymm15,%ymm1
#1  inner_thread ()  #2 exec_threads ()  #3 blas_thread_server ()
    .../librocm-openblas.so.0
```

### Root cause

The CPU is an **Ivy Bridge-EP Xeon E5-2667 v2**. Raw CPUID confirms:

```
CPUID.1:         AVX=1  FMA3(FMA)=0  F16C=1  OSXSAVE=1
CPUID.80000001:  FMA4=0
CPUID.7.0:       AVX2=0  BMI1=0  BMI2=0
```

`librocm-openblas.so.0` is `OpenBLAS 0.3.31.dev DYNAMIC_ARCH` and auto-detects
`Core: Sandybridge`. Its own embedded message explains the fallback:

> *"Your OS does not support AVX2 instructions. OpenBLAS is using Sandybridge
> kernels as a fallback, which may give poorer performance."*

Sandybridge is a legitimate AVX-only fallback — but **this build's AVX-era
kernels contain AVX2 instructions**. Two confirmed instances:

| Function | Faulting instruction |
| --- | --- |
| `sgemm_oncopy_SANDYBRIDGE+616` | `vpermd` (AVX2) |
| `sgemm_incopy_BARCELONA+1216` | `vpermd` (AVX2) |

So the fallback path raises `#UD` on a CPU that has AVX but not AVX2. This is a
defect in how this OpenBLAS was compiled/assembled, not something this setup
introduced.

### Interim workaround (superseded)

`OPENBLAS_CORETYPE` selects the kernel family at runtime. Of **15** coretypes
tried, only the pre-AVX **Prescott** kernels are clean:

| Coretype | f32 matmul | Full op suite |
| --- | --- | --- |
| PRESCOTT | OK | **ALL_OK** |
| ATHLON | OK | **ALL_OK** (maps to Prescott kernels) |
| BARCELONA | OK | **SIGILL** (`sgemm_incopy_BARCELONA`) |
| NEHALEM, SANDYBRIDGE, HASWELL, ZEN, PILEDRIVER, BULLDOZER, NANO, VIENNA | SIGILL | — |
| CORE2, PENRYN, DUNNINGTON, OPTERON | OK (2D mm) | SIGILL |

Every AVX2-capable coretype crashes; BARCELONA passes a bare 2D matmul but dies
on `F.linear`. This bought correctness but **threw away AVX** (SSE-only
Prescott): f32 ~266, f64 ~275 GFLOPS at n=4096.

## OpenBLAS rebuild — the real fix (AVX restored)

Reasoning about the kernel tables explained everything: scanning every family in
the shipped `librocm-openblas.so.0` for AVX2 instructions gave

| Kernel family | funcs containing AVX2 | AVX2 instructions |
| --- | --- | --- |
| SANDYBRIDGE | 38 | 665 |
| HASWELL | 39 | 702 |
| BARCELONA | 37 | 630 |
| NEHALEM | 35 | 586 |
| **PRESCOTT** | **0** | **0** |

`vpermd` appears in **zero** files under `kernel/` — the AVX2 is introduced by
the compiler (auto-vectorization) during the DYNAMIC_ARCH build, and
`NO_AVX2=1` only affects kernel *selection* (`kernel/Makefile:23`), never
codegen. So DYNAMIC_ARCH is the culprit. With `DYNAMIC_ARCH=0` the whole
miscompile disappears.

### Convention

Cloned 3rd-party repositories on beast live under **`$HOME/sources/`**
(`llama.cpp`, `vllm`, `vllm-ROCm`, `nvtop`, and now `OpenBLAS`). Build *output*
goes elsewhere — for OpenBLAS that is `/home/preston/ob-build/`.

### Recipe

Built from TheRock's own pinned source —
commit `18638c70eff1f0d08e2833b2724deaa128d6a334` of `OpenMathLib/OpenBLAS`
(what `third-party/host-blas/CMakeLists.txt` fetches; its only patch,
`0001-Remove-hardcoded-Zi-and-DEBUG-flags-from-CMake.patch`, is CMake-only and
irrelevant to a Makefile build):

```bash
# Cloned 3rd-party repos live under $HOME/sources/
git clone https://github.com/OpenMathLib/OpenBLAS.git ~/sources/OpenBLAS
cd ~/sources/OpenBLAS && git checkout 18638c70eff1f0d08e2833b2724deaa128d6a334

make -j32 TARGET=SANDYBRIDGE DYNAMIC_ARCH=0 \
     NO_AVX2=1 NO_LAPACK=0 C_LAPACK=1 USE_THREAD=1 \
     LIBSONAMEBASE=rocm-openblas BUILD_TESTING=0 QUIET_MAKE=1
```

`records/beast-build-openblas.sh` automates this end to end.

Three details that make it a drop-in:

- **`LIBSONAMEBASE=rocm-openblas`** — `Makefile.system:1592` defaults this to
  `openblas`; overriding it yields the exact filename **and** SONAME
  `librocm-openblas.so.0`, so no `patchelf`/rename is needed.
- **`C_LAPACK=1`** — torch needs 45 Fortran-style BLAS+LAPACK symbols
  (`sgemm_`, `dgesdd_`, `dgetrf_`, `sorgqr_`, `dormqr_`, `cgels_`, …). All 45
  are exported. (The C LAPACK also means gfortran is not required.)
- **`TARGET=SANDYBRIDGE` + `DYNAMIC_ARCH=0` + `NO_AVX2=1`** — this host's true
  ceiling: AVX + F16C, no AVX2/FMA.

### Result

`TARGET=SANDYBRIDGE DYNAMIC_ARCH=0 NO_AVX2=1` → **0 AVX2 and 0 FMA
instructions**, with **32,343 AVX (`%ymm`) instructions** actually used.
(Compare: a DYNAMIC_ARCH build keeps 665 AVX2 instructions in the SANDYBRIDGE
family alone.) Size drops 48 MB → 17 MB.

```bash
# installed over both lookup paths, torch's librocm-openblas stays the name
cp librocm-openblas_sandybridgep-r0.3.31.dev.so \
   .../_rocm_sdk_core/lib/host-math/lib/librocm-openblas.so.0
cp librocm-openblas_sandybridgep-r0.3.31.dev.so \
   .../_rocm_sdk_core/lib/librocm-openblas.so.0
```

`OPENBLAS_CORETYPE=PRESCOTT` was then **removed from `~/.profile`** — no runtime
coretype selection happens in a single-target build, so plain `import torch`
works with a clean environment.

### Measured (16-thread E5-2667 v2)

| Workload | Shipped DYNAMIC_ARCH (Prescott) | Rebuilt AVX | Gain |
| --- | --- | --- | --- |
| f32 n=4096 | 265.7 GFLOPS | **489.5** | 1.84x |
| f64 n=4096 | 274.7 GFLOPS | **464.2** | 1.69x |
| f32 n=2048 | 181.7 GFLOPS | **278.4** | 1.53x |
| f64 n=1024 | 33.9 GFLOPS | **131.1** | 3.87x |

### Verified after the rebuild

```
17/17 CPU ops OK (same set as above), 0 failures, no OPENBLAS_CORETYPE set
torch CPU f32 n=4096  489.5 GFLOPS correct=True
torch CPU f64 n=4096  464.2 GFLOPS correct=True
GPU suite still ALL PASSED (gfx900, 9.24 TFLOP/s fp16)
openblas_get_config = OpenBLAS 0.3.31.dev NO_AFFINITY SANDYBRIDGE MAX_THREADS=32
```

The original code path was written off as "pre-existing, use numpy" in the first
pass; that was wrong twice over — it was diagnosable, and then it was worth
rebuilding rather than merely working around.



## Rollback

Package list and apt sources as they were before the change:
- `records/beast-rocm-pkgs-before.txt` (unchanged) (251 entries)
- `records/beast-apt-sources-before.txt`

The AMD ROCm repo is still configured but **disabled** at
`/etc/apt/sources.list.d/rocm.list.disabled`.

### OpenBLAS rollback

| File | What it is |
| --- | --- |
| `/home/preston/librocm-openblas.so.0.DYNAMIC_ARCH.bak` | TheRock's original broken build (48 MB) |
| `/home/preston/librocm-openblas.so.0.prescott.bak` | Rebuilt SSE-only fallback (17 MB, works, no AVX) |

To revert to TheRock's shipped library:

```bash
V=~/rocm-therock/lib/python3.14/site-packages
cp ~/librocm-openblas.so.0.DYNAMIC_ARCH.bak \
   $V/_rocm_sdk_core/lib/host-math/lib/librocm-openblas.so.0
cp ~/librocm-openblas.so.0.DYNAMIC_ARCH.bak \
   $V/_rocm_sdk_core/lib/librocm-openblas.so.0
# then re-add OPENBLAS_CORETYPE=PRESCOTT to ~/.profile (see .profile.bak2-*)
```

Build tree kept for reproducibility: `~/sources/OpenBLAS` (pinned clone —
cloned 3rd-party repos live under `$HOME/sources/`), `/home/preston/ob-build/`
(both variants + logs), rebuild script `records/beast-build-openblas.sh`.
Note `librocm-openblas64.so.0` (the ILP64 variant) was left untouched — torch
does not link it.

Leftover: `/opt/rocm/core-7.14` retains 35 orphaned files (1.7 MB, mostly
`__pycache__`) that dpkg could not remove because the directories were non-empty.
Harmless; safe to `sudo rm -rf /opt/rocm` once you are satisfied.
