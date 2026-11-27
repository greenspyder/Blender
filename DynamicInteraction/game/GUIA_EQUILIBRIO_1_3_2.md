# Rosé 1.3.2 · Equilíbrio e contato com o chão

No Android ou no PC, extraia o ZIP em outra pasta, importe `project.godot` e abra **Bancada → Articulações → Corpo inteiro → Equilíbrio e chão**. Pelo editor, execute diretamente `rig/balance_lab.tscn`. A cena inicia com a personagem vestida e o piso nivelado. A dinâmica nova roda nessa bancada. O jogo principal continua disponível para testar as interações anteriores.

## O que mudou desde a 1.3.1

| | Bancada de corpo inteiro da 1.3.1 | Bancada de equilíbrio da 1.3.2 |
| --- | --- | --- |
| Contato | Menu selecionava os pés a plantar e o IK usava pontos no espaço do esqueleto. O piso era uma malha visual. | Cada pé consulta o mundo físico, identifica o colisor, mede a distância e lê a normal. O vínculo de apoio desaparece na fase de balanço, fora de alcance ou quando acaba a superfície. |
| Peso | O perfil fornecia massa e centro de massa para diagnóstico. A altura da pelve seguia a pose. | A gravidade acelera a raiz. A compressão e a velocidade vertical produzem reações de apoio. A carga se reparte entre os pés conforme a posição do centro de massa. |
| Coordenação | A pelve e as duas cadeias de pernas compartilhavam um solver. | O mesmo solver recebe o alvo e a orientação de cada sola. A pelve compensa desvios; lombar e tórax acompanham o movimento. O IK continua respeitando alcance e limites do perfil. |
| Animação | Referências fixas, sem clipes importados no GLB estudado. | Trajetórias reproduzíveis geram a intenção de passo, agachamento e inclinação. Os raios decidem se existe superfície capaz de sustentar o passo. Uma única etapa escreve os ossos. |

## Leia a cena

O **centro de massa** é a média das posições dos segmentos, ponderada pela massa de cada um. O solver usa pontos entre os pivôs da cadeia e as proporções do perfil. Mudar a pose do tronco, dos braços ou das pernas desloca a cruz amarela. Sob gravidade uniforme, o centro de gravidade coincide com esse centro de massa. A linha amarela mostra a projeção vertical no apoio. Em voo, a projeção sobre um apoio desaparece.

A **base de sustentação** é o polígono verde formado pelo contorno convexo das áreas estimadas das solas em contato. Em apoio unilateral, o polígono encolhe para um pé. Em repouso, a posição da projeção dentro da base indica margem de equilíbrio estático. Durante a caminhada, velocidade e inércia também importam. A bancada usa a margem geométrica para acionar compensação e identificar perda e recuperação. Ainda há movimentos que exigiriam um passo corretivo ou uma queda.

As linhas verticais nos pés e os valores em newtons representam as **componentes verticais das reações**. Em repouso, a soma se aproxima de massa × gravidade. Na aterrissagem, ela pode superar o peso durante a desaceleração. Um pé fora do piso deixa de fornecer carga. O polígono e a indicação de contato são independentes das cruzes de alvos do IK, que também aparecem durante o balanço livre.

## Como funciona um passo

1. A trajetória pede uma posição livre para cada sola. O comprimento das pernas medido no repouso define a escala do passo.
2. Um raio vertical verifica a superfície na camada configurada. Uma faixa de entrada e uma faixa um pouco maior para saída evitam a troca repetida de estado perto do chão. Uma inclinação íngreme demais descarta o apoio.
3. Durante o apoio, o ponto fica registrado nas coordenadas do colisor. O alvo acompanha a superfície. Ao entrar em balanço, o pé se libera e segue o arco do passo. A orientação converge para a normal medida.
4. O IK calcula quadril, joelho e tornozelo. Depois do cálculo, o sistema compara a posição efetiva da sola com a âncora. Um alvo que ficou longe demais deixa de sustentar o corpo.
5. A raiz recebe a gravidade e as reações verticais em subpassos de até 1/120 s. Uma resposta amortecida desloca a pelve em direção à base. A passagem por fora da base e o retorno geram os estados **Perda de equilíbrio** e **Recuperação**. O contato e o estado de equilíbrio são mostrados separadamente.

## Parâmetros e outros modelos

