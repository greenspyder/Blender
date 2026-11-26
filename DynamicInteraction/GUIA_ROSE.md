# Rosé · Dynamic Interaction System 1.0

## Primeiro experimento

Extraia tudo. No Godot 4.7, importe **game/project.godot**, aguarde a importação e pressione F5. Em **Ambas as mãos**, aponte para o ombro à direita da tela. Pressione W aos poucos. Na vista frontal, a mão esquerda acompanha o movimento em espelho. Abra **Ajustes**. Observe o nome e a intensidade de cada contato, o recuo, os braços e a sobrancelha. Afaste as mãos com S e veja a recuperação. Compare um toque rápido com uma aproximação lenta.

| Controle | Função |
|---|---|
| Mouse | Posiciona as mãos no plano da câmera |
| W / S | Aproxima / afasta em profundidade |
| Q / E | Gira as mãos no punho |
| Botão direito + arrastar | Orbita horizontal e verticalmente |
| Roda | Zoom |
| Setas para cima / baixo | Move a altura do enquadramento |
| Pirulito | Arraste até a boca ou use o botão de oferecer |
| R | Restaura o enquadramento e a posição do pirulito |

O campo **Distância** controla a abertura mínima do par. **Espelho** controla quanto a esquerda acompanha o afastamento horizontal da direita. Teste o espelho de frente: a referência é o eixo X da personagem. No modo individual é possível cruzar o centro.

## Estudo no Blender 5.1

Abra **src/Rose_Contato_1_0.blend** mantendo BUBUROSTO.blend ao lado. A cena 05 contém a esfera junto ao short. A cena 06 contém a almofada oval junto à camisola. Cada uma tem um controle chamado **Mover em Y**. Os seis PNGs ao lado do arquivo são renders dos quadros 1, 46 e 84. Na Timeline, compare esses três quadros e o repouso final no 108.

1. Pare no 46. Selecione **Mover em Y** e pressione G, Y. Afaste o objeto e examine a resposta do corpo e da roupa. Mudar de quadro retoma a animação.
2. Selecione a malha Body da cena. Em **Object Data Properties → Shape Keys**, abra o driver de **hip_press** na 05 ou **chest_press** na 06. Ele remapeia Y do controle para intensidade entre zero e um. A mesma expressão dirige as peças da roupa.
3. No quadro 84, veja **Retorno = 0,17** nas propriedades personalizadas do controle. Reduza para zero e compare. Grave com I sobre o campo para editar a recuperação. No quadro 108 deve voltar a zero.
4. Para redesenhar o sulco, salve uma cópia, selecione a shape key e edite os vértices com edição proporcional. Compare de perfil. Repita na roupa e no bolso, verificando as três camadas sob pressão máxima.

A cena 07 é a pose de exportação com materiais e deformações editáveis. As cenas anteriores de modelagem, painel e clipe continuam no arquivo. A cena 01 usa os ossos **Apoio, Quadril, Tórax, Braço.E e Braço.D**. Antes de tentar IK de mãos ou pés, crie, numa cópia da armature, cadeias de braço/antebraço/mão e coxa/canela/pé. Acrescente pescoço e cabeça. Distribua pesos nas articulações, pose cada cadeia e confira a roupa nos extremos. O GLB desta versão usa a pose inicial e morphs; uma revisão de pesos requer uma nova exportação com skinning para chegar à engine.

## Como funciona e onde editar

| Arquivo | Responsabilidade |
|---|---|
| game/dynamic.tscn e dynamic/lab.gd | Cena principal, câmera, seleção, espelhamento, parâmetros do painel e aplicação dos pesos no corpo e na face |
| dynamic/hand.gd | Forma simplificada da mão, suavização, rotação, contato visual e transição de visibilidade |
| dynamic/contact.gd | Elipsoides de cabeça, pernas, braços, ombros, tronco e quadril. Calcula superfície, normal e força |
| dynamic/response.gd | Combina dois contatos e integra uma mola amortecida com subpassos de até 1/120 s |
| assets/full.glb | Malhas da Rosé e shape keys da pose procedural |
| tools/build_full.py | Geração das cenas de estudo e exportação a partir do clipe facial |
| demo.tscn, interaction.gd e TUTORIAIS.md | Demonstração anterior do retrato e lógica reutilizada do pirulito |
| tests/dynamic_test.gd e tests/interaction_test.gd | Verificações da versão nova e da interação anterior |

