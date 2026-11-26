"""Recalibra o bind dos braços no espaço glTF, com base na superfície da malha 1.1."""
import struct
import numpy as np


def rebind(doc, binary):
    def array(index):
        acc = doc['accessors'][index]
        view = doc['bufferViews'][acc['bufferView']]
        dtype = np.dtype({5121: 'u1', 5123: '<u2', 5126: '<f4'}[acc['componentType']])
        width = {'VEC4': 4, 'VEC3': 3, 'MAT4': 16}[acc['type']]
        offset = view.get('byteOffset', 0) + acc.get('byteOffset', 0)
        return np.ndarray((acc['count'], width), dtype, binary, offset,
                          (view.get('byteStride', width * dtype.itemsize), dtype.itemsize))

    skin = doc['skins'][0]
    inverse = array(skin['inverseBindMatrices'])
    names = [doc['nodes'][n]['name'] for n in skin['joints']]
    rest = {name: np.linalg.inv(row.reshape(4, 4).T) for name, row in zip(names, inverse)}
    for side, sign in [('L', -1), ('R', 1)]:
        parent = 'Spine'
        for segment, (x, y, z) in [('Upper', (.214, 1.606, -.056)),
                                    ('Fore', (.422, 1.319, -.087)),
                                    ('Palm', (.568, 1.072, -.08))]:
            name = segment + side
            index = names.index(name)
            rest[name][:3, 3] = (sign * x, y, z)
            node = doc['nodes'][skin['joints'][index]]
            node['translation'] = (np.linalg.inv(rest[parent]) @ rest[name])[:3, 3].tolist()
            inverse[index] = np.linalg.inv(rest[name]).T.flatten()
            parent = name

    def smooth(t):
        t = np.clip(t, 0, 1)
        return t * t * (3 - 2 * t)

    body = next(n for n in doc['nodes'] if n['name'] == 'Body')
    for prim in doc['meshes'][body['mesh']]['primitives']:
        attrs = prim['attributes']
        xyz, joints, weights = (array(attrs[key]) for key in ('POSITION', 'JOINTS_0', 'WEIGHTS_0'))
        for i, (signed_x, y, z) in enumerate(xyz):
            x = abs(signed_x)
            side = 'L' if signed_x < 0 else 'R'
            # Abaixo da axila, a margem lateral isola o braço do quadril.
            mask = smooth((x - (.167 + .11 * smooth((1.52-y)/.23))) / .095)
            if mask <= 0 or y < .81 or (x < .30 and y < 1.29):
                continue
            elbow = smooth((x - .365) / .115)
            wrist = smooth((x - .537) / .064)
            entries = [('Spine', 1-mask), ('Upper'+side, mask*(1-elbow)),
                       ('Fore'+side, mask*elbow*(1-wrist)), ('Palm'+side, mask*elbow*wrist)]
            joints[i] = [names.index(n) for n, _ in entries]
            weights[i] = [w for _, w in entries]
