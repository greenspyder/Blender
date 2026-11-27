# Rosé 1.3.1 · Rig de corpo inteiro e integração

Importe `project.godot`, execute e abra **Bancada → Articulações → Corpo inteiro · 1.3.1**. Você também pode executar `rig/full_body_lab.tscn` pelo editor. A mesma cena usa toque ou mouse. O jogo principal continua com a rig e as interações da 1.2.12. A bancada usa uma instância separada e vestida para você estudar a nova rig.

## Como estudar pela bancada

1. Comece em **Em pé**, com **Esqueleto**, **Centro de massa** e **IK e apoios** ligados. A cruz amarela marca o centro de massa. A linha amarela projeta esse ponto no piso. As cruzes verdes são alvos de IK em alcance. Em vermelho, veja quando o pé não alcança o alvo dentro dos limites.
2. Alterne **Transferência E** e **Transferência D** e observe a direção da pelve e a projeção da massa. Mude o menu **Apoio de referência** para escolher os dois lados, um lado ou **Livre**.
3. Em **Inclinar**, deixe os pés apoiados e mova primeiro a **Lombar**, depois o **Tórax**. Use o controle de câmera para conferir de perfil e observe onde a inclinação começa. O arco vermelho mostra a faixa de inclinação da articulação selecionada.
4. Para isolar quadril, joelho ou tornozelo, escolha **Livre** ou desative **IK de apoio**. Em **Sentar · referência**, experimente dobrar apenas um joelho e compare os dois lados. Em **Suspender**, veja as pernas acompanharem a subida da pelve. **Sentar** e **Reclinar** são poses de referência sem assento físico.
5. Desative os controladores separadamente e observe o resultado. Desativar **Cadeia das pernas** deixa a pose local de repouso nas pernas. Desativar **IK de apoio** mantém as articulações diretas sob controle. Ative **Distribuição de massa** para comparar a contribuição de cada segmento. Cruzes maiores indicam maior massa.

## Auditoria

| Região ou sistema | Origem confirmada | Tratamento nesta versão |
| --- | --- | --- |
| Hierarquia | Tanto a importação do GLB no Blender quanto a importação na Godot mostram nove ossos. A cadeia central era `Base → Spine → Head`, com dois braços saindo de `Spine`. `tools/rig_11.py` gera exatamente essas cadeias. | Na bancada, uma cópia em memória acrescenta `Lumbar` e duas cadeias de coxa, canela e pé. Mantém as posições de repouso existentes e redistribui pesos da região lombar e das pernas. |
| Joelhos e pés | O GLB não tinha articulações das pernas. `idle_knees` criava uma dobra na malha sem mover ossos. A cena antiga não tinha alvos articulares para ancorar ou liberar pés. Alguns colisores de interação e roupa usavam alturas aproximadas fixas. | A bancada usa flexão esquelética. O peso dos alvos de apoio transita suavemente de zero a um. Os colisores da cena principal continuam compatíveis com a malha legada. |
| Tronco e braços | O controlador anterior redefinia a pose completa e escrevia a reação procedural em `Base`, `Spine`, `Head` e braços. O GLB auditado não contém clipes. | A bancada coordena pelve, lombar, tórax, cabeça e membros em uma passagem. Reusa o solver de braço existente. A solução de apoio e a pose livre são combinadas pelo mesmo coordenador. |
| Massa | Na cena principal, rigidez de reação, amortecimento e limite de força pertencem ao sistema de vínculo. Não havia centro de massa esquelético global. | A bancada estima o centro de massa pela média ponderada das posições dos segmentos. A massa em kg e suas proporções ficam no perfil. A estimativa é diagnóstica. Rigidez e tempo de transição têm papéis distintos e a suspensão da bancada não depende de diminuir a massa. |

O arquivo `Rose_Contato_1_0.blend` disponível usa o formato de save 5.01. O Blender 4.3.2 deste ambiente não abriu esse arquivo. A comparação acima se baseia nos scripts de geração e na importação do GLB que a cena principal usa. Os originais e os GLBs existentes foram preservados.

## Contrato do perfil

Duplique `rig/rose_131.tres` e abra o arquivo pelo Inspector. **Model** aponta para uma cena importada. **Bones** traduz funções, como `thigh_l`, para nomes usados na sua armature. **Mesh Roles** registra as partes do modelo. **Shape Keys** documenta os nomes que precisam ser preservados para as interações anteriores. Os limites angulares, o deslocamento da sola, a resposta de pose e a massa ficam no mesmo perfil.

