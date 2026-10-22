"""End-to-end LAPACK/BLAS check on beast.lan after the OpenBLAS rebuild.

Exercises the Fortran-style BLAS+LAPACK symbols torch requires (sgemm_,
dgesdd_, dgetrf_, sorgqr_, sgels_, dpotrf_, dsyev_ ...) plus the GPU path.
Run inside the venv:  source ~/rocm-therock/bin/activate && python this.py
"""
import torch

m = torch.nn.Linear(1024, 1024)
y = m(torch.randn(256, 1024)); y.sum().backward()
print("CPU Linear fwd+bwd : OK")
print("CPU SVD (LAPACK)   :", tuple(torch.linalg.svd(torch.randn(256, 256))[1].shape))
print("CPU inverse        :", tuple(torch.linalg.inv(torch.randn(256, 256)).shape))
print("CPU QR             :", tuple(torch.linalg.qr(torch.randn(256, 256))[0].shape))
print("CPU lstsq (gels)   :", tuple(torch.linalg.lstsq(torch.randn(128, 64), torch.randn(128, 8)).solution.shape))

M = torch.randn(64, 64)
spd = M @ M.T + 64 * torch.eye(64)   # genuinely positive definite
print("CPU cholesky       :", tuple(torch.linalg.cholesky(spd).shape))
print("CPU symeig         :", tuple(torch.linalg.eigh(spd)[0].shape))

a = torch.randn(2048, 2048, device="cuda", dtype=torch.float16)
print("GPU                :", torch.cuda.get_device_name(0), tuple((a @ a).shape))
print("torch              :", torch.__version__)
