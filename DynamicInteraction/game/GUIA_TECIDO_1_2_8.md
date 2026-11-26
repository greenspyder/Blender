# Rosé 1.2.8 · Tecido durante a retirada

Use o mesmo projeto no PC e no Android. Importe `project.godot`, execute e enquadre a personagem inteira. No Android, selecione **Agarrar**. No PC, clique na alça. Puxe para cima e mantenha a pega enquanto a barra ainda estiver passando pelos ombros. Quando aparecer **Camisola na mão**, solte para deixar a peça cair. **Recolocar** leva a peça de volta ao corpo.

Se você soltar antes de o tecido passar, a peça volta ao lugar. Um arrasto rápido que chega ao topo antes da própria roupa deixa de completar a retirada automaticamente. O botão **Remover** ainda oferece um acionamento assistido quando a peça está agarrada.

## O que mudou

Antes, o movimento aplicava uma transformação ao conjunto da camisola. O fim do gesto mudava imediatamente o conjunto para o estado de peça retirada. A versão nova simula uma malha reduzida de partículas, conectadas por restrições de comprimento e dobra. A alça reage primeiro. A barra tem atraso e os pontos restantes redistribuem a tensão pelas conexões. A retirada só muda de estado depois que a barra passa acima do limite dos ombros. A peça preserva as posições e os deslocamentos anteriores ao trocar da puxada para a queda.

A trajetória de retirada continua guiada. Volumes elipsoidais aproximam o tronco, a cabeça e os ombros. A aproximação permite dobras durante a travessia, com espaço para o gesto em uma malha de jogo. A queda usa gravidade, arrasto e piso. As colisões seguem aproximadas em pontas de cabelo, braços e dedos, e o tecido ainda pode atravessar a si mesmo em dobras fechadas.

| Arquivo | Onde ajustar |
|---|---|
| `direct/garment_cage.gd` | `CELL` regula a resolução. `ITERATIONS` controla quantas vezes as ligações são corrigidas por passo. `triangle` e `connect_triangle_edge` montam ligações de estiramento e dobra. |
| `direct/garment_pull.gd` | `write_guide` distribui o atraso pela altura da malha. `has_clearance` determina quando toda a peça está livre. `advance` controla retirada, queda e recolocação. |
| `direct/direct_lab.gd` | `update_garment_collisions` posiciona os volumes de colisão usando o esqueleto animado. |

## Checagem no celular

1. Puxe devagar e pare na metade sem soltar. A barra deve continuar se ajustando à alça e aos ombros.
2. Solte durante a passagem e repita até **Camisola na mão**. Compare o retorno da primeira puxada com a queda da segunda.
3. Repita de três quartos e observe o contato com cabelo e ombros. Teste **Recolocar** com a peça em queda e depois com a peça estacionada no piso.
4. Abra **Física** para acompanhar FPS e tempo do passo no seu aparelho.

Os testes verificam que a captura começa na mesma pose, que o movimento da barra difere da alça, que as partículas não saltam ao liberar a peça e que a camisola permanece no piso. Uma inspeção da geometria em quadros amostrados foi feita no Blender a partir das posições calculadas na Godot. Essa inspeção e os testes headless não medem a taxa de quadros nem a sensação do toque em Android físico.