| Controle | Efeito e exercício |
| --- | --- |
| Inclinação do piso | Experimente 0°, depois 9°. Observe de perfil a sola acompanhar a rampa. |
| Resposta de sustentação | Frequência angular da mola vertical. Reduza para ver maior compressão sob o mesmo peso e aumente para obter um apoio mais firme. |
| Amortecimento | Aumente para reduzir a oscilação na aterrissagem. Compare usando **Impulso vertical**. |
| Compensação | Regula quanto a pelve tenta recentralizar a massa. Execute **Perturbar e recuperar** com dois valores. |
| Faixa de contato / perna | Proporção do comprimento da perna usada para reconhecer aproximação. Valores altos antecipam a captura do pé. |
| Meia largura e meio comprimento da sola | Ajustes do Inspector no perfil. Determinam a área estimada do calçado e a margem indicada para equilíbrio. |
| Ground Mask | Camadas de colisão aceitas como chão. No editor, confira a camada do StaticBody3D e a sua CollisionShape3D. |

Ajustes durante a execução valem para o ensaio atual. Para mudar os padrões, edite um perfil duplicado de `rig/rose_131.tres` e atribua-o ao nó raiz da bancada. Os limites, a distância do pivô do tornozelo à sola, a massa total e a divisão por segmentos continuam nesse perfil. O chão padrão usa a gravidade do projeto dirigida para baixo em Y. Mantenha escala unitária na importação e siga o contrato de eixos da 1.3.1.

Ao trocar o GLB, confira em Pose Mode no Blender se o pivô do joelho fica no centro da dobra e se os grupos do calçado acompanham o pé correto. Um erro de peso pode mover vértices mesmo quando a âncora está estável. Na Godot, calibre **Sole Offset** e as dimensões das solas pela nova malha. Se a âncora não aparecer, inspecione primeiro o colisor e a máscara. Se aparecer mas o joelho travar, confira comprimentos, limites e mapeamento de ossos.

## Validação

O ensaio determinístico chama o controlador a 30, 60 e 120 Hz com colisores reais da Godot. Testa repouso, agachamento, caminhada alternada, apoio esquerdo, perda e recuperação, ausência de apoio, aterrissagem e rampa de 9°. Mede a distância horizontal da sola calculada pelo esqueleto à âncora e a penetração vertical do ponto de sola durante a marcha. Com o perfil de 56 kg, a soma das reações em repouso foi **548,8 N** nas três frequências. Os dois desvios medidos na marcha ficaram abaixo de **0,01 mm** no cenário plano testado. O ensaio completo headless consumiu em média aproximadamente **0,6, 0,3 e 0,15 ms por tick** neste executor. Resultados dependem do hardware e da carga da cena.

Um segundo teste usa o ciclo normal de física da engine durante 180 ticks de caminhada. Foi executado com a cadência de quadros headless configurada em 30, 60 e 120 FPS. Essa medição não inclui renderização, aquecimento ou latência de toque de um aparelho Android.

### Roteiro pelo Android

1. Observe **Bilateral / Estável** em repouso, as duas reações e o nome da superfície. Em **Apoio esquerdo**, verifique o pé direito livre e a força direita em zero.
2. Execute **Caminhar** e gire a câmera para três quartos. Observe se a pantufa permanece no lugar durante cada apoio e se atravessa o piso na fase de balanço. Repita a 9° de inclinação.
3. Alterne **Agachar** e **Inclinar o tronco**. Veja a coordenação entre joelhos, tornozelos e coluna e anote qualquer quebra de volume. Use **Impulso vertical** em pé para observar ausência de apoio e aterrissagem.
4. Em **Perturbar e recuperar**, acompanhe o marcador de massa cruzando o contorno. Compare tempo por tick com as visualizações ligadas e desligadas. Volte à cena principal para conferir os seus gestos de interação.

### Alcance desta versão

O cálculo resolve a dinâmica vertical da raiz e usa compensação horizontal guiada. A força exibida é uma estimativa vertical de sustentação. Atrito lateral dinâmico, torque muscular, queda articulada, apoio pelas mãos e agarrar o tronco para erguer a personagem pertencem à próxima etapa. O contato de cada sola usa um raio central e uma área estimada. Degraus estreitos, bordas e interpenetrações de vértices da pantufa pedem validação adicional. Os parâmetros de referência foram testados com o modelo atual.

Para a 1.3.3, `rig/ground_balance.gd` disponibiliza superfície, normal, ponto, cargas, base e estado de equilíbrio. `rig/full_body_pose.gd` mantém os alvos de pose que poderão orientar os motores articulares. A demonstração e os controles ficam em `rig/balance_lab.gd`.
