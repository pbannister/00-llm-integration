"""Exercise the CPU op set most likely to reach OpenBLAS, for coretype A/B testing."""
import sys, torch
import torch.nn.functional as F
fails = []
def check(label, fn):
    try:
        fn(); print("  OK   %s" % label, flush=True)
    except Exception as e:
        print("  FAIL %s (%s)" % (label, e), flush=True); fails.append(label)
a2 = torch.randn(1024, 1024)
check("matmul 2d 1024",        lambda: a2 @ a2)
check("matmul 2d 4096",        lambda: torch.randn(4096,4096) @ torch.randn(4096,4096))
check("addmm 64x512@512x512",  lambda: torch.addmm(torch.zeros(64,512), torch.randn(64,512), torch.randn(512,512)))
check("F.linear 64x512",       lambda: F.linear(torch.randn(64,512), torch.randn(512,512), torch.randn(512)))
check("F.linear no bias",      lambda: F.linear(torch.randn(64,512), torch.randn(512,512), None))
check("F.linear batch=1",      lambda: F.linear(torch.randn(1,512), torch.randn(512,512), torch.randn(512)))
check("nn.Linear fwd",         lambda: torch.nn.Linear(512,512)(torch.randn(64,512)))
check("nn.Linear fwd+bwd",     lambda: torch.nn.Linear(512,512)(torch.randn(64,512)).sum().backward())
check("conv2d fwd",            lambda: torch.nn.Conv2d(3,8,3,padding=1)(torch.randn(2,3,32,32)))
check("conv2d fwd+bwd",        lambda: torch.nn.Conv2d(3,8,3,padding=1)(torch.randn(2,3,32,32)).sum().backward())
check("bmm 3d",                lambda: torch.bmm(torch.randn(8,512,512), torch.randn(8,512,512)))
check("einsum",                lambda: torch.einsum("ij,jk->ik", torch.randn(512,512), torch.randn(512,512)))
check("sdpa attention",        lambda: F.scaled_dot_product_attention(torch.randn(2,8,64,64), torch.randn(2,8,64,64), torch.randn(2,8,64,64)))
check("layernorm",             lambda: torch.nn.LayerNorm(512)(torch.randn(64,512)))
check("softmax",               lambda: F.softmax(torch.randn(64,512), dim=1))
check("conv_transpose",        lambda: torch.nn.ConvTranspose2d(8,3,3)(torch.randn(2,8,16,16)))
check("GRU",                   lambda: torch.nn.GRU(64,64)(torch.randn(10,4,64)))
print("RESULT:", "FAILURES=%s" % fails if fails else "ALL_OK")
sys.exit(1 if fails else 0)
