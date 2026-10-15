"""Build the original decorative glTF 2.0 binary import probe, with stdlib only."""
from pathlib import Path
import json
import struct

faces = [
    ([( -.5,-.5,.5),(.5,-.5,.5),(.5,.5,.5),(-.5,.5,.5)], (0,0,1)),
    ([(.5,-.5,-.5),(-.5,-.5,-.5),(-.5,.5,-.5),(.5,.5,-.5)], (0,0,-1)),
    ([(.5,-.5,.5),(.5,-.5,-.5),(.5,.5,-.5),(.5,.5,.5)], (1,0,0)),
    ([(-.5,-.5,-.5),(-.5,-.5,.5),(-.5,.5,.5),(-.5,.5,-.5)], (-1,0,0)),
    ([(-.5,.5,.5),(.5,.5,.5),(.5,.5,-.5),(-.5,.5,-.5)], (0,1,0)),
    ([(-.5,-.5,-.5),(.5,-.5,-.5),(.5,-.5,.5),(-.5,-.5,.5)], (0,-1,0)),
]
positions, normals, indices = [], [], []
for vertices, normal in faces:
    base = len(positions)
    positions.extend(vertices)
    normals.extend([normal] * 4)
    indices.extend([base,base+1,base+2,base,base+2,base+3])
pos_data = struct.pack('<72f', *(v for p in positions for v in p))
norm_data = struct.pack('<72f', *(v for n in normals for v in n))
index_data = struct.pack('<36H', *indices)
binary = pos_data + norm_data + index_data
root = {
    'asset': {'version': '2.0', 'generator': 'Do Vostrebovaniya stdlib GLB probe'},
    'scene': 0, 'scenes': [{'nodes': [0]}],
    'nodes': [{'name': 'OriginalCrateProbe', 'mesh': 0}],
    'meshes': [{'name': 'CrateProbe', 'primitives': [{'attributes': {'POSITION': 0, 'NORMAL': 1}, 'indices': 2, 'material': 0}]}],
    'materials': [{'name': 'WornKraft', 'pbrMetallicRoughness': {'baseColorFactor': [.60,.48,.32,1.0], 'roughnessFactor': .86, 'metallicFactor': 0.0}}],
    'buffers': [{'byteLength': len(binary)}],
    'bufferViews': [
        {'buffer':0,'byteOffset':0,'byteLength':len(pos_data),'target':34962},
        {'buffer':0,'byteOffset':len(pos_data),'byteLength':len(norm_data),'target':34962},
        {'buffer':0,'byteOffset':len(pos_data)+len(norm_data),'byteLength':len(index_data),'target':34963}],
    'accessors': [
        {'bufferView':0,'componentType':5126,'count':24,'type':'VEC3','min':[-.5,-.5,-.5],'max':[.5,.5,.5]},
        {'bufferView':1,'componentType':5126,'count':24,'type':'VEC3'},
        {'bufferView':2,'componentType':5123,'count':36,'type':'SCALAR'}],
}
json_data = json.dumps(root,separators=(',',':')).encode('utf-8')
json_data += b' ' * (-len(json_data) % 4)
binary += b'\0' * (-len(binary) % 4)
length = 12 + 8 + len(json_data) + 8 + len(binary)
result = struct.pack('<III',0x46546C67,2,length)
result += struct.pack('<II',len(json_data),0x4E4F534A) + json_data
result += struct.pack('<II',len(binary),0x004E4942) + binary
Path(__file__).with_name('crate_probe.glb').write_bytes(result)
print(f'Original GLB probe: {len(result)} bytes; 24 vertices; 12 triangles.')
