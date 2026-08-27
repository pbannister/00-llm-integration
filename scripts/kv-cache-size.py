import struct, sys, os

def read_string(f):
    n = struct.unpack('<Q', f.read(8))[0]
    return f.read(n).decode('utf-8')

def read_value(f, t):
    if t == 0: return struct.unpack('<B', f.read(1))[0]
    if t == 1: return struct.unpack('<b', f.read(1))[0]
    if t == 2: return struct.unpack('<H', f.read(2))[0]
    if t == 3: return struct.unpack('<h', f.read(2))[0]
    if t == 4: return struct.unpack('<I', f.read(4))[0]
    if t == 5: return struct.unpack('<i', f.read(4))[0]
    if t == 6: return struct.unpack('<f', f.read(4))[0]
    if t == 7: return struct.unpack('<?', f.read(1))[0]
    if t == 8: return read_string(f)
    if t == 9:
        typ = struct.unpack('<I', f.read(4))[0]
        n = struct.unpack('<Q', f.read(8))[0]
        return [read_value(f, typ) for _ in range(n)]
    if t == 10: return struct.unpack('<Q', f.read(8))[0]
    if t == 11: return struct.unpack('<q', f.read(8))[0]
    if t == 12: return struct.unpack('<d', f.read(8))[0]
    raise ValueError(t)

def scalar(v):
    return v[0] if isinstance(v, list) and v else v

def meta(path):
    out = {}
    with open(path,'rb') as f:
        assert f.read(4) == b'GGUF'
        f.read(4); f.read(8)
        nkv = struct.unpack('<Q', f.read(8))[0]
        for _ in range(nkv):
            k = read_string(f)
            t = struct.unpack('<I', f.read(4))[0]
            v = read_value(f, t)
            out[k] = v
    return out

for path in sys.argv[1:]:
    m = meta(path)
    arch = m.get('general.architecture','?')
    def key(k): return f"{arch}.{k}"
    layers = scalar(m.get(key('block_count'), 0))
    kv_heads = scalar(m.get(key('attention.head_count_kv'), 0))
    n_embd = scalar(m.get(key('embedding_length'), 0))
    heads = scalar(m.get(key('attention.head_count'), 0))
    head_dim = scalar(m.get(key('attention.head_dim'))) or (n_embd // heads if heads else 0)
    max_ctx = scalar(m.get(key('context_length'), 0))
    bpt_f16 = layers * kv_heads * head_dim * 2 * 2
    bpt_q8  = layers * kv_heads * head_dim * 2 * 1
    bpt_q4  = layers * kv_heads * head_dim * 2 * 0.5
    name = os.path.basename(path)
    for s in ('-00001-of-00002','-00001-of-00003','-00001-of-00004'):
        name = name.replace(s,'')
    print(f"{name:46s} arch={arch:<9s} L={layers:<4d} kv={kv_heads:<3d} hd={head_dim:<4d} ctx={max_ctx:<7d} KV/tok f16={bpt_f16/1048576:.3f}MB q8={bpt_q8/1048576:.3f}MB q4={bpt_q4/1048576:.3f}MB")