| Função | Nomes de referência | Hierarquia mínima |
| --- | --- | --- |
| Centro e coluna | `Base`, `Lumbar`, `Spine`, `Head` | Pelve → lombar → tórax → cabeça |
| Membros superiores | `UpperL/R`, `ForeL/R`, `PalmL/R` | Tórax → braço → antebraço → mão por lado |
| Membros inferiores | `ThighL/R`, `ShinL/R`, `FootL/R` | Pelve → coxa → canela → pé por lado |
| Auxiliares opcionais | `Neck`, `ClavicleL/R`, `ToeL/R` | Pescoço entre tórax e cabeça, clavículas entre tórax e braços, dedos do pé filhos do pé. São aceitos como parte da hierarquia, sem controle procedural dedicado nesta versão. |

A cadeia de braço do cotovelo à mão e a cadeia de perna da coxa ao pé devem ser diretas. Ossos auxiliares de controle do Blender ficam separados das cadeias deformadoras. Use metros, escala unitária no objeto e chão em zero. Na cena da Godot, o modelo fica com **+Y para cima, +Z à frente, lado L em X negativo**. No Blender, mantenha **Z para cima** e confira a direção frontal depois da conversão do exportador. O solver calcula os segmentos pelos pivôs do repouso. Um bone roll coerente facilita a autoria e a inspeção de cada eixo no Blender.

Mantenha a neutralidade das shape keys em repouso. Preserve `blink_l`, `blink_r`, `smile`, `brow_up`, `mouth_open`, `chest_press` e `hip_press` para as interações correspondentes. Os drivers artísticos permanecem no Blender. Na engine, as respostas existentes configuram os valores de morph separadamente do esqueleto. Use materiais PBR exportáveis com Principled BSDF, UVs e texturas incluídas. Vincule roupa e calçado à mesma armature. Para o laboratório, a nova base usa as cores e os materiais importados.

## Blender · ossos, pesos e poses

1. Crie uma cópia de trabalho. Você pode importar o GLB atual para ver os nove ossos ou gerar uma base vestida com os 16 ossos da bancada. No PC, com o projeto já importado pela Godot, rode a partir da pasta do projeto:

   ```bash
   godot --headless --path . --script res://tools/export_rig_base.gd -- res://rose_base_trabalho.glb
   ```

   O comando cria um arquivo novo. Importe-o no Blender em **File → Import → glTF 2.0** e salve sua cópia como `.blend`. Você também pode escolher um caminho absoluto fora da pasta do projeto.

2. Selecione a armature e entre em **Edit Mode**. Em vista frontal, confira o centro das duas articulações do quadril. Em vista lateral, alinhe cada coxa com o joelho e cada canela com o tornozelo. Em **Bone Properties → Relations**, confira os pais da tabela. Para corrigir um osso, mova cabeça e cauda em repouso. Confira o roll com os eixos locais exibidos.
3. Com o corpo selecionado em **Weight Paint**, inspecione os grupos `Base`, `Lumbar`, `ThighL/R`, `ShinL/R` e `FootL/R`. Teste a fronteira coxa–pelve com um lado de cada vez. Suavize a passagem no joelho. Em **Weights → Normalize All**, normalize os pesos. Inspecione também o short, os bolsos e as pantufas. Antes de mexer na topologia, salve uma cópia que preserve as shape keys.
4. Em **Pose Mode**, teste inclinação da lombar, rotação da pelve, joelho esquerdo e tornozelo direito individualmente. Comece com ±15° e aumente até a pose sentada. Inspecione a silhueta e a sobreposição da roupa de frente e de perfil. Depois limpe a pose com **Pose → Clear Transform → All** e valide a neutralidade das shape keys.
5. Corrija no Blender centros anatômicos, separação de grupos, perda de volume, colisão visual por pesos e topologia. Corrija na Godot atraso de alvo, condições para liberar apoio, ordem de cálculo, limites do solver e coordenação de controles.

## Exportar do Blender e configurar na Godot

