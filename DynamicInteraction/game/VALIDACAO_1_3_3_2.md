# Validação — ROSE 1.3.3.2

Data: 27/11/2026. Base: commit `81c366684e3322de00308a8065c056aae3120e45` (1.3.3.1).
Entrega: branch `rose/action-composer-gameplay-1.3.3.2`.

## Ambiente e verificações realizadas

Godot **4.7.2.stable.official.ed1daf0bf**, Linux. Física executada de verdade no engine, sem mocks de gravidade, articulações ou contatos. Testes determinísticos usam `--fixed-fps 60`; o Active Ragdoll mantém seus **120 Hz**, 16 corpos e os parâmetros anteriores.

- **82 scripts GDScript:** compilados individualmente com `--check-only`, nenhum erro de sintaxe ou arquivo com mistura de tabs/espaços na indentação.
- **25 scripts de teste:** aprovados. Os 22 testes anteriores permanecem, além de `gameplay_test`, `gameplay_visual_check` e `gameplay_cost_test`.
- Importação do projeto: concluída sem erros. Logs e resultados JSON em `validation_1_3_3_2/`.
- Renderização real via OpenGL Compatibility/Mesa llvmpipe em X11: tela principal e menus em retrato/paisagem. O driver virtual não permite mudar VSync e emite um aviso; não houve erro de script/shader na execução final.
- O teste visual também verifica retângulos do painel e câmera. A auditoria visual verificou personagem vestida centralizada, controles recolhidos, menu de ações e ausência inicial de diagnósticos.

Não foram executados testes em dispositivo Android físico. Eventos de touchscreen nos testes são sintéticos. FPS móvel, latência do dedo, teclado virtual, recortes da tela e aquecimento continuam pendentes do roteiro manual.

## Novos comportamentos testados

Composição de Sentada + Flexão + Olhar; pausa individual; ritmo independente; encerramento sem repetição e reativação; bloqueio de flexão na caminhada; mudança real do relógio da caminhada a 2x e pausa com física ainda ativa; transições para agachada, inclinada e em pé; persistência/duplicação/renomeação/exclusão de múltiplos perfis; gravação e cópia de poses separadas; limites anatômicos após composição; estímulo externo por duração; seleção skinned da roupa e alteração/restauração do parâmetro de relevo; alternância entre modalidades sem recriar o corpo; órbita por evento de toque; persistência da modalidade; interface mínima e menu fechado por padrão.

Os testes legados cobrem Active Ragdoll, queda e recuperação, Dynamic Pose Reference, Full Body Rig, Ground Contact, remapeamento semântico de outro rig sintético, controles de PC/toque e sistemas anteriores de contato/tecido. O rig sintético não é BUBUROSTO.

## Medidas físicas da execução final

| Cenário | Resultado observado |
| --- | --- |
| Sentada + Flexão + Olhar | Erro RMS máximo 0,0420 m; folga articular máxima 0,0004 m; contato da pelve com banco em 360/360 passos amostrados. |
| Agachada após caminhada/transições | COM 0,788 m; erro RMS 0,0690 m; folga 0,0001 m. |
| Inclinada após transições | COM 0,955 m; erro RMS 0,0557 m; folga 0,0001 m. |
| Em pé após transições | COM 0,972 m; erro RMS 0,0562 m; folga 0,0001 m. |

O teste exige erro inferior a 0,09 m, folga inferior a 0,04 m e apoio no banco em mais de 300/360 passos para o cenário composto. RMS mede diferença entre alvos e segmentos; não é a folga das juntas. Os valores não prometem estabilidade de qualquer pose/preset ou velocidade, especialmente em Passive/Livre.

## Comparação de custo

Medição sequencial headless no mesmo host, depois de aquecimento, 720 passos por cena (seis segundos simulados). Inclui o laço do engine e script, não o custo de desenho em uma GPU móvel.

| Cena | ms host/passo | ms host/segundo simulado |
| --- | ---: | ---: |
| Active Ragdoll 1.3.3.1 | 0,784 | 94,1 |
| Gameplay 1.3.3.2 | 0,644 | 77,3 |

São amostras de um host compartilhado; a diferença não demonstra ganho garantido de desempenho. O teste não usa limiar de FPS como critério de estabilidade. Velocidade das ações não altera `Engine.physics_ticks_per_second`.

## Alterações na base

O controlador físico `active_body.gd`, massas, ganhos, colisores e solver não foram recalibrados. Foram acrescentados hooks de composição de referência e relógio de animação que retornam o comportamento original nas cenas antigas. O registro de Skin no adaptador legado passou a anteceder a atribuição da malha ampliada: isso corrige o erro de renderer `bs > sbs` observado no ensaio visual, preservando os pesos.

## Limitações e reprodução

O vestuário desta atualização é um ajuste visual local, não uma nova simulação de tecido. Há uma região editável por malha e limite pequeno de deslocamento externo. Capturas headless não validam aparência. Os detalhes e o roteiro Android estão em `GUIA_GAMEPLAY_1_3_3_2.md`.

Para repetir importação, auditoria e todos os testes: `python3 tools/validate_gameplay.py`, com `godot` disponível no PATH. O runner usa um diretório de dados temporário no Linux. Para renderizar as duas orientações, execute `godot --path . --script res://tests/gameplay_visual_check.gd` em um desktop; as imagens ficam em `user://rose-game-landscape.png` e `user://rose-game-portrait.png`.
