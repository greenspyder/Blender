"""Adiciona uma forma bilateral suave de flexão ao GLB existente, preservando o rig."""
import json, struct, sys, math
from pathlib import Path
raw=Path(sys.argv[1]).read_bytes()
jl=struct.unpack_from('<I',raw,12)[0]
doc=json.loads(raw[20:20+jl])
binary=bytearray(raw[28+jl:])
from rebind import rebind
rebind(doc, binary)
for mesh in doc['meshes']:
    names=mesh.get('extras',{}).get('targetNames',[])
    if not names or 'idle_knees' in names: continue
    mats=[doc['materials'][p['material']]['name'] for p in mesh['primitives'] if 'material' in p]
    dress=any('framboesa' in m.lower() for m in mats)
    shorts=any(any(token in m.lower() for token in ('cetim','sarja','viés','pétala','bolso')) for m in mats)
    for key in (['idle_knees','fabric_pull'] if dress or shorts else ['idle_knees']):
        names.append(key)
        if 'weights' in mesh: mesh['weights'].append(0)
        for p in mesh['primitives']:
            a=doc['accessors'][p['attributes']['POSITION']]
            v=doc['bufferViews'][a['bufferView']]
            start=v.get('byteOffset',0)+a.get('byteOffset',0)
            values=[]
            for i in range(a['count']):
                x,y,z=struct.unpack_from('<fff',binary,start+i*v.get('byteStride',12))
                t=min(1,max(0,(y-.08)/.87))
                if key=='idle_knees': values.append((.009*t,-.018*t,.023*math.sin(math.pi*t)**2*(.78 if x>0 else 1)))
                else:
                    band=math.exp(-((y-(1.32 if dress else 1.02))/.30)**2)
                    values.append((0,0,.055*band))
            off=len(binary)
            for xyz in values: binary.extend(struct.pack('<fff',*xyz))
            bid=len(doc['bufferViews'])
            doc['bufferViews'].append(dict(buffer=0,byteOffset=off,byteLength=len(binary)-off,target=34962))
            aid=len(doc['accessors'])
            doc['accessors'].append(dict(bufferView=bid,componentType=5126,count=len(values),type='VEC3',min=list(map(min,zip(*values))),max=list(map(max,zip(*values)))))
            p['targets'].append({'POSITION':aid})
doc['buffers'][0]['byteLength']=len(binary)
j=json.dumps(doc,separators=(',',':')).encode();j+=b' '*(-len(j)%4)
Path(sys.argv[2]).write_bytes(struct.pack('<4sII',b'glTF',2,28+len(j)+len(binary))+struct.pack('<I4s',len(j),b'JSON')+j+struct.pack('<I4s',len(binary),b'BIN\0')+binary)
