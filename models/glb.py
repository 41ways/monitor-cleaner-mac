import json, struct, io
def load(path):
    b = open(path, 'rb').read()
    L = struct.unpack('<I', b[12:16])[0]
    j = json.loads(b[20:20 + L])
    off = 20 + L
    BL = struct.unpack('<I', b[off:off + 4])[0]
    bin_ = b[off + 8: off + 8 + BL]
    def acc(i):
        a = j['accessors'][i]; bv = j['bufferViews'][a['bufferView']]
        start = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
        n = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3}[a['type']]
        fmt = {5126: 'f', 5123: 'H', 5125: 'I'}[a['componentType']]
        size = struct.calcsize(fmt)
        stride = bv.get('byteStride', size * n)
        out = []
        for k in range(a['count']):
            s = start + k * stride
            v = struct.unpack('<' + fmt * n, bin_[s:s + size * n])
            out.append(v if n > 1 else v[0])
        return out
    p = j['meshes'][0]['primitives'][0]
    pos = acc(p['attributes']['POSITION']); nor = acc(p['attributes']['NORMAL']); uv = acc(p['attributes']['TEXCOORD_0'])
    idx = acc(p['indices'])
    img = j['images'][0]; bv = j['bufferViews'][img['bufferView']]
    png = bin_[bv.get('byteOffset', 0): bv.get('byteOffset', 0) + bv['byteLength']]
    return pos, nor, uv, idx, png, img.get('mimeType')
