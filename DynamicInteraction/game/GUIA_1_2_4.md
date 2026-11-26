# Rosé 1.2.4 · Restrições e resistência

Extraia o ZIP em uma pasta nova e importe `project.godot` no Godot para Android. Na tela principal, **Bancada** abre os objetos de teste, **Tecidos** abre as amostras e **Física** mostra o diagnóstico da mão ativa. **Ajustes** abre os parâmetros. **Salvar perfil** aplica o perfil às próximas execuções e às outras bancadas quando forem abertas.

## O que fazia a mão escapar

Na 1.2.3, o arraste atualizava `g.point` e chamava `place_hand` imediatamente. A etapa de física também redesenhava a mão em `g.point`. Esse ponto vinha do dedo projetado no plano da câmera. O corpo e o objeto já tinham limites, mas a mão desenhada ignorava o ponto de contato depois da seleção.

| Posição | Como funciona |
|---|---|
| Desejada | O dedo projetado no plano capturado no primeiro toque. Continua indo para onde você arrastar. |
| Âncora | Ponto no material que foi agarrado. Em Rosé, acompanha o triângulo da malha animada. No bloco e na alavanca, fica em coordenadas locais da peça. |
| Efetiva | Posição onde a mão é desenhada. Durante o vínculo, acompanha a âncora. Ao soltar, a mão fica na última posição efetiva até começar outro gesto. |
| Resistência | A distância entre intenção e âncora gera uma força de mola, com teto. A velocidade da peça reduz a força na direção do movimento por amortecimento. |

Em **Tocar**, a mão continua acompanhando o dedo no plano inicial, com uma varredura contra as zonas corporais para bloquear ou deslizar em obstáculos. Em **Agarrar**, a diferença entre o dedo e a mão fica visível ao puxar além do limite. A soltura de cada dedo é independente. O modo espelhado continua disponível. No PC, os controles anteriores continuam disponíveis.

## Bloco e alavanca

O bloco desliza sobre um trilho, com paredes nas duas extremidades. A alavanca gira em Z em torno de uma dobradiça com limites angulares. Cada dedo gera uma força no ponto em que tocou. Somamos as contribuições antes de atualizar a velocidade. Na dobradiça, a distância ao eixo e a direção da puxada determinam o torque. O integrador usa passos de até 1/120 s. O atrito reduz a velocidade e os batentes anulam a componente do movimento que tenta atravessá-los.

| Ajuste | Efeito |
|---|---|
| Rigidez | Eleva a força por unidade de distância entre o dedo e a âncora. |
| Elasticidade | Divide a rigidez efetiva. Um valor maior dá mais curso para a mesma tração. |
| Massa (kg) | Controla a aceleração do bloco e do pirulito. Na alavanca, também aumenta a inércia de rotação. |
| Atrito | Dissipa a velocidade livre do bloco, da alavanca e do pirulito. |
| Amortecimento | Reduz oscilações durante o vínculo e afeta a resposta do corpo. |
| Força máxima | Limita a força de cada dedo. O diagnóstico da Rosé mostra a força estimada em relação ao teto. |

## Rosé e tecidos

Rosé usa o erro na âncora para alimentar o solver de postura da 1.2.1. As puxadas dos dois lados contribuem para uma carga limitada no tronco, com comandos separados para os braços. O IK aplica seus limites de cotovelo e retorna gradualmente à postura ociosa. A massa corporal não é reconstruída por segmentos. Dois dedos podem puxar o mesmo acessório rígido. Cada braço tem um único alvo IK, e uma segunda tentativa de conduzir o mesmo braço é indicada no diagnóstico.

O pirulito integra força, massa e atrito, com limites e varredura de colisão por aproximação. Pode deslizar um pouco depois de soltar. A bancada de tecidos agora tem amostra, tira, cordão e alça de bolsa. O seletor prioriza o triângulo sob o dedo, depois tenta dois anéis de tolerância. Use um toque prolongado na bancada de tecidos. O cordão tem ligações mais rígidas que a amostra. Pinos e colisão com esfera continuam ativos.

## Exercícios no Android

1. Abra **Bancada**. Agarre o bloco com dois dedos e puxe para lados opostos. Compare as forças. Solte um dedo e confirme que o bloco chega ao batente e que a âncora restante continua na peça.
2. Puxe a alavanca primeiro perto da base e depois perto da ponta. Gire até o batente. A mão segue o ponto na peça, mesmo com o dedo fora do alcance.
3. Em **Ajustes**, dobre a massa e repita a mesma puxada no bloco. Depois abaixe o amortecimento e compare a estabilização. Abra `direct/grip_physics.gd` no editor de scripts para ver os termos de mola, amortecimento e atrito.
4. Em Rosé, use **Agarrar** nas duas mãos da personagem e puxe para lados opostos. Abra **Física**, compare posição desejada e efetiva e solte um dedo de cada vez. Confira a recuperação em perfil. Em `direct/direct_lab.gd`, localize `follow_held` para ver como a força chega ao IK e `refresh_physical_hand` para ver como a mão acompanha a âncora.
5. Em **Tecidos**, selecione o cordão pelo meio com tolerância zero. Aumente a tolerância e tente um toque junto à borda. Puxe a alça de bolsa perto do pino e depois no meio. Compare as dobras e o retorno. Edite os pontos fixos e a resistência por amostra em `direct/fabric.gd`.

## Validação e limites

Os testes injetam eventos no viewport. A bancada mede equilíbrio com dois dedos no mesmo objeto, tração dos dois lados, batente, continuidade da âncora e desaceleração. A integração mede diferença entre dedo e mão, contato com a malha animada, puxadas simultâneas, soltura, interação com tecido e controles herdados.

O solver da bancada tem um grau de liberdade por peça. O pirulito usa translação, sem torque de dois dedos. As colisões na personagem usam zonas aproximadas. A ponta da mão respeita a âncora e a varredura livre, mas os dedos renderizados podem penetrar a malha em alguns ângulos. As amostras de tecido não incluem autocolisão. A precisão do toque, a visibilidade do HUD e a sensação de peso ainda precisam ser conferidas em um Android físico com os exercícios acima.