1. Selecione a armature e as malhas do personagem. Exporte por **File → Export → glTF 2.0**, formato **glTF Binary (.glb)**. Use seleção de objetos, **Skinning** e **Shape Keys**. Em **Data → Armature**, habilite **Deformation Bones Only** ao exportar morphs. Confira que cada osso obrigatório participa da cadeia deformadora. Use **Animations** somente para ações que queira testar em uma cena separada. A bancada usa comandos procedurais em vez de tocar um clipe do modelo.
2. Coloque o novo GLB em `assets/` com outro nome. Aguarde a importação. Duplique o perfil, arraste o novo GLB para **Model** e desmarque **Add Legacy Rose Bones**. Ajuste **Bones** se nomeou a sua armature de outro jeito. No nó **CorpoInteiro** da cena da bancada, escolha o perfil duplicado. Para preservar sua configuração, salve uma cópia da cena.
3. Execute. A bancada exibe problemas de hierarquia ou funções ausentes antes de executar o solver. Se a postura ficar invertida, verifique os eixos e a orientação do modelo. Se só a roupa falhar, revise se usa o mesmo armature e os grupos corretos. Ajuste **Sole Offset** com o piso em zero. Repita os testes de um lado só antes de ativar os dois apoios.
4. A cena principal ainda usa o objeto e os mapeamentos de interação da 1.2.12. O ponto de troca do modelo genérico é a bancada nesta versão.

Referências oficiais [Formats 3D na Godot](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html) · [glTF no Blender](https://docs.blender.org/manual/en/latest/addons/import_export/scene_gltf2.html)

## Validação e limites

| Teste | 1.2.12 | 1.3.1 na bancada |
| --- | --- | --- |
| Ossos de deformação | 9 | 16 |
| Joelho esquerdo | Sem ângulo esquelético | 27,4° em pé e 83,0° na pose sentada |
| Altura do pé na suspensão guiada | Sem transição equivalente | Pé E a +28,3 cm em relação ao repouso. Maior deslocamento medido por quadro a 60 Hz de 3,2 cm no trajeto testado |
| Integridade na pose sentada | Sem pose esquelética equivalente | Pesos normalizados e barras rígidas com comprimentos preservados. Razão de alongamento máximo das arestas amostradas na região, corpo 1,83× e short 1,93× |

O alongamento indica que a base de pesos gera deformação visível e ainda requer refinamento artístico para poses de grande amplitude. A amostra de arestas não mede conservação de volume nem cobre todas as combinações. Na prova de exportação, a base gerada pela bancada passou pelo Blender 4.3.2, foi novamente exportada para GLB e voltou à Godot com os 16 ossos, sem erros de contrato e com a shape key `smile` preservada.

O teste `tests/full_body_rig_test.gd` mede cadeias, apoio, suspensão, limites e troca de nomes no perfil. As regressões foram executadas em Godot 4.7.2 headless. Sem um display gráfico utilizável no executor, as verificações de renderização e a experiência no Android físico ficam para o roteiro abaixo.

### Roteiro no Android

1. Rode o jogo e confirme que a mão responde ao toque e ao arraste. Abra **Bancada → Articulações → Corpo inteiro · 1.3.1**.
2. Gire a câmera de frente até a lateral. Alterne **Em pé → Inclinar → Suspender → Em pé**. Veja se as pantufas acompanham os pés, a roupa permanece vestida e a volta ao apoio ocorre de forma contínua.
3. Desative **IK de apoio**, selecione um tornozelo e mude apenas o primeiro deslizador. Faça o mesmo em um joelho. Repita com **Cadeia das pernas** desativada e compare o resultado.
4. Teste as duas transferências, ative a distribuição de massa e confira se o marcador amarelo muda de lado. Volte ao jogo e teste os vínculos anteriores. Confira também o modo Desktop com mouse no PC.

## Próximas versões

| Versão | Onde encaixa |
| --- | --- |
| 1.3.2 · Balance & Ground Contact | Substituir os alvos de referência por contatos de chão, usar a projeção do centro de massa para escolher apoios e recuperar equilíbrio. |
| 1.3.3 · Active Ragdoll | Derivar corpos articulados do perfil, aplicar alvos de pose com força muscular limitada, separar massa, rigidez e amortecimento e misturar física e pose em uma única etapa responsável pelo esqueleto. |
| 1.3.4 · Modular Model Integration | Levar o perfil para o jogo principal, reconfigurar colisores, tecidos e regiões de toque pelo modelo e validar clipes e perfis de outras revisões. |

As poses guiadas desta entrega demonstram articulação e liberação dos apoios. Levantar a personagem pelo tronco durante o jogo e fazer o corpo encontrar o chão com colisões ainda depende das duas próximas fundações físicas.
