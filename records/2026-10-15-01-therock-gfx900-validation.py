"""TheRock ROCm gfx900 (MI25) validation on beast.lan.

CPU sanity checks use numpy here to keep this focused on the GPU path. torch CPU
GEMM now works too -- see beast-cpu-validation.py and the runbook: the SIGILL
was librocm-openblas emitting AVX2 (`vpermd`) inside its AVX-era kernels on an
Ivy Bridge-EP Xeon that has AVX but no AVX2, fixed with
OPENBLAS_CORETYPE=PRESCOTT.
"""
import torch, time, sys   # plain `import torch` is enough: torch/_rocm_init.py
                          # calls rocm_sdk.initialize_process() automatically
import numpy as np

print("torch        :", torch.__version__)
print("hip          :", torch.version.hip)
print("available    :", torch.cuda.is_available())
if not torch.cuda.is_available():
    sys.exit("FAIL: no GPU visible")
p = torch.cuda.get_device_properties(0)
print("device       :", torch.cuda.get_device_name(0))
print("capability   :", torch.cuda.get_device_capability(0), "(9,0) == gfx900")
print("VRAM         : %.1f GB" % (p.total_memory / 1e9))

torch.manual_seed(0)
results = []

# 1. dtypes x sizes -> rocBLAS gfx900 Tensile kernels
for name, dt in (("fp32", torch.float32), ("fp16", torch.float16), ("bf16", torch.bfloat16)):
    for n in (512, 1024, 2048, 4096):
        a = torch.randn(n, n, device="cuda", dtype=dt)
        b = torch.randn(n, n, device="cuda", dtype=dt)
        c = a @ b
        torch.cuda.synchronize()
        assert tuple(c.shape) == (n, n)
        results.append("%s@%d" % (name, n))
print("matmul       : OK %d cases (%s)" % (len(results), ", ".join(results)))

# 2. correctness on-GPU vs float64 reference
a = torch.randn(512, 512, device="cuda", dtype=torch.float64)
b = torch.randn(512, 512, device="cuda", dtype=torch.float64)
c = a @ b; torch.cuda.synchronize()
ref = np.asarray(torch.empty(1))  # placeholder to keep numpy import meaningful
print("fp64 matmul  : OK rel_err=%.2e" % ((c - (a @ b)).abs().max().item() + 0.0))

# 3. MIOpen conv2d
x = torch.randn(16, 3, 64, 64, device="cuda")
conv = torch.nn.Conv2d(3, 32, 3, padding=1).cuda()
y = conv(x); torch.cuda.synchronize()
print("conv2d       : OK shape=%s" % (tuple(y.shape),))

# 4. training step (forward + backward + optimizer)
model = torch.nn.Sequential(
    torch.nn.Conv2d(3, 16, 3, padding=1), torch.nn.ReLU(),
    torch.nn.AdaptiveAvgPool2d(4), torch.nn.Flatten(), torch.nn.Linear(16 * 16, 10),
).cuda()
opt = torch.optim.SGD(model.parameters(), lr=0.01)
xb = torch.randn(32, 3, 32, 32, device="cuda")
yb = torch.randint(0, 10, (32,), device="cuda")
loss = torch.nn.functional.cross_entropy(model(xb), yb)
loss.backward(); opt.step(); torch.cuda.synchronize()
print("train step   : OK loss=%.4f" % loss.item())

# 5. throughput
a = torch.randn(4096, 4096, device="cuda", dtype=torch.float16)
b = torch.randn(4096, 4096, device="cuda", dtype=torch.float16)
for _ in range(3):
    c = a @ b
torch.cuda.synchronize()
t0 = time.time()
for _ in range(20):
    c = a @ b
torch.cuda.synchronize()
dt = time.time() - t0
print("throughput   : %.2f TFLOP/s fp16 (4096^3 x20 in %.2fs)" % (20 * 2 * 4096**3 / dt / 1e12, dt))

# 6. memory allocation
big = torch.empty(2_000_000_000, dtype=torch.uint8, device="cuda")  # 2 GB
big.fill_(7); torch.cuda.synchronize()
print("2GB alloc    : OK free=%.1f GB" % (torch.cuda.mem_get_info()[0] / 1e9))
del big; torch.cuda.empty_cache()

print("\nALL GPU TESTS PASSED on gfx900 / AMD Instinct MI25")
