# Rosé Mobile · Godot no Android

> Para a versão 1.3.3.2, comece pelo [tutorial da interface de jogo](GUIA_GAMEPLAY_1_3_3_2.md). Este documento preserva as instruções das cenas anteriores, disponíveis em Desenvolvimento.

## Instalar no celular

1. Extraia **Rose_Mobile_Completo.zip** em uma pasta própria no celular.
2. No gerenciador do Godot, toque em **Importar** e selecione o **project.godot** dessa pasta. Os modelos, as cenas e os scripts já estão incluídos.
3. Aguarde a importação dos modelos. Toque no triângulo de executar projeto. A cena inicial é mobile_lab.tscn. Para recuperar configurações próprias, você também pode manter seu project.godot e escolher mobile_lab.tscn como cena principal nas configurações do projeto.
4. A interface de toque aparece automaticamente no Android. No computador com mouse, o laboratório usa os controles da 1.1. A primeira entrada touchscreen ativa o painel de toque.

## Pegar na mão da Rosé

Escolha **Mão direita**. Arraste um dedo até o punho da Rosé. Use o controle vertical à direita: subir aproxima a mão no enquadramento frontal; descer a afasta. Ao tocar ou chegar perto do punho, toque em **Agarrar**. Arraste novamente. O alvo do braço acompanha sua mão dentro do alcance definido no rig 1.1. Toque em **Soltar** para liberar. A pegada controla o braço; o corpo continua com sua resposta postural. Para recolher o pirulito, aproxime sua palma do doce e use o mesmo botão. Ao soltar, ele volta à bandeja.

## Modos e controles

| Modo ou controle | Gesto |
|---|---|
| Direita / esquerda | Um dedo posiciona a mão no plano da câmera. A barra lateral controla a terceira dimensão. |
| Par espelhado | Um dedo controla a abertura horizontal das duas mãos em relação ao centro da Rosé. |
| Duas independentes | Comece um toque em cada metade da tela. Cada dedo conserva sua mão mesmo ao cruzar o centro. Levantar o dedo deixa a mão na última posição. |
| D / E | Alterna a mão ativa em modo independente para profundidade e pegada. Mover um dedo também seleciona sua mão. |
| Girar − / + | Toque para um pequeno passo ou mantenha pressionado. A rotação do par é espelhada. |
| Câmera | Toque em Câmera, arraste um dedo para orbitar e use dois para pinçar. Desloque os dois dedos verticalmente para ajustar a altura. Toque em Câmera de novo para voltar. |
| Pirulito | Arraste o doce até a boca e solte. Também pode tocar em Oferecer ou Retirar. |
| Feedback | As letras D/E identificam as palmas. A cor muda com o contato. A faixa inferior mostra a região ou o item segurado e a mão que recebe o ajuste de profundidade. |

Uma pinça só controla zoom no modo Câmera. A posição das mãos fica retida enquanto você muda o ponto de vista. Toques iniciados nos controles laterais e botões não são atribuídos a uma mão.

## Editar no próprio Android

No painel **FileSystem**, abra **res://mobile/touch_lab.gd** com dois toques. Use a busca do editor de scripts para localizar as funções. Salve e execute a cena após cada ajuste.

- **Alcance da pegada.** Ajuste GRAB_DISTANCE em metros. Comece com uma variação de 0,01. A seleção escolhe o punho ou o doce mais próximo da palma dentro desse limite.
- **Interface.** Em layout(), ajuste a largura da barra e os afastamentos. Em button(), altere custom_minimum_size. Rode em retrato e paisagem. As linhas de botões usam HFlowContainer para quebrar conforme a largura.
- **Profundidade.** Em adjust_depth() e hand_world(), veja como a posição de tela se converte em um ponto no plano da câmera. A barra move esse plano. Os limites devem concordar com os do laboratório de precisão.
- **Multitouch.** Em start_finger(), owners associa cada índice de toque a uma função. Em end_finger(), a associação é liberada. Mude primeiro a regra que escolhe a mão inicial e confira cruzamento e soltura.
- **Resposta e força.** O laboratório continua usando precision/hand.gd e precision/pose_solver.gd. Consulte GUIA_1_1.md para os limites de alcance e os parâmetros do solver.
- **Outro objeto.** Acrescente um Node3D à cena e registre seu nome, posição de pegada, acompanhamento e destino de soltura junto ao tratamento de candy. Use um Marker3D na região que a mão deve segurar.

## Conferência no aparelho

Comece em paisagem. Deslize a direita, ajuste profundidade com o segundo dedo, segure a mão da Rosé e solte. Repita de outro ângulo. Em Duas independentes, cruze os dedos e levante só um. O outro deve manter a mão original. Entre em Câmera e faça uma pinça: confira se as mãos ficam paradas. Volte, alterne espelho e pirulito, gire o telefone, minimize o app durante um arrasto e reabra. As associações de toque devem ser liberadas ao perder o foco.

**Estado da validação:** nenhuma interação desta atualização foi executada em aparelho Android físico nesta entrega. O teste tests/mobile_touch_test.gd passou com eventos de toque sintéticos no Godot 4.7.2 em Linux headless. A cena mobile_test.tscn também executou com zero falhas. Foram verificados espelhamento, IDs das mãos, profundidade independente, pinça, órbita e pegada do punho e do pirulito. Os testes anteriores de precisão, resposta e pirulito passaram. Ergonomia, rotação física do aparelho, latência e renderização na GPU Android requerem avaliação no dispositivo. No editor Android, siga o roteiro manual acima.

Em uma instalação com terminal do Godot, rode a partir de game: `godot --headless --editor --import --quit` e `godot --headless -s res://tests/mobile_touch_test.gd`. No editor Android, a verificação manual usa a própria cena mobile_lab.tscn.

Para executar a verificação sintética sem teclado, abra mobile_test.tscn e escolha **Executar cena atual**. Ao fim, a cena exibe OK ou a lista de falhas. Isso exercita o roteamento no aparelho com eventos gerados por código. A ergonomia requer a conferência com os dedos descrita acima.
