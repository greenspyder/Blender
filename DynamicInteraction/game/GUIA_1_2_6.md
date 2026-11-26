# Rosé 1.2.6 · Retirar a camisola por cima

Extraia o ZIP, importe `project.godot` no Godot para Android e execute. Selecione **Agarrar**, toque na alça junto ao ombro e puxe para cima. A alça começa a se mover, o braço daquele lado sobe primeiro e o outro acompanha conforme a peça passa pelos ombros.

Solte no meio da puxada para ver a peça voltar ao lugar. Continue até **Camisola na mão** para separar a peça do corpo. Ainda com o dedo na tela, mova a camisola. Ao soltar, ela cai e fica visível no chão. **Recolocar** anima a volta da peça do chão ao corpo. O botão também funciona antes de a peça tocar no chão. **Reiniciar** restaura imediatamente a pose vestida.

A camada preta provisória da 1.2.5 foi removida. O short é outra peça e segue vestido ao retirar a camisola.

## Alterar o comportamento

| Arquivo | Ajuste |
|---|---|
| `direct/direct_lab.gd` | `update_garment_pull` converte a distância vertical do dedo em progresso. O limiar inicial evita iniciar a subida em um toque. |
| `direct/garment_pull.gd` | `path` define a trajetória acima e à frente dos ombros. `arm_weight` define em que momento cada braço começa a subir. `advance` coordena subida, recuo, separação, queda e recolocação. |
| `mechanics/posture.gd` | `wardrobe_lift` comanda um arco lateral de cada punho. O IK existente preserva comprimentos dos ossos, flexão dos cotovelos e recuperação. |
| `direct/garment_pull.gdshader` | Deforma a malha capturada no início do gesto. A barra se recolhe e pende da alça, e a oscilação diminui à medida que a peça desacelera. |

A posição da mão agarrada fica vinculada ao ponto de captura. Para preservar o movimento quando a peça se solta, a mesma malha que estava subindo continua em cena. A queda tem gravidade, arrasto e contato aproximado com o piso. A peça pousada pode ser recuperada pelo botão **Recolocar**.

A deformação usa uma trajetória procedural e a colisão é aproximada. Não há simulação completa de tecido, autocolisão ou detecção de contato individual entre a camisola e cada articulação. Em zoom alto, parte da trajetória pode sair do enquadramento. Para conferir no Android, comece com a personagem inteira visível. Compare um puxão lento, um incompleto e um rápido, depois teste a soltura e a recolocação em vista frontal e em três quartos.

Os testes automatizados verificam captura da alça, braço do mesmo lado subindo primeiro, posição da mão na peça, retorno após puxão incompleto ou cancelado, permanência da peça no chão e recolocação. A percepção de naturalidade no aparelho físico segue sujeita ao roteiro acima.
