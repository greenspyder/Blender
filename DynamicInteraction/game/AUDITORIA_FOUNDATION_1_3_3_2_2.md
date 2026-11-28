# ROSE 1.3.3.2.2 · Auditoria da fundação

Na base `8087f26a15c7125089aa6d1306be354e9bb60236`, a malha distal das mãos recebia pesos das pernas ao iniciar o jogo. A versão corrigida preserva os pesos de autoria, recupera o ciclo de agachamento da 1.3.2 e permite acomodar áreas pequenas da roupa com o próprio solver de tecido. A validação foi feita na Godot 4.7.2 oficial, revisão `ed1daf0bf`, em Linux x86-64. O equipamento Android físico continua como etapa de campo. [Guia de uso e roteiro no aparelho](GUIA_FOUNDATION_1_3_3_2_2.md)

## Alcance e origem das correções

O ponto de partida foi o projeto completo do hotfix. Os 370 arquivos da distribuição foram conferidos pelos hashes dos blobs da árvore `DynamicInteraction/game` do commit-base. O inventário da versão final abrange 100 scripts GDScript, 15 cenas, seis recursos .tres, quatro GLBs e sete scripts Python. As referências literais de recursos resolveram, as 15 cenas abriram em processos da Godot e a cena principal continuou sendo `gameplay/main.tscn`. A verificação individual de sintaxe e indentação passou nos 100 scripts. O manifesto apresenta as dependências por arquivo, os nomes de malhas, materiais, skins e contagens de animações dos quatro GLBs. [Inventário](validation_foundation/inventory.json) · [Sintaxe](validation_foundation/syntax.json)

| Área auditada | Problema ou dependência encontrada | Mudança e verificação |
|---|---|---|
| Blender, GLB e adaptação da skin | O GLB já atribuía antebraços e palmas corretamente. Na conversão do rig de nove ossos, a faixa de altura que recebia coxa/canela também atravessava as mãos. | O adaptador redistribui somente a parcela original de pelve e tórax. A amostra distal perdeu a influência indevida das pernas. GLBs, materiais e texturas de origem permaneceram idênticos à base. |
| Braços e calçados | A referência de repouso abria os cotovelos; o polo precisava acompanhar o tronco. O nome importado da segunda pantufa era `Slipper_001`; a busca por `Slipper.001` deixava uma peça fora da nova skin. | Referência de elevação, flexão e giro axial e direção do polo no perfil. Alvos bilaterais no referencial do tórax, ajuste para a base sentada e balanço alternado na marcha. O teste inspeciona os pesos das duas pantufas e seus pés. |
| Full Body Rig, solo e musculatura | A referência vertical em pé cedia sob o próprio peso e dobrava os joelhos. A área dos pés usada para diagnosticar o equilíbrio não acompanhava corretamente a orientação física em todos os usos. | A referência de solo leva em conta a fração de peso assistida do perfil muscular. Essa compensação diminui progressivamente para sentar e cair. O núcleo constrói o contorno dos pés a partir dos corpos girados e o compartilha com a avaliação de apoio. Foram medidos repouso, marcha, banco, queda e recuperação. |
| Bancada histórica e Action Composer | O jogo oferecia uma base agachada estática e uma flexão pequena. O ciclo histórico de descida e subida havia ficado na bancada. A rotação do olhar podia sobrescrever outra contribuição. | A bancada e o jogo usam a mesma curva do agachamento. O compositor soma as contribuições em seus papéis antes de resolver IK, aplica limites e mantém relógios individuais. A interface reflete o término de uma repetição única. |
| Roupas e acessórios | A escolha do primeiro triângulo do proxy dava uma alavanca diferente da área tocada. A roupa inteira tinha pouca precisão para ajustar bordas estreitas. Havia reconstruções mesmo com a peça acomodada. | A seleção parte da superfície visível, usa seis zonas do perfil ou o triângulo mais próximo do proxy e reparte a tração por pesos. As zonas têm curso e força limitados. A roupa usa o mesmo XPBD. O pano independente passa a ter suspensão opcional de física, desenho e seleção. |
| Custo de pele, malha e contatos | ArrayMesh e dados estáticos eram recriados nas atualizações visuais. Formas e constantes de restrição eram consultadas repetidamente. | Recurso dinâmico persistente, envio parcial de posições e normais nos formatos suportados, reaproveitamento de buffers de trabalho, dados de colisores e constantes por passo. Os transformes dos colisores móveis continuam a ser lidos e a malha visual continua independente da resolução física. |
| Touchscreen, câmera e menus | Uma troca de foco/modalidade podia deixar um arrasto ativo. A órbita precisava atravessar o limite angular e o estado de um controle podia ficar defasado após o término de uma ação. Textos de diagnóstico eram reconstruídos em frequência física. | Encerramento da captura no cancelamento, atribuição de dedos à órbita e à pinça, retorno do nome da área de roupa e sincronização dos controles. Textos de status são amostrados a 10 Hz e a sobreposição técnica é optativa. A física mantém seu relógio. |
| Personalizações e partida | Gravação de poses duplicava a lógica de substituição. Trocar a identidade de armazenamento do aplicativo perderia o acesso aos dados locais existentes. | A biblioteca usa o mesmo fluxo de validação, arquivo temporário e substituição. O formato anterior, os nomes das bibliotecas de poses e perfis e a identidade de dados foram mantidos. A versão está em `config/version`. O jogo abre diretamente na simulação. |
| Contrato de personagem e seleção | Um osso auxiliar entre dois papéis semânticos podia invalidar uma hierarquia válida. A seleção pressupunha quatro influências e índices explícitos. | Caminho opcional de esqueleto no perfil, validação de ancestralidade, comprimentos e massas, leitura de superfícies rígidas ou skinnadas com quatro/oito influências e triângulos sem índice. Teste com osso de torção intermediário, hierarquia inválida e influência ativa no oitavo slot. |
| Interação legada desde 1.0 | As cenas de mãos, contato, manipulação direta, mecânica e precisão têm seus próprios controladores, apropriados às respectivas cenas. Ativar esses controladores sobre o jogo acrescentaria outro escritor dos mesmos ossos. | Cenas históricas, modelos e ferramentas de manutenção preservados e abertos no inventário. No jogo o arrasto usa o único ponto de aplicação de força limitada do Active Ragdoll. Identificação de contato e entrada de múltiplos dedos podem ser reutilizadas na próxima versão. |

