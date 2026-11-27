extends RefCounted
const BASES := ["Em pé","Sentada","Agachada","Inclinação","Caminhada","Personalizada"]
# Máscaras semânticas. Somente o compositor escreve a referência final.
const ACTIONS := {
    "flex": {"name":"Flexão cíclica","category":"Movimento cíclico","mask":["pelvis","lumbar"],"blocked":[4]},
    "sway": {"name":"Balanço lateral","category":"Movimento cíclico","mask":["pelvis","chest"],"blocked":[4]},
    "arms": {"name":"Elevar braços","category":"Movimento complementar","mask":["upper_l","upper_r"] ,"blocked":[]},
    "head": {"name":"Olhar ao redor","category":"Movimento complementar","mask":["head"],"blocked":[]},
}
