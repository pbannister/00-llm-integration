#!/usr/bin/env bash
# Rebuild OpenBLAS as a drop-in replacement for ROCm/TheRock's
# librocm-openblas.so.0, with AVX2 permanently removed.
#
# Why: TheRock builds OpenBLAS from commit 18638c70eff1f0d08e2833b2724deaa128d6a334
# with -DDYNAMIC_ARCH=ON -DTARGET=HASWELL. On this Ivy Bridge-EP Xeon
# (AVX=1, AVX2=0, FMA3=0, FMA4=0) the DYNAMIC_ARCH dispatcher picks the
# SANDYBRIDGE family, whose AVX-era kernels nonetheless contain AVX2
# instructions (vpermd et al) -> SIGILL. Building with DYNAMIC_ARCH off and a
# single AVX2-free target removes the broken kernels entirely.
#
# Two variants are produced so we can measure the cost:
#   prescott : TARGET=PRESCOTT    (SSE only) -- known-good at runtime
#   sandy    : TARGET=SANDYBRIDGE NO_AVX2=1  -- AVX if it builds clean
#
# Usage: build-openblas.sh
set -euo pipefail

SRC=/home/preston/sources/OpenBLAS
OUT=/home/preston/ob-build
JOBS=${JOBS:-$(( $(nproc) / 2 ))}   # half the cores by default; heavy builds have reset this box
export OPENBLAS_CORETYPE=      # never influence our own build
unset OPENBLAS_CORETYPE || true
unset OPENBLAS_NUM_THREADS || true

mkdir -p "$OUT"

build_variant() {
  local name="$1"; shift
  echo "=================================================================="
  echo "=== BUILD VARIANT: $name   ($*)"
  echo "=================================================================="
  local dir="$OUT/$name"
  rm -rf "$dir"; mkdir -p "$dir"
  # OpenBLAS' build system wants a pristine-ish tree; copy sources per variant.
  rsync -a --exclude '.git' "$SRC/" "$dir/src/"
  # LIBSONAMEBASE=rocm-openblas makes OpenBLAS emit librocm-openblas.so.0
  # (Makefile.system:1592 sets the default "openblas"). This is the exact
  # SONAME TheRock's package ships, so no patchelf/rename is needed.
  ( cd "$dir/src" && make "${@}" -j"$JOBS" \
      LIBSONAMEBASE=rocm-openblas \
      BUILD_TESTING=0 QUIET_MAKE=1 \
      > "$dir/build.log" 2>&1 ) || {
        echo "  !! build FAILED for $name (tail of log):"
        tail -25 "$dir/build.log" | sed 's/^/     /'
        return 1
      }
  echo "  build OK:"
  ls -la "$dir"/src/librocm-openblas*.so* 2>/dev/null | sed 's/^/     /'
  ls -la "$dir"/src/libopenblas*.so* 2>/dev/null | sed 's/^/     /'
}

echo "### host: $(uname -srm)"; echo "### jobs: $JOBS"

# Single-target, DYNAMIC_ARCH off. NO_AVX2=1 is belt-and-braces: it feeds
# -DNO_AVX2 into the kernel-selection logic. The decisive factor is
# DYNAMIC_ARCH=0 + TARGET=PRESCOTT, which drops every AVX2-bearing kernel from
# the binary (a survey of the shipped librocm-openblas found AVX2 in
# SANDYBRIDGE=665, HASWELL=702, BARCELONA=630, NEHALEM=586 instructions, and
# PRESCOTT=0).
build_variant prescott TARGET=PRESCOTT DYNAMIC_ARCH=0 NO_LAPACK=0 C_LAPACK=1 USE_THREAD=1 NO_AVX2=1 NO_AVX512=1

echo
echo "=== AVAILABLE ARTIFACTS ==="
find "$OUT" -name 'lib*openblas*.so*' -printf '%p %s\n' 2>/dev/null