## Braços, agachamento e apoios

Comparamos a personagem vestida em pé, sentada, agachada e caminhando, nas vistas de 0°, 65° e 145°, com a mesma câmera e o mesmo roteiro. Dos 110 vértices distais amostrados na skin, 96 recebiam peso de coxa ou canela na base. O total caiu para zero. Em um segundo teste, os 155 vértices com mais de 99% de influência autoral de antebraço/palma conservaram essa soma, com desvio máximo de 0,000016. Para as arestas da região distal, o percentil 95 da razão comprimento deformado/repouso ficou entre 1,521 e 1,589 na base e entre 1,000 e 1,005 após a correção. São indicadores da mão deste modelo e destas posturas. [Medições por postura](validation_foundation/performance.json) · [Teste dos pesos e da marcha](validation_foundation/foundation_motion_test.log)

| Observação visual | Comparativo da execução |
|---|---|
| Em pé, mãos junto aos punhos e ambas as pantufas acompanhando os pés | [Três ângulos em pé](validation_foundation/visual/em_pe.jpg) |
| Sentada, cotovelos e antebraços acompanhando a rotação do tórax | [Três ângulos sentada](validation_foundation/visual/sentada.jpg) |
| Agachada, pelve baixa e pernas articuladas | [Três ângulos agachada](validation_foundation/visual/agachada.jpg) |
| Caminhando, oposição dos braços durante o passo | [Três ângulos da caminhada](validation_foundation/visual/caminhada.jpg) |

