# Rosé 1.2.7 · Um projeto para PC e Android

Use o mesmo ZIP nos dois dispositivos. O projeto abre a cena `direct_touch.tscn` e usa o renderizador Compatibilidade. O título da janela indica **Rosé 1.2.7**. O nome interno no Gerenciador de Projetos continua igual ao da 1.2.6 r2 para manter a mesma pasta de preferências. A versão usada nos testes foi Godot **4.7.2**.

## Executar

| Plataforma | Passos |
|---|---|
| **PC** | Extraia o ZIP. No Gerenciador de Projetos do Godot, clique em **Importar** e selecione `project.godot`. Abra o projeto e pressione **F5**. |
| **Android** | Extraia o mesmo ZIP em uma pasta acessível pelo editor Godot. Importe o mesmo `project.godot` e toque no botão **Executar projeto**. |

O ZIP contém o projeto editável para executar pelo Godot. Arquivos executáveis de distribuição dependem de exportação posterior.

## Controles

Na barra superior, **Auto · Desktop** ou **Auto · Touchscreen** indica o modo que será usado no automático. Em Android, o automático seleciona toque. Em PC, seleciona mouse e teclado. Você pode escolher **Desktop** ou **Touchscreen** manualmente e a opção fica salva no dispositivo. Trocar de modo encerra a captura em andamento. A cena, as configurações de física, a pose e os objetos são compartilhados.

| Ação | Desktop | Touchscreen |
|---|---|---|
| Posicionar a mão | Mova o cursor. | Selecione **Tocar** e mova o dedo. |
| Agarrar e soltar | Clique no alvo, mova o cursor e clique novamente para soltar. | Selecione **Agarrar**. Toque, arraste e levante o dedo para soltar. |
| Usar as duas mãos | **Par espelhado** controla as duas. Em **Duas independentes**, **D / E** escolhe a mão controlada pelo cursor. | **Par espelhado** usa um dedo. **Duas independentes** usa dois. |
| Profundidade e rotação | **W/S** muda a profundidade e **Q/E** gira a mão. | O arraste conserva o plano inicial. Use os botões de rotação. |
| Câmera | Botão direito orbita, roda aproxima e **↑/↓** alteram a altura. | Em **Câmera**, um dedo orbita e a pinça aproxima. |
| Restaurar | **R** reinicia. | Toque em **Reiniciar**. |
| Pirulito | Em **Pirulito**, clique e arraste ou use **Espaço** para oferecer/recolher. | Em **Pirulito**, arraste a peça ou use o botão de ação. |
| Camisola | Clique na alça, mova o mouse para cima e clique para soltar. | Agarre a alça e puxe para cima. Levante o dedo para soltar. Nos dois modos, **Recolocar** veste novamente. |

Para experimentar o layout touchscreen com um mouse, escolha **Touchscreen** e mantenha o botão esquerdo pressionado como se fosse um dedo. Esse ensaio simula um único contato. As bancadas respondem a toque ou mouse diretamente.

## Validação de regressão

O teste `tests/platform_controls_test.gd` envia eventos de mouse, teclado e toque à cena principal. Verifica seleção automática e manual, persistência, clique para pegar e soltar, profundidade, rotação, câmera, espelhamento, pirulito, camisola e encerramento de vínculos ao trocar de modo. Também confere que o evento de mouse emulado pelo toque não cria uma segunda pega.

Para repetir todos os testes, execute os scripts em `tests/` com a opção `--headless` do Godot. Exemplo para esta suíte:

```bash
godot --headless --path /caminho/do/projeto -s res://tests/platform_controls_test.gd
```

No PC gráfico, abra o projeto e confira uma pega enquanto move a câmera. Em seguida, troque para **Touchscreen** e experimente o mouse como dedo. No Android, confira o modo automático e o toque com dois dedos. Os testes automatizados foram executados no Godot sem interface. A renderização e o comportamento real de entrada em Windows e Android continuam sujeitos a essas verificações no dispositivo.
