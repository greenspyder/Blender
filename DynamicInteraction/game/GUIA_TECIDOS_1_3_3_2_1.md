# ROSE 1.3.3.2.1 — Cloth Physics Refinement

## Começar

Extraia o ZIP inteiro numa pasta nova, importe `project.godot` no Godot 4.7.2 e execute o projeto. A simulação principal, as ações simultâneas, o editor de poses e a câmera flutuante permanecem. Não foi adicionada uma bancada pública. Um pano num suporte ao lado da personagem permite interação com uma superfície independente na própria cena.

Escolha **Vestuário** no seletor superior. Toque/arraste o pano: a tração atua num triângulo físico, propaga-se pela rede de partículas e forma dobras. Ao soltar, gravidade, elasticidade, amortecimento e contatos determinam a acomodação. No PC use o botão esquerdo. Trocar para Corpo ou Câmera libera o vínculo sem interromper as ações. A pinça continua pertencendo ao modo Câmera.

A roupa vestida recebe movimento secundário físico pequeno sobre o skinning original. O arrasto também pode selecionar a roupa, mas o deslocamento permanece limitado para preservar ajuste, alças, bordas e cobertura. Esta entrega não implementa remoção nem reposicionamento livre de roupas. Para observar a deformação maior solicitada, utilize o pano independente.

## Personalizações → Tecidos

Abra **Menus → Personalizações → Tecidos**. Essa seção começa recolhida. Selecione Leve, Natural, Elástico, Rígido ou Personalizado. Os presets alteram propriedades físicas; preservam os materiais e as texturas das roupas.

| Propriedade | Efeito |
| --- | --- |
| Massa por área, g/m² | Distribui massa entre as partículas pela área dos triângulos. A roupa usa a área da malha original, agrupada na malha física reduzida. |
| Complacência estrutural | Inverso da rigidez da restrição de distância: valores menores resistem mais ao alongamento. |
| Complacência à dobra | Resistência aproximada à flexão, calculada com distâncias entre vértices opostos de triângulos vizinhos. |
| Amortecimento | Dissipa velocidade ao longo do tempo; não elimina a gravidade. |
| Atrito | Reduz o movimento tangencial quando há contato. |
| Extensão máxima | Alvo de enrijecimento/limitação iterativa. Com um número finito de iterações pode haver excesso transitório; veja os picos medidos na validação. |

**Salvar tecido personalizado** grava os seis parâmetros e a qualidade em `user://cloth_material.cfg` usando arquivo temporário e renomeação. Ao reabrir, um perfil válido é reaplicado. Selecionar Personalizado relê o último perfil salvo; editar um slider marca o perfil como Personalizado. **Restaurar tecido Natural** repõe os parâmetros naturais. Essa biblioteca é separada das poses e dos perfis musculares.

**Preferências → Alisar vestuário** libera a tração e restaura as posições de referência do tecido. A gravidade volta a atuar imediatamente. Não se trata de fixar a roupa numa forma arbitrária depois da soltura.

## Qualidade e Android

| Qualidade | Iterações: pano / roupa | Atualização visual máxima |
| --- | --- | --- |
| Econômico | 3 / 2 | 15 Hz |
| Equilibrado | 4 / 3 | 24 Hz |
| Detalhado | 6 / 4 | 30 Hz |

Android inicia em Econômico quando não há uma preferência salva; outros sistemas iniciam em Equilibrado. A simulação de tecido continua usando subpassos de até 1/120 s. A frequência, os corpos, as massas e as iterações do Active Ragdoll não são reduzidos. A frequência visual da malha é independente da frequência da física.

A troca de qualidade não remonta a malha nem teleporta partículas. A resolução física é fixa durante a sessão: 88 partículas no pano e 79 na roupa do modelo atual. Outros modelos podem produzir outra contagem no agrupamento espacial. Não há troca automática de resolução em movimento, pois isso exigiria transferência de estado e validação adicional de costuras. A malha visual do pano subdivide a rede; as roupas conservam sua topologia original.

O pano pode suspender cálculos quando está quieto, sem tração e distante de colisores móveis; a aproximação de um colisor o acorda. A roupa acompanha o corpo continuamente. O custo é maior que o antigo shader: **não há comprovação de FPS nem autonomia de bateria no Android físico**. Comece em Econômico e observe custo/estabilidade no seu aparelho antes de aumentar a qualidade.

## Auditoria e decisão técnica