A base **Agachada** sustenta uma altura. A ação **Agachar** usa a curva do `balance_lab` de 1.3.2, com excursão de referência de 0,29 comprimento de perna e fase de 2 rad/s a 1x. A pelve entra na solução de referência, os dois pés consultam o chão e os motores acompanham o alvo com força limitada. A **Flexão cíclica** continua separada e pode ser usada sentada. A física do ciclo composto com olhar e braços desceu a pelve **23,8 cm** e voltou a **10,0 mm** da altura inicial. A flexão medida no joelho foi de **42,3° a 99,9°**. Houve contato bilateral em **405/405 ticks**, deriva espacial máxima do pé amostrado de **8,3 mm** e afastamento máximo de junta de **0,4 mm**. No teste de base sentada com flexão e olhar, o banco sustentou a pelve em **360/360 ticks**. [Ciclo, apoio e fim individual](validation_foundation/foundation_motion_test.log) · [Composição e banco](validation_foundation/gameplay_test.log)

### Active Ragdoll sob a mesma sequência

O ensaio histórico percorre repouso, marcha, agachar, inclinar, sentar, cair, recuperar e trocar estados. O erro RMS mede a distância entre os pontos físicos e a referência. A penetração usa o canto mais baixo das caixas dos pés em relação ao plano do chão ao longo do ensaio completo.

| Métrica | Base | 1.3.3.2.2 |
|---|---:|---:|
| Centro de massa em pé | 0,965 m | 0,990 m |
| Erro RMS em pé | 26,9 mm | 24,7 mm |
| Apoio bilateral em repouso | 316 ticks | 316 ticks |
| Altura do centro de massa depois da queda | 0,131 m | 0,137 m |
| Altura do centro de massa após Recovery | 0,955 m | 0,978 m |
| Erro RMS após Recovery | 48,1 mm | 51,8 mm |
| Pico de discrepância entre pele e junta | 14,7 mm | 10,8 mm |
| Pico de penetração da caixa do pé | 17,3 mm | 21,2 mm |
| Energia cinética máxima | 123,0 J | 120,8 J |

A recuperação alcançou uma altura maior, com aumento de 3,7 mm no erro final. O pico de entrada do pé no chão aumentou 3,9 mm. Ambos são limites observados para orientar o próximo ajuste de contato. O preset fornecido continua com 16 corpos, 15 juntas, massa total de 56 kg, 120 ticks/s e 48 iterações. No teste de pose personalizada fora da base de apoio, a assistência chegou a zero e a personagem caiu. [Ensaio da base](validation_foundation/active_before.log) · [Ensaio atual](validation_foundation/active_ragdoll_test.log) · [Poses e perda de apoio](validation_foundation/dynamic_pose_test.log)

## Tecido e seleção da superfície

A simulação econômica usa 85 partículas na roupa vestida, incluindo seis pontos para alças, barras e cós, e 88 no pano independente. A posição de ajuste acompanha a peça no espaço do rig. A tração aplicada passa pelo solver; ao soltar, somente parte do deslocamento físico atingido pode permanecer na acomodação. Pontos de costura coincidentes recebem o mesmo deslocamento. O cálculo de normais acompanha a superfície deformada. A escrita parcial mantém índices, UVs, pesos, materiais e bytes das tangentes. Na implementação dummy usada nos ensaios headless, o caminho alternativo atualiza as superfícies no mesmo recurso. No renderizador Compatibility real, cinco das cinco malhas de vestuário usaram atualização parcial. [Leitura da malha enviada ao renderizador](validation_foundation/fit_opengl.log)

No comparativo por toque, o roteiro localizou um triângulo visível da alça direita e arrastou 58 × 10 pixels. Para cada versão, uma segunda execução idêntica sem gesto serviu de controle. Nos mesmos 116 vértices, a diferença RMS passou de **1,16 mm para 15,46 mm** e a máxima, de **4,17 mm para 17,82 mm**. A medida foi lida de `Mesh.ARRAY_VERTEX` após a atualização real. No ensaio separado de liberação, a alça se deslocou 7,65 mm durante seu gesto e conservou 3,52 mm depois. O cós passou por 15,90 mm e conservou 15,89 mm. Nesse ensaio, a diferença entre o deslocamento calculado e o lido, e a diferença entre as duplicatas da costura amostradas, arredondaram para 0,000 mm. [Imagem da tração](validation_foundation/visual/alca.jpg) · [Valores do gesto pareado](validation_foundation/strap_comparison.json) · [Resposta durante as ações](validation_foundation/worn_response_test.log)

