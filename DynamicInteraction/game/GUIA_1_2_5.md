# Rosé 1.2.5 · Retirar a camisola pela alça

Extraia o ZIP em uma pasta nova, importe `project.godot` no Godot para Android e execute o projeto.

1. Selecione **Agarrar** na barra superior e toque na alça visível, junto ao ombro.
2. Arraste o mesmo dedo **para baixo** até aparecer **Solte para retirar a camisola**.
3. Levante o dedo. A camisola e o laço saem juntos. A camada interna preta aparece e o short continua vestido.
4. Toque em **Recolocar** para restaurar a camisola. **Reiniciar** também restaura as peças.

Puxe para cima até sair da faixa de confirmação ou solte após um puxão curto para conservar a peça. Cancelar o toque, perder o foco ou trocar de modo também cancela o gesto. No PC, o botão de roupa continua disponível ao agarrar uma peça.

## Causa e correção

Na 1.2.4, o raycast identificava a alça e o solver aplicava tração, mas a soltura só encerrava o vínculo. A remoção acontecia pelo botão separado. Agora o fim de um gesto válido chama a mesma operação de retirada do botão. O gatilho depende de uma alça agarrada, movimento vertical na tela e soltura voluntária. A retirada libera todos os vínculos daquela peça, preservando os vínculos com outros objetos.

Em `direct/strap.gd`, a seleção usa o viés da malha e sua posição de referência no rig. Quando o toque passa perto, o seletor experimenta pontos vizinhos e confirma com um raio que a alça está visível. Isso evita selecionar a alça atrás do cabelo ou do corpo. Para ajustar o alcance de seleção, altere `NEAR_PIXELS`. Para mudar a distância do gesto, ajuste o divisor de `g.pull` em `direct/direct_lab.gd`.

A retirada troca a visibilidade das malhas da camisola e do laço. A tração durante o gesto continua usando a deformação da peça. A saída da roupa não simula o tecido deslizando sobre os ombros. A camada interna preta de prova usa a malha e os pesos da própria Rosé. Os limites de seu material estão em `direct/base_layer.gdshader`. A peça original do BUBUROSTO está em um arquivo Blender 5.1 que a instalação 4.3 usada aqui não conseguiu ler.

## Teste manual no Android

- Faça a retirada pela alça de frente e de três quartos. Experimente começar ligeiramente ao lado da alça.
- Confirme que arrastar o ombro fora da área da alça não retira a roupa. Faça um puxão curto e depois um longo sem soltar. A peça só sai depois da soltura longa.
- Recoloque e repita. Confira a aparência da camada interna e a saída do laço.
- Puxe até confirmar e troque de aplicativo antes de soltar. A peça deve continuar vestida ao voltar.

O teste automatizado injeta eventos de toque e arraste no viewport para localizar a alça em três ângulos, validar a tolerância, preservar a peça em puxões curtos e cancelados, retirar a camisola e recolocá-la pelo botão. A aparência em movimento e o gesto no aparelho físico ainda dependem da prova manual.