O detector recebe a posição desejada. Ao entrar em uma zona, projeta a palma na superfície aproximada. A pressão usa profundidade, velocidade na direção da normal e tempo de contato. O controlador soma os estímulos dos dois lados, limita os alvos e suaviza a resposta. Uma força simétrica nos dois ombros pode cancelar a inclinação lateral enquanto os dois braços e o recuo permanecem ativos. Os pesos afetam corpo, roupa, cabelo e olhos conforme a altura dos vértices. O mesmo material pode ser substituído por um shader toon posteriormente.

## Exercícios progressivos

**1 · Ajustar uma mola.** No painel, varie apenas **Rigidez** entre 20 e 80. Repita o toque. Depois mantenha a rigidez e varie **Amortecimento**. A influência mistura a pose final. Recuperação altera a rigidez usada ao soltar. Sensibilidade multiplica a força de entrada.

**2 · Ajustar as mãos.** Compare Distância em 0 e 0,25 com Espelho em 1. No arquivo hand.gd, altere o fator 16 da suavização exponencial em advance. Valores menores deixam o cursor mais atrasado. As duas mãos são instâncias separadas; um controle independente pode fornecer um ponto diferente a cada chamada de advance.

**3 · Cadastrar contato.** Em contact.gd, adicione uma chave a ZONES com centro e semieixos locais, em metros, Y para cima. Comece pelo cotovelo: inspecione a malha na cena 3D e use o gizmo para medir o centro. Evite sobrepor todo o braço. Em áreas sobrepostas prevalece a zona de maior força. Ative Ajustes e confira qual nome aparece quando você aproxima uma mão.

**4 · Criar uma reação.** Em response.gd, localize o ramo de ombro/braço. Acrescente o cotovelo à condição e reduza o ganho local. Teste só de um lado e depois dos dois. Para desenhar uma pose totalmente nova, crie uma shape key na cena 07, exporte o GLB e acrescente o nome às listas de bindings e pesos de lab.gd. Ao exportar a cena 07, inclua só a cena ativa, com shape keys e sem animações.

**5 · Adicionar um objeto.** Duplique a representação de uma mão e substitua a geometria por uma esfera de espuma. Registre o modo em lab.gd. Passe a posição do ponto de toque para o detector e ajuste a margem de 0,033 m em contact.gd para esse objeto. Verifique a projeção lateralmente com a câmera orbital. Para um objeto alongado, amostre ponta e cabo separadamente e defina como combinar os contatos.

## Diagnóstico e limites

- Se a mão pairar na frente da personagem, ajuste a profundidade com W. Se o contato ocorrer cedo demais, reduza o raio da zona e confira por dois ângulos.
- Se a pose parecer exagerada, reduza Sensibilidade ou Influência. Se oscilar ao soltar, aumente Amortecimento. Os marcadores mostram o contato calculado; a superfície real pode divergir, principalmente nas extremidades.
- Os colisores aproximam a pose de repouso. As mãos são formas estilizadas, com um ponto de contato por palma. Movimentos rápidos podem ultrapassar regiões finas. Dedos articulados, colisão contínua com a malha deformada e controles multitouch independentes ficam para outra versão.
- A resposta de postura é contínua e usa blend shapes compartilhadas. Cabeça e tronco acompanham curvas de inclinação. O equilíbrio flexiona a silhueta. Não há passos de equilíbrio, IK ou simulação física de ossos. Os estudos locais de compressão no Blender têm trajetos próprios.
- No terminal, execute dentro de game: `godot --headless --editor --import --quit`, depois `godot --headless -s res://tests/dynamic_test.gd` e `godot --headless -s res://tests/interaction_test.gd`. O primeiro teste verifica os contatos simultâneos em vista frontal, pesos dos braços e expressão, espelhamento, modos individuais, retorno ao repouso, encaixe e zoom. O segundo envia eventos reais à viewport da cena anterior.
- A validação Godot foi em modo headless. O acabamento da iluminação em GPU, a sensação do controle com mouse e a fidelidade da colisão em todos os ângulos precisam de avaliação visual no editor.