O ensaio do pano independente executou os cenários de 30, 60 e 120 FPS de renderização simulados, com extensão relativa máxima de 0,1606 a 0,1611 e velocidade final de 0,0030 m/s. Atrito e contato continuaram respondendo. Ao suspender o acessório, seu estado fica guardado para a retomada. A roupa vestida continua a simular. [Estabilidade do pano](validation_foundation/cloth_physics_test.log) · [Contato e atrito](validation_foundation/cloth_contact_test.log) · [Ajustes e suspensão](validation_foundation/foundation_fit_test.log)

## Desempenho comparável

O mesmo script executou a cena principal nas duas revisões, em Linux, Godot headless, tecido em Econômico, ação de olhar ativa e avanço de renderização fixado em 60 FPS. Cada postura teve 180 ticks de aquecimento e 180 de medição. Foram três processos por condição, com diretório de dados isolado. A ordem das revisões alternou antes/depois, depois/antes, antes/depois. Outras três execuções mediram a versão atual com o acessório suspenso. Os valores abaixo são a mediana entre as médias por execução. O tempo de host inclui a simulação completa e as atualizações visuais headless ocorridas nesse intervalo.

| Postura | Host antes (ms/tick) | Host depois (ms/tick) | Depois sem acessório (ms/tick) | Física do tecido antes → depois (ms/tick) |
|---|---:|---:|---:|---:|
| Em pé | 4,186 | 2,666 | 2,089 | 2,437 → 1,754 |
| Sentada | 4,341 | 3,223 | 2,634 | 2,594 → 1,973 |
| Agachada | 4,127 | 2,626 | 2,068 | 2,501 → 1,809 |
| Caminhando | 3,127 | 2,432 | 2,378 | 1,473 → 1,265 |

Na caminhada, o custo total por tick caiu cerca de 22%. O pico do monitor de memória estática da Godot subiu de aproximadamente **57,46 para 60,02 MiB** nessa postura. Os caches e buffers trazem um custo de memória e o acessório suspenso mantém seus dados para retomada. O relatório bruto contém as nove execuções, p95 da física de tecido, custo por atualização visual e contagem de apoios. [Amostras e medianas](validation_foundation/performance.json)

Em uma execução gráfica por versão, a mediana de CPU para uma atualização visual do tecido caiu de **9,69 para 4,48 ms** caminhando e de **9,88 para 0,20 ms** em pé. O segundo resultado inclui atualizações dispensadas quando a deformação já se acomodou. Usamos OpenGL Compatibility com Mesa llvmpipe. São tempos da rotina de malha no host, e o driver reportou ausência de controle de VSync. O tempo de GPU e o FPS sustentado em um telefone ainda precisam de medição dedicada. [Renderização da base](validation_foundation/visual_before.json) · [Renderização atual](validation_foundation/visual_after.json)

## Evidências e reprodução

- Os 31 testes anteriores e os três novos passaram. Os novos ensaios cobrem pesos das mãos e pantufas, joelhos e apoios durante o ciclo, finalização de ação, seleção de zonas, liberação, costura, suspensão, variantes de skin e limites de força/torque. A suíte inclui os testes legados de câmera, toque, contatos, integridade de malha, persistência e comparação dos perfis. [Resultados dos 34 testes](validation_foundation/results.json)
- Os testes de interface injetaram eventos de toque e mouse. O ensaio gráfico executou retrato e paisagem em X11. As 30 capturas PNG originais incluem 24 vistas do corpo, quatro vistas da alça e duas da interface. As pranchas JPEG fazem apenas recorte, redução e identificação de versão e ângulo. [Registro de interface](validation_foundation/ui_opengl.log) · [PNGs originais](validation_foundation/capturas_godot.zip)
- A distribuição foi extraída em uma pasta nova, com um diretório de dados de usuário vazio. A importação do editor, 30 quadros da cena inicial e os testes de agachamento e vestuário passaram nesse projeto extraído. [Registro do ZIP](validation_foundation/package_smoke.log)
- Para repetir o inventário e a suíte, use a Godot 4.7.2 disponível como `godot` no PATH e Python 3. A partir da pasta do projeto, rode os comandos abaixo. Os resultados vão para `validation_foundation/`. A importação limpa deve preceder a abertura das cenas.

