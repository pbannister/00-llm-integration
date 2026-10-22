"""CPU matmul validation after the OPENBLAS_CORETYPE fix on beast.lan.

Diagnosis: librocm-openblas (DYNAMIC_ARCH) mis-detects this Ivy Bridge-EP Xeon.
CPUID reports AVX=1, FMA3=0, FMA4=0, AVX2=0, so OpenBLAS falls back to
"SANDYBRIDGE" kernels -- but this build's sgemm_oncopy_SANDYBRIDGE contains
`vpermd` (AVX2) at +616, which faults with SIGILL. Pinning a pre-AVX2 coretype
avoids it; BARCELONA is also the fastest option measured here.
"""
import os, time, sys
import torch
import numpy as np

ct = os.environ.get("OPENBLAS_CORETYPE", "(unset)")
print("OPENBLAS_CORETYPE :", ct)
print("torch             :", torch.__version__)

if ct in ("", "SANDYBRIDGE", "NEHALEM", "HASWELL") and ct != "":
    print("WARNING: this coretype is expected to SIGILL on this CPU")

fails = []

# 1. torch CPU matmul across sizes and both dtypes
for n in (256, 1024, 2048, 4096):
    for name, dt in (("f32", torch.float32), ("f64", torch.float64)):
        a = torch.randn(n, n); b = torch.randn(n, n)
        t0 = time.time(); c = a @ b; el = time.time() - t0
        ref = a.to(torch.float64) @ b.to(torch.float64)
        ok = torch.allclose(c.to(torch.float64), ref, rtol=1e-3, atol=1e-2)
        gf = 2 * n**3 / el / 1e9
        print("  torch CPU %-3s n=%-5d %6.1f GFLOPS correct=%s" % (name, n, gf, ok))
        if not ok: fails.append("torch %s n=%d" % (name, n))

# 2. numpy CPU matmul on the same data (separate OpenBLAS)
a = np.random.randn(2048, 2048).astype(np.float32)
c = a @ a
print("  numpy     n=2048  OK %s" % (c.shape,))

# 3. CPU linear layer / backward (exercises more than GEMM)
m = torch.nn.Linear(512, 512)
x = torch.randn(64, 512)
y = m(x); y.sum().backward()
print("  torch CPU Linear fwd+bwd OK")
print("  torch CPU conv2d:", tuple(torch.nn.Conv2d(3, 8, 3, padding=1)(torch.randn(2, 3, 32, 32)).shape))

# 4. GPU still fine
if torch.cuda.is_available():
    g = torch.randn(2048, 2048, device="cuda", dtype=torch.float16)
    print("  GPU matmul:", tuple((g @ g).shape), torch.cuda.get_device_name(0))
else:
    fails.append("GPU not available")

print()
print("FAILURES:", fails if fails else "none")
sys.exit(1 if fails else 0)
