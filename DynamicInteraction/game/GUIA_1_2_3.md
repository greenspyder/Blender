# Rosé 1.2.3 · Toque e arraste

Extraia o ZIP em uma pasta nova, importe `project.godot` no Godot para Android e execute o projeto. Para verificar só o controle, toque em **Teste cubo** na barra superior. **Rosé** volta para a personagem.

| Modo na barra superior | Como usar |
|---|---|
| **Tocar** | Encoste o dedo e arraste. A ponta da mão segue o dedo. O cubo e a personagem permanecem livres. |
| **Agarrar** | Encoste diretamente na superfície visível e comece a arrastar. O vínculo começa no primeiro toque e termina ao levantar o dedo. |
| **Duas independentes** | Use dois dedos, um para cada mão. Solte um deles e continue com o outro. |
| **Par espelhado** | Use um dedo. Em Agarrar, cada lado precisa encontrar uma superfície para estabelecer seu vínculo. |
| **Câmera** | Um dedo orbita e dois aproximam. Volte ao modo de mãos para retomar a interação. |

No PC, o clique continua alternando pegar e soltar. O mouse movimenta a mão, os atalhos de profundidade e rotação continuam disponíveis e o botão direito orbita. Para a bancada **Tecidos**, continua valendo o gesto descrito no guia 1.2.2.

## Causa reproduzida

Na 1.2.2, enviei um toque com índice 7 e um arraste de 95 pixels pelo viewport. O controlador recebeu o arraste e atualizou a posição armazenada. Como o dedo se moveu antes do toque longo, o código desativou o vínculo. Sem vínculo, o arraste não atualizava o alvo da mão. A etapa de desenho reposicionava a mão no triângulo inicial a cada quadro. O indicador se deslocou só 0,35 pixel, acompanhando a oscilação de repouso da malha. A reprodução isolou essa falha na transição entre contato e arraste. Ela não mede a frequência de eventos de um Android físico.

## Como foi corrigido

- `direct/touch_drag.gd` encaminha `InputEventScreenTouch` e `InputEventScreenDrag` pelo índice do dedo. Um toque iniciado sobre a interface fica com a interface. Um dedo capturado na cena continua arrastando ao passar sobre uma barra. A soltura ou o cancelamento descarta a captura. O cubo e a Rosé compartilham esse código.
- `direct/direct_lab.gd` usa o raycast existente para encontrar o ponto inicial na malha. O plano de arraste passa por esse ponto e fica paralelo à tela. Os próximos eventos projetam o dedo nesse plano, preservando a profundidade. A diferença entre o raio central e o ponto obtido pela tolerância fica preservada durante o gesto.
- Em **Agarrar**, a ponta da mão mostra a posição comandada pelo dedo. A Rosé segue com a resistência e os limites do IK. Pirulito e roupas continuam usando suas respostas existentes. A alça da camisola continua selecionável e aplica a deformação da peça. O indicador pode se distanciar do alvo ao puxar além do alcance.
- **Debug toque** mostra o último dedo recebido, o tipo de evento, contadores, posição 3D da ponta da mão, alvo, vínculo e motivo de falha. O painel recebe eventos do modo de mãos. Câmera e pirulito da ferramenta legada continuam com seu próprio roteamento.

## Roteiro para o Android

| Teste | Resultado que indica aprovação |
|---|---|
| Abra **Teste cubo** e ative **Debug toque**. Em **Agarrar**, toque no cubo e arraste imediatamente. | O índice continua o mesmo, **Arrastes** aumenta, a mão e o cubo mudam de posição com a profundidade inicial. |
| Continue o mesmo arraste até passar sobre uma barra e solte. | O cubo acompanha o gesto e fica onde parou. O painel mostra **Soltura** e **Livre**. |
| Em **Agarrar**, toque fora do cubo. Depois repita em **Tocar**. | O primeiro registra que o raio não atingiu o cubo. O segundo move o indicador livremente. |
| Volte para Rosé. Em **Tocar**, inicie no antebraço e arraste para fora da silhueta. | A mão acompanha o dedo continuamente. |
| Em **Agarrar**, pegue o pirulito. Depois teste mão, antebraço, ombro e alça. | O vínculo aparece no toque, o elemento reage durante a puxada e soltar encerra a tração. |
| Teste mãos independentes, espelho, câmera e troca de aplicativo. | Soltar um dos dois dedos encerra apenas sua captura. Em câmera, arrastar orbita. Perder o foco encerra o gesto. |

## Como editar pelo Godot

No painel **FileSystem**, abra `direct/touch_drag.gd` para inspecionar o encaminhamento dos eventos e `direct/direct_lab.gd` para acompanhar `begin_direct`, `move_direct` e `follow_held`. O primeiro seleciona a superfície, o segundo calcula a posição da mão e o terceiro transmite a tração. Para comparar comportamentos, ajuste **Sensibilidade**, **Força máxima** ou **Suavização** em **Ajustes**. Esses parâmetros mudam a resposta do elemento agarrado. A ponta da mão continua seguindo o dedo no plano inicial. Use `direct/drag_cube.tscn` para editar distância da câmera, tamanho do cubo e posição inicial em um cenário pequeno.

A duração de toque longo e a tolerância do gesto permanecem relevantes na bancada de tecidos. O plano fixo preserva a profundidade inicial. Ao cruzar uma silhueta em **Tocar**, a mão segue esse plano, sem recalcular a superfície a cada pixel.

## Validação registrada

Primeiro, o teste do cubo por eventos injetados no viewport verificou toque, índice, seleção, arraste, profundidade e soltura. Em seguida, a integração verificou o movimento imediato da ponta, pirulito e alça em movimento, dois dedos, espelho, câmera e cancelamento. Foram usados eventos sintéticos no Godot. O roteiro acima cobre a experiência que ainda deve ser conferida no Android físico.