```sh
godot --headless --editor --import --quit
python3 tools/audit_foundation.py
python3 tools/validate_gameplay.py
godot --headless --fixed-fps 60 --script res://tests/foundation_motion_test.gd
godot --rendering-method gl_compatibility --fixed-fps 60 --script res://tests/foundation_fit_test.gd
```

Para comparar revisões, use o mesmo caminho absoluto do script novo para ambas e indique a pasta do projeto a medir. Execute cada processo com um diretório vazio e exclusivo em `XDG_DATA_HOME`. Substitua os caminhos do exemplo. O modo `images` exige uma sessão gráfica e grava os PNGs após o desenho do quadro. O modo `without_accessory` aplica-se à versão atual. Para a alça, rode `tools/garment_capture.gd` da mesma forma com destinos separados e os argumentos finais `control` e `grab`.

```sh
godot --headless --audio-driver Dummy --fixed-fps 60 --path /caminho/da/revisao --script /caminho/da/versao_nova/tools/foundation_probe.gd -- /tmp/rose-custos bench
godot --rendering-method gl_compatibility --fixed-fps 60 --path /caminho/da/revisao --script /caminho/da/versao_nova/tools/foundation_probe.gd -- /tmp/rose-imagens images
```

## Limites e continuidade

**Android.** Os gestos automatizados e as duas orientações foram exercitados no desktop. Latência do toque físico, multitouch real, drivers móveis, aquecimento e memória disponível dependem do aparelho. O tutorial inclui um roteiro de verificação no editor Android, com a mesma cena e qualidade usadas nos comparativos. [Roteiro manual](GUIA_FOUNDATION_1_3_3_2_2.md)

**Malha e corpo.** O perfil legado depende de um GLB compacto sem cadeia articulada completa de clavículas, dedos ou torção do antebraço. Os ensaios cobrem as poses, os gestos e as costuras descritos. O solver aproxima contato por proxies e colisores simples. A cobertura nas zonas configuradas é limitada pelo curso de ajuste e pela vinculação da peça. Contato triângulo a triângulo, autocolisão completa e ausência de recorte em todas as poses extremas continuam fora do que foi validado.

**1.3.3.3 · Mãos físicas.** As cenas históricas em `mobile/`, `dynamic/` e `precision/` já separam dedos de entrada, contato e resolução de pose. Para conectar mãos à cena principal, reutilize esses sinais de intenção e os limites no ponto único `core.apply_grip(papel, ponto_local, alvo_global, dt)`. O núcleo devolve força e torque aplicados. Para tecido, reutilize a seleção da superfície visível e `begin_grip` / `begin_weighted_hold`. Encerrar o contato deve liberar a captura mesmo após rotação de tela ou perda de foco. [Teste do contrato](validation_foundation/foundation_contract_test.log)

**1.3.4 · BUBUROSTO.** O arquivo do segundo modelo já está no repositório. Para sua integração, crie um recurso CharacterProfile próprio com cena importada, caminho do Skeleton3D quando necessário, papéis de ossos e malhas, massa, limites, direção do polo, calçados e zonas de ajuste no espaço de repouso da peça. Use metros, +Y para cima e +Z para a frente no referencial do personagem em Godot. Deixe o adaptador legado desativado para o rig nativo. A primeira aceitação deve conferir bind/rest, escala, correspondência dos lados, pesos e limites em quatro vistas/posturas, depois repetir contato, agachamento, liberação de tecido e custo no aparelho. Nesta entrega, a segunda hierarquia usada nos testes é sintética. A validação visual e física no BUBUROSTO depende da sua integração.
