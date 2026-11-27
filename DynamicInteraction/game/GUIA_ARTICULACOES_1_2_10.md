# ROSE 1.2.10 · Articulações e IK

Use o mesmo ZIP no PC e no Android. Importe `project.godot` e execute. Na cena principal, selecione **Agarrar** no Android ou clique na mão da Rosé no PC. Arraste para cima e um pouco para fora. Solte o dedo ou clique de novo para ver o braço voltar ao repouso.

Para isolar uma articulação, abra **Bancada → Articulações**. Use os controles de ombro, cotovelo e punho esquerdo e direito, além de **Pelve**, **Coluna** e **Pescoço**. As linhas mostram os ossos importados. As cruzes amarelas mostram os alvos depois da aplicação dos limites. Os valores ao lado medem a elevação do braço e a flexão real do cotovelo. No editor, abra `direct/articulation_lab.tscn` e selecione o nó **BancadaArticular** para editar os mesmos parâmetros no Inspector.

## O que era da Godot

A 1.2.9 convertia a puxada em um deslocamento de força antes de passá-la ao IK. O solver ainda limitava o desvio em torno do repouso. O braço fletia, mas o punho travava abaixo do ombro mesmo com o dedo muito acima. A 1.2.10 mantém a resistência aplicada ao corpo e entrega ao IK a intenção de deslocamento da mão. O alvo preserva o ponto de pega na palma ou no antebraço e passa da coordenada global para o espaço local do esqueleto.

O solver limita o alcance pelos comprimentos do braço e do antebraço, usa uma faixa padrão de flexão de **12° a 128°** e amortece a resposta até o alvo. A orientação preferencial do cotovelo permanece lateral e muda gradualmente com a pose. Os giros de punho da bancada usam o eixo do antebraço. A coluna, a pelve e a cabeça preservam a reação procedural. O GLB desta versão não tem clipes ou AnimationPlayer importado. O solver restaura a pose dos ossos antes de calcular cada quadro. As blend shapes corretivas dos braços continuam excluídas da resposta procedural principal, e a correção de pesos do quadril da 1.2.9 continua ativa.

| Mesmo comando de puxada para cima | 1.2.9 | 1.2.10 |
|---|---:|---:|
| Quanto o punho direito subiu | 19,9 cm | 97,8 cm |
| Altura final em relação ao ombro | 33,8 cm abaixo | 44,0 cm acima |
| Flexão do cotovelo ao final | 111,9° | 73,7° |

Os valores vêm de uma trajetória de teste equivalente a 0,98 m de elevação do alvo, com deslocamento lateral de 0,16 m e profundidade preservada como no toque. São medidas do rig em uma pose repetida, não o alcance absoluto de todas as poses. Um teste adicional varreu o gesto em 36 passos e verificou comprimentos, limites, continuidade e retorno ao repouso.

## O que depende do rig

| Região | Ossos que chegaram à Godot | Limite atual e onde corrigir |
|---|---|---|
| Ombros e braços | `Spine → UpperL/R → ForeL/R → PalmL/R` | Os braços elevam e giram a partir de `UpperL` e `UpperR`. Para mover a cintura escapular independentemente, adicione clavículas entre `Spine` e cada braço no Blender e ajuste seus pesos. |
| Cotovelos | `ForeL` e `ForeR` | Usados no IK com polo e limite de flexão. No Blender, revise a orientação local e o bone roll se quiser recalibrar o eixo de dobra em uma exportação futura. |
| Punhos | `PalmL` e `PalmR` | Rotação axial disponível na bancada. Não há uma cadeia esquelética separada para dedos do avatar nesse GLB. |
| Pelve | `Base` | Permite deslocar o apoio do corpo. Falta uma cadeia independente para cada quadril, o que impede controlar abdução e rotação das pernas de modo esquelético. |
| Joelhos e tornozelos | Nenhum osso de coxa, canela ou pé | O controle **Joelho · blend shape** demonstra a aparência atual. Para dobrar ou abrir as pernas com IK, adicione e pese as cadeias no Blender. |
| Coluna e pescoço | `Spine` e `Head` | A coluna é um segmento e a orientação do pescoço usa o pivô de `Head`. Um pescoço independente exige um osso intermediário. |

## Como reproduzir e corrigir no Blender

1. Importe `assets/rig121.glb` em um arquivo temporário. No Outliner, selecione **ResponseRig** e entre em **Edit Mode**. A hierarquia exportada tem nove ossos. Abra **Pose Mode** e confirme que é possível selecionar `UpperR`, `ForeR` e `PalmR`, enquanto as pernas não têm cadeia selecionável. Alterar `idle_knees` em **Object Data Properties → Shape Keys** mostra a dobra visual existente.
2. Na cópia de trabalho da 1.3, crie uma cadeia por perna em **Edit Mode**, da pelve ao joelho, ao tornozelo e ao pé. Confira o alinhamento dos centros articulares em vista frontal e lateral. Mantenha a canela e o pé filhos da cadeia correspondente. Para abrir uma perna sem arrastar a outra, a coxa de cada lado precisa ter seu próprio grupo.
3. Defina o bone roll de forma consistente dos dois lados. Em Pose Mode, confira a direção da dobra com um alvo de pé e um polo à frente do joelho. Teste primeiro com o solver da Godot desligado ou em uma cena isolada.
4. Em **Weight Paint**, limpe a influência de `Base` nas partes que agora pertencem à coxa e à canela. Suavize a transição no joelho, normalize os pesos e cheque se o pé conserva o volume durante a rotação. Inspecione a roupa com o mesmo conjunto. Exporte um GLB de teste e confirme os novos ossos no Skeleton3D antes de ligar um IK na engine.

Os arquivos Blender e o GLB de produção foram preservados. O diagnóstico descreve o esqueleto efetivamente exportado e o script de geração presente no projeto. Se o seu arquivo autoral contiver ossos adicionais, confira se aparecem no GLB e se estão associados à malha na exportação.

## Validação

- **Jogo** · Elevação por pega real, flexão, comprimento dos segmentos até o limite, ponto de contato e recuperação após soltar.
- **Bancada** · Testes independentes de elevação e flexão nos dois lados, torção de punho, deslocamento de pelve, rotação de tronco, orientação de cabeça, limite editável e referência dos joelhos.
- **Regressões** · Tecido, braços ao retirar a camisola, integridade do quadril, toque e mouse continuam nas suítes automatizadas.

No Android, comece com a personagem toda no enquadramento. Puxe a mão devagar até acima do ombro, segure no limite e solte. Repita em ângulo de três quartos. Na bancada, altere um controle por vez e use **Ossos e alvos de IK** para conferir a direção do cotovelo. As medições foram executadas no Godot 4.7.2 headless. A qualidade do movimento renderizado e a sensação do toque no dispositivo físico ainda precisam dessa verificação.