- `gameplay/wardrobe.gdshader` fazia um relevo gaussiano visual com um centro por malha. `interaction_mode_manager.gd` substituía os materiais por um shader simplificado. A cena principal agora usa uma rede física e conserva os materiais originais por superfície. O shader antigo permanece no projeto para manutenção/histórico, sem um segundo deformador concorrente na cena principal.
- `direct/fabric.gd` já continha partículas, massa por área, multiplicadores de restrição, diagonais, resistência à dobra, contato e atrito. A formulação de distância foi reaproveitada e separada da interface e dos obstáculos fixos da bancada antiga. O módulo novo aceita geometria e colisores fornecidos pelo chamador.
- `direct/garment_cage.gd` e `garment_pull.gd` forneceram o precedente de uma malha física reduzida separada da malha visual. Sua remoção/reposição orientada por trajetórias não foi ligada ao Active Ragdoll: pressupõe poses e referenciais próprios. As cenas anteriores continuam funcionando.
- `surface_picker.gd` é reutilizado para selecionar triângulos skinned e obter as posições de referência. Ossos, pesos, UVs, índices, blend shapes e materiais são conservados. Não há edição direta dos ossos físicos.
- O rig fornece os colisores atuais de cápsulas, esferas e caixas; piso e banco também entram no contato. A resposta é unidirecional: os tecidos recebem o movimento corporal, mas não aplicam forças de reação no ragdoll.
- A primeira malha física vestida tinha 229 partículas e custou aproximadamente 10–12 ms por passo nos ensaios iniciais. Agrupamento mais amplo e filtragem espacial das colisões reduziram a malha para 79 partículas. A configuração final e seu custo estão registrados no relatório.

## Como funciona

`cloth/xpbd.gd` integra velocidade e gravidade, resolve restrições de distância com complacência dividida por `h²` e multiplicadores acumulados dentro do passo, limita extensão, projeta contatos e aplica atrito. A dobra é uma aproximação por distância entre vértices opostos, não um modelo completo de casca. O vínculo de toque tem complacência e força limitada. A API `begin_hold(face, bary, goal)` / `release()` prepara a integração futura com mãos físicas sem implementá-las novamente.

`cloth/accessory.gd` constrói a superfície independente e sua malha visual subdividida. Os dois cantos superiores são costurados ao suporte. Não há shape keys controlando as dobras.

`cloth/worn_layer.gd` agrupa vértices da roupa em uma malha física reduzida. O skinning dá os alvos móveis; a simulação calcula deslocamentos secundários ao redor deles. Uma interpolação por três partículas suaviza a transferência para a malha visual. Bordas topológicas conservam suas posições skinned; normais geométricas acrescentam apenas sua variação às normais originais, preservando a iluminação de autoria. O limite de movimento secundário é proporcional ao comprimento de perna do CharacterProfile.

`cloth/controller.gd` coordena colisões, subpassos, seleção, qualidade e salvamento. `cloth/material_profile.gd` guarda as propriedades, independentemente dos nomes de ossos/peças. As roupas vêm de `CharacterProfile.mesh_roles`, e o tamanho de referência vem do perfil. O BUBUROSTO não foi integrado nesta versão.

Base conceitual: Macklin, Müller e Chentanez, *XPBD: Position-Based Simulation of Compliant Constrained Dynamics* (2016), https://mmacklin.com/xpbd.pdf. A implementação usa a formulação de restrição complacente como base; não reproduz todos os métodos/material models do artigo.

## Limitações reais

- Roupa vestida é um modelo híbrido: skinning para forma principal, física limitada para movimento secundário. Não é uma roupa inteira solta ao redor de um corpo. Bordas/alças permanecem ajustadas; a faixa final protege a cobertura mesmo quando um colisor aproximado pediria um deslocamento maior.
- Não há autocolisão entre todas as faces, colisão tecido–tecido, rasgos, atrito estático completo ou detecção contínua. Dobras muito apertadas podem se atravessar; objetos muito rápidos podem atravessar entre subpassos. As cápsulas representam segmentos, não a superfície exata da pele. Interpenetrações legadas não foram eliminadas universalmente.
- O picker da roupa usa a superfície skinned antes do pequeno movimento secundário. O pano independente é selecionado sobre os triângulos físicos atuais.
- O material original pode mostrar brilho/detalhes diferentes do shader simplificado da 1.3.3.2; texturas e propriedades de autoria agora são mantidas. As normais são atualizadas, mas os tangentes de normal map permanecem os originais; torções grandes exigiriam uma reconstrução mais completa.
- A reconstrução de ArrayMesh e das normais é feita na CPU para preservar os materiais. Há custo adicional real. Não se deve interpretar os números do host como previsão de FPS em um celular.

## Validação manual Android

1. Execute o ZIP novo no editor Godot, confirme início direto e menus recolhidos.
2. Em Vestuário, arraste o canto inferior do pano, mantenha por um segundo e solte. Observe propagação, dobras e acomodação. Compare Natural, Elástico e Rígido com o mesmo gesto.
3. Combine Sentada + Flexão + Olhar; depois escolha Agachada, Inclinação e Caminhada. Confira alças, barra, cós, bolsos, cobertura e contato com o banco.
4. Troque Corpo/Vestuário/Câmera durante as ações. Use pinça, sliders e menus. Confirme que trocar modalidade solta o tecido e mantém as ações.
5. Salve um tecido personalizado, feche e reabra. Confira parâmetros e qualidade. Restaure Natural.
6. Em retrato/paisagem, teste alcance e rolagem da seção Tecidos. O painel continua recolhível.
7. Em Visualização, ative Desempenho e estabilidade para ver custo da física e da reconstrução da malha. Compare Econômico/Equilibrado por cinco minutos, anotando aparelho, FPS, aquecimento, travamentos e eventuais interpenetrações.

Consulte `VALIDACAO_TECIDOS_1_3_3_2_1.md`. Os ensaios automatizados usam física real do engine, mas os gestos são sintéticos; não houve execução em dispositivo Android físico.
