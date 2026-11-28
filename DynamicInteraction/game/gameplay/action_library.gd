extends RefCounted

const BASES := ["Em pé","Sentada","Agachada","Inclinação","Caminhada","Personalizada"]
const PARAMETERS := {"intensity":Vector2(0,1), "amplitude":Vector2(0,1), "speed":Vector2(.1,3)}
# Limites da pelve em comprimentos de perna, rotações em graus. Maior prioridade recebe a margem primeiro.
const ACTIONS := {
    "squat":{"name":"Agachar","category":"Movimento cíclico","mask":["pelvis"],"priority":80,"requires":"support","strategy":"leg_travel","limit":.29},
    "flex":{"name":"Flexão cíclica","category":"Movimento cíclico","mask":["pelvis","lumbar"],"priority":50,"requires":"support","strategy":"flexion","limit":.09},
    "sway":{"name":"Balanço lateral","category":"Movimento cíclico","mask":["pelvis","chest"],"priority":40,"requires":"support","strategy":"weight_shift","limit":.035},
    "arms":{"name":"Elevar braços","category":"Movimento complementar","mask":["upper_l","upper_r"],"priority":30,"requires":"muscle","strategy":"shoulders","limit":25.},
    "head":{"name":"Olhar ao redor","category":"Movimento complementar","mask":["head"],"priority":20,"requires":"muscle","strategy":"look","limit":24.},
}
