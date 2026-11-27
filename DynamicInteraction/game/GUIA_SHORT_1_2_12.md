# Rosé 1.2.12 — Retirar o short por baixo

Extraia o ZIP em uma nova pasta e importe `project.godot` na Godot. Execute a cena principal e enquadre a personagem da cintura aos pés. O mesmo projeto funciona com os modos **Desktop** e **Touchscreen**.

| Ação | Android | PC |
| --- | --- | --- |
| Pegar pelo cós | Selecione **Agarrar**, toque na borda superior do short até ver **Cós agarrado** e mantenha o dedo na tela. | Clique na borda superior do short até ver **Cós agarrado**. |
| Tirar por baixo | Arraste para baixo e sustente o gesto até aparecer **Short na mão**. | Mova o cursor para baixo e aguarde **Short na mão**. |
| Largar | Levante o dedo. | Clique novamente. |
| Vestir | Use **Recolocar**. | Use **Recolocar**. |

O tecido desce, passa pela ponta dos pés e continua visível ao cair no chão. Se soltar antes de liberar os pés, o short volta ao lugar. Quando ambas as peças estiverem fora do corpo, **Recolocar** veste uma de cada vez, começando pela mais recente. A camisola continua saindo para cima, pela alça.

## Como funciona e como editar

- `direct/direct_lab.gd` usa o triângulo visível sob o toque para distinguir o cós do restante da peça. A função `update_garment_pull()` converte o deslocamento vertical em progresso. Ajuste `travel` para experimentar um gesto mais longo ou mais curto.
- `direct/short_pull.gd` define a faixa do cós na malha em repouso e o trajeto de descida e saída em `path()`. A passagem pelos pés tem um limite de segurança em `has_clearance()`. Ao substituir o modelo, ajuste a altura do cós em `contains_hit()`, o trajeto e os colisores de pernas e pés em `update_short_collisions()`, na cena principal.
- `direct/garment_pull.gd` e `direct/garment_cage.gd` compartilham a simulação entre camisola e short. Os bolsos são conectados ao tecido pela mesma simulação. A malha deformada é usada do início da puxada até o repouso no piso e durante o retorno.

## Validação

O teste `tests/short_pull_test.gd` envia eventos de toque e mouse à cena principal. Ele verifica a seleção pelo cós, a direção do arraste, o retorno ao soltar cedo, a posição da mão, a passagem pelos pés, a queda com os bolsos, a recolocação e a preservação da camisola e das pantufas.

No Android, repita pela frente e de três quartos. Faça primeiro um arraste curto e solte. Depois faça um arraste completo e aguarde a confirmação antes de soltar. Observe se os pés atravessam o tecido e se os bolsos permanecem presos. Por fim, use **Recolocar** e repita com a camisola.

Os pés são fixos no rig atual. A trajetória conduz o short para a frente na altura dos tornozelos, com colisores aproximados para pernas e pantufas. A validação automatizada usa Godot 4.7.2 sem interface. O comportamento visual e a sensação do gesto ainda precisam ser conferidos no Android.
