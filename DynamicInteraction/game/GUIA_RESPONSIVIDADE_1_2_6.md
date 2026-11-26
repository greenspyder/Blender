# Rosé 1.2.6 · Revisão de responsividade física

Importe `project.godot` pelo Godot no Android. Abra **Ajustes** e escolha **Leve**, **Natural**, **Resistente** ou **Personalizada**. Cada perfil guarda seus ajustes separadamente. **Salvar perfis** grava os quatro ajustes e a seleção atual. Se houver um perfil antigo salvo neste dispositivo, seus valores físicos ficam em **Personalizada**. O ponto de partida da revisão é **Natural**.

## O que deixava o arraste pesado

A versão anterior convertia o erro em força, normalizava pelo teto, filtrava o deslocamento em outra etapa e o comprimia novamente antes do IK. Em puxões pequenos, isso entregava pouco deslocamento ao braço. Agora o comando chega diretamente a uma curva de alcance com resposta rápida perto da origem e resistência crescente perto do limite. O IK amortece o movimento e conserva a pose e os limites dos cotovelos.

Para acessórios e a bancada rígida, o perfil anterior usava 1 kg e aplicava atrito integral junto com o amortecimento da mola durante a pega. A massa padrão passa a 0,50 kg. Enquanto o vínculo está ativo, a mola fornece a maior parte do amortecimento e o integrador usa um quarto do atrito configurado. Ao soltar, volta o atrito integral. O início da mola exige menos força por unidade de deslocamento, e a rigidez efetiva aumenta à medida que o erro cresce. As forças continuam somadas antes da integração, preservando o equilíbrio de puxadas opostas. A mão desenhada fica na âncora real durante o vínculo.

| Parâmetro | O que muda durante o teste |
|---|---|
| **Rigidez** | A força por deslocamento nas peças, a rapidez da resposta postural e a resistência dos vínculos do tecido. |
| **Elasticidade** | A folga do vínculo. Um valor maior aumenta a complacência da mola e facilita o deslocamento inicial do membro. |
| **Massa (kg)** | Quanto a peça acelera ao receber força. Também escala a rapidez postural e a resistência da amostra ao puxão. |
| **Atrito** | Quanto a velocidade livre do objeto decai depois de soltar. Tem efeito menor durante a pega. |
| **Amortecimento** | Quanto a resposta oscila antes de se estabilizar. Valores altos também podem atrasar a chegada ao alvo. |
| **Força máxima** | Teto de força de cada dedo e limite efetivo de deslocamento. |
| **Recuperação** | Rapidez com que o corpo e o tecido retornam após soltar. |
| **Suavização** | Acompanhamento do alvo nos controles herdados e no tecido. Também escala a resposta do IK ao arraste direto. |
| **Sensibilidade** | Ganho aplicado à distância física comandada pelo dedo. |
| **Tolerância, precisão do gesto e pressão longa** | Ajustes de seleção e de retenção do toque. A pressão longa continua sendo usada na bancada de tecidos. |

## Tecido simulado e animação procedural

Em **Tecidos**, as partículas integram gravidade e velocidade a cada passo. As ligações resistem ao estiramento e à dobra. A peça pode mudar de forma continuamente enquanto você puxa e ao atingir a esfera. A integração limita deslocamentos bruscos, e a pega próxima a pinos tem deslocamento máximo por vértice. Quando a amostra repousa, o solver pode pausar. O próximo gesto ou ajuste o reativa.

Na retirada da camisola, uma função coordena a subida da alça, dos braços e da peça. A forma muda por deformação procedural. Depois de soltar, a peça integra gravidade e arrasto até o chão. Esse gesto da 1.2.6 foi preservado. Na bancada, os tecidos ainda têm colisão aproximada e não simulam autocolisão.

## Medições reproduzidas no Godot

Os testes aplicaram o mesmo comando de arraste em cada perfil e mediram o deslocamento aos **167 ms**. São medidas da simulação com eventos e alvos programáticos, sem tela física.

| Deslocamento | 1.2.6 anterior | Leve | Natural | Resistente |
|---|---:|---:|---:|---:|
| Bloco no trilho | 5,1 cm | 14,1 cm | 9,1 cm | 4,1 cm |
| Punho da Rosé | 1,0 cm | 9,7 cm | 5,9 cm | 2,7 cm |

O teste manteve os batentes, os limites do cotovelo e a âncora ao puxar além do alcance. Verificou também o equilíbrio de dois dedos, a recuperação corporal e a desaceleração das amostras após soltar.

Uma execução em Godot 4.7.2 headless mediu cerca de **2,25 → 0,15 ms** de CPU por passo de física na bancada de tecidos em repouso. O cenário principal ficou em **0,18 → 0,16 ms** em repouso. Com 75 seleções incluindo ombro, cabeça e pirulito, o percentil 90 da seleção ficou em **5,97 → 5,69 ms** e a mediana em **2,75 → 3,08 ms**. A consulta reaproveita informação da malha no mesmo conjunto de raios. Essa amostra não demonstrou redução da mediana de seleção. Nenhuma dessas medidas inclui renderização, compositor nem processamento do toque pelo Android.

## Roteiro no celular

1. Entre na **Bancada**. Puxe o bloco a mesma distância com **Leve**, **Natural** e **Resistente**. Depois use dois dedos em sentidos opostos. Solte um e observe o batente.
2. Na Rosé, compare uma puxada leve no punho e outra longa. **Física** mostra a posição final da mão, o erro e a força. Observe a volta do braço ao repouso.
3. Em **Tecidos**, compare uma dobra perto do pino com uma puxada no meio da amostra. Solte e observe a oscilação. Salve o perfil e retorne para confirmar que é carregado.
4. Compare **FPS**, **Física** e **Cena** antes e durante o gesto. **Física** é o tempo do processamento de física reportado pelo motor. **Cena** é a média suavizada do script da cena. **Evento → tick** mede do recebimento do evento pela cena ao tick seguinte. A métrica não inclui latência do painel touch nem mede o tempo até o pixel aparecer.

A sensação de peso, a taxa de quadros com renderização e a latência completa ainda precisam de conferência no Android físico.
