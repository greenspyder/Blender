# ROSE 1.3.3.2 — Action Composer & Gameplay Interface

> A interação com tecido evoluiu na 1.3.3.2.1. Consulte [o guia atualizado](GUIA_TECIDOS_1_3_3_2_1.md); os parágrafos sobre relevo visual abaixo documentam a versão anterior.

## Instalar e jogar no Android ou PC

Extraia **o ZIP inteiro em uma pasta nova**, importe `project.godot` no Godot e execute o projeto (▶). A entrada agora é `gameplay/main.tscn`: a personagem aparece vestida, com Active Ragdoll ligado e sem diagnósticos. Não é necessário abrir uma bancada. O nome interno do projeto foi mantido para preservar o diretório `user://` e os dados anteriores.

No alto à esquerda estão o seletor **Corpo / Vestuário / Câmera** e **Menus**. No alto à direita, **Câmera** abre o controle flutuante. Os menus são recolhíveis; abra uma seção de cada vez. Deslize o painel para alcançar as opções inferiores. O rodapé indica a postura, o estado muscular e as ações ativas.

## Combinar ações

1. Abra **Menus → Ações** e escolha a postura base: Em pé, Sentada, Agachada, Inclinação, Caminhada ou Personalizada. A postura Sentada disponibiliza um banco físico.
2. Selecione **Flexão cíclica** e ligue **Ativar**. Escolher outra ação no seletor não desativa a anterior.
3. Selecione **Olhar ao redor** e ligue **Ativar**. A lista **Ativas** e o rodapé mostram a composição atual.
4. Ajuste cada ação selecionada: **Intensidade** (peso da contribuição), **Amplitude** (tamanho), **Ritmo** (0,1x a 3x, padrão 1x). O número acompanha o slider durante a execução. **Restaurar ritmo 1x** afeta somente a ação selecionada.
5. **Pausar** congela a fase daquela ação, mantendo a simulação corporal funcionando; desligue para retomar. **Repetir** repete o ciclo. Sem repetição, a ação termina ao completar o ciclo. **Ativar** desligado retira gradualmente sua contribuição.
6. **Ritmo da base / caminhada** abre velocidade e pausa próprias da evolução da base, sem pausar as ações adicionais. A duração da interpolação entre posturas continua independente.
7. **Transição de postura** define a duração da interpolação da referência entre bases (0,15 a 3 segundos). Não altera a frequência da física.

| Categoria | Opções desta versão | Composição |
| --- | --- | --- |
| Postura base | Em pé, Sentada, Agachada, Inclinação, Caminhada, Personalizada | Uma base por vez; as complementares permanecem ativas quando compatíveis. |
| Movimento cíclico | Flexão cíclica, Balanço lateral | Compatíveis entre si e com bases estáticas. Desativados na caminhada para preservar a cadeia de apoio. |
| Movimento complementar | Elevar braços, Olhar ao redor | Compatíveis com todas as bases. Cada um tem sua própria fase e ritmo. |
| Transição postural | Interpolação entre bases e poses salvas | Duração independente; não é um controlador físico adicional. |

Ao tentar ativar Flexão ou Balanço durante a caminhada, o menu informa a incompatibilidade. Ao entrar na caminhada, essas ações saem progressivamente. Na referência Personalizada, os movimentos adicionais usam os ângulos salvos e preservam os alvos de altura/apoio editados pelo usuário. As contribuições são limitadas pela anatomia do perfil.

## Interação direta

**Corpo:** arraste um segmento com um dedo ou botão esquerdo do mouse para aplicar tração limitada. Solte para liberar. A captura física da versão anterior continua disponível no editor de poses. A força não é um bloqueio infinito: perturbações e poses sem apoio ainda podem derrubar o corpo.

**Vestuário:** toque a peça visível e arraste para cima para acomodar um pequeno relevo/dobra para fora; arraste para baixo para alisar. A região acompanha a deformação da roupa. Soltar conserva o ajuste na sessão. **Preferências → Alisar vestuário** restaura as peças. A seleção testa a malha animada visível: não seleciona tecido através do corpo. O alcance é propositalmente pequeno para preservar a cobertura. Não há remoção de roupa.

**Câmera:** arraste um dedo ou o mouse na área 3D para orbitar; faça pinça com dois dedos para zoom. No PC, a roda também controla o zoom neste modo. Os gestos só começam fora dos controles da interface. A mudança de modalidade encerra o gesto em curso sem recriar o corpo e sem pausar as ações.

O painel **Câmera** continua disponível em qualquer modalidade e oferece horizontal, vertical, zoom, centralização no centro de massa e restauração. Os sliders acompanham os gestos. Para manipular o corpo e mudar o enquadramento no Android, mantenha o primeiro dedo na personagem e use o painel com o segundo.

## Estímulos externos

**Menus → Estímulos externos** permite escolher intensidade, direção e duração. **Perturbar tronco** aplica uma força externa limitada ao tórax durante o intervalo escolhido. Esse controle não é uma ação muscular, não altera o ritmo do compositor e não troca o estado muscular.

## Personalizações independentes

**Menus → Personalizações** mantém os modos de referência Automático, Personalizado e Livre, separados dos estados Animated, Active, Relaxed, Passive e Recovery.

**Editar postura** expõe o editor existente: selecione uma articulação, ajuste os ângulos e a pelve, copie a referência ou capture o corpo físico, dê um nome e salve. Use **Carregar postura salva** dentro do editor. O seletor de posturas logo abaixo do editor permite **Duplicar**, **Renomear** e **Excluir** a entrada selecionada. Duplicar/renomear exige um nome novo. Salvar com o mesmo nome atualiza aquela pose. Restaurar retorna à base Em pé.

Os **perfis musculares** têm outro seletor e outro campo de nome. **Salvar perfil** guarda os seis conjuntos de parâmetros das nove regiões; **Carregar**, **Duplicar**, **Renomear** e **Excluir** operam somente sobre esses perfis. Não apagam posturas. **Restaurar perfil Natural** repõe os ganhos originais. O estado muscular é um controle separado e não é imposto ao carregar um perfil.

Abra **Configurações articulares** para escolher o grupo e editar rigidez, amortecimento, força máxima, torque máximo, escala dos limites e recuperação. Rígido, Natural, Relaxado e Personalizado continuam disponíveis. Os perfis são gravados atomicamente em `user://gameplay_muscles.cfg`; poses continuam em sua biblioteca da 1.3.3.1. Dados inválidos não são usados para substituir parâmetros.

## Interface mínima, visualização e manutenção

**Preferências → Interface mínima** recolhe o painel e oculta o rodapé. **Ocultar controles** deixa apenas **Mostrar controles**, que permite voltar sem teclado. A preferência de interface mínima, modalidade e enquadramento são persistidas em `user://gameplay_ui.cfg`. A câmera é salva ao sair da cena ou trocar a modalidade. As ações e os ajustes de roupa pertencem à sessão, não são restaurados automaticamente ao reabrir o projeto.

**Visualização** reúne esqueleto físico, referência, centro de massa, apoios, colisores, limites, forças, torques e desempenho/estabilidade. Tudo começa desligado, mesmo que tenha sido usado anteriormente. Os limites mostram o grupo articular selecionado. As forças/torques mostram os controladores musculares e a tração corporal; a seta do estímulo externo não é desenhada separadamente.

Para manutenção, abra **Preferências → Mostrar ferramentas de desenvolvimento**. Ali ficam Active Ragdoll, Full Body Rig, Articulações, Equilíbrio e os controles anteriores. Essas cenas e os testes internos foram preservados. No editor também podem ser abertas diretamente. Não são etapas necessárias para acessar as funções novas.

## Arquitetura e adaptação para 1.3.4

| Módulo em `gameplay/` | Responsabilidade |
| --- | --- |
| `action_library.gd` | Categorias, compatibilidade e máscaras de papéis semânticos. |
| `action_composer.gd` | Fases independentes, ativação suave, composição aditiva e contribuição de cada ação. |
| `external_stimulus_controller.gd` | Força externa com intensidade, direção e duração próprias. |
| `customization_manager.gd` | Biblioteca de perfis musculares, distinta da biblioteca de poses. |
| `visualization_manager.gd` | Representações dos colisores; reutiliza os diagnósticos físicos existentes. |
| `camera_overlay.gd` | Enquadramento, órbita e zoom. |
| `interaction_mode_manager.gd` | Arbitragem das modalidades e seleção das peças por `CharacterProfile.mesh_roles`. |
| `gameplay_ui_controller.gd` | Painéis, controles, listas, nomes e persistência das preferências. |
| `gameplay.gd` | Integração com o Active Ragdoll e a referência dinâmica existente. |

A ordem é: base/pose salva → contribuições mascaradas → limites/IK → interpolação da referência → controlador muscular limitado → simulação → malha visível. Flexão e balanço somam componentes diferentes da pelve; as demais máscaras cobrem coluna, cabeça ou braços. Não há dois controladores escrevendo o mesmo osso físico. O `ActiveBody`, as massas, o solver físico e o Dynamic Ground Contact foram preservados. O novo hook `compose_custom_reference` mantém o comportamento antigo nas bancadas.

As roupas são identificadas pelo perfil, não por nomes fixos no módulo novo. As amplitudes de deslocamento usam o comprimento das pernas; os ângulos e limites vêm do perfil. O adaptador legado da Rosé continua isolado. Uma correção de ordem registra o Skin ampliado antes da malha ampliada, evitando o aviso `bs > sbs` do renderer, sem mudar pesos ou física. BUBUROSTO ainda **não foi integrado**: será o segundo modelo de validação da 1.3.4.

## Limitações reais

- Vestuário usa uma deformação visual pequena, contínua e externa, com uma região de ajuste por malha. Não é tecido completo com solver, atrito e dobras permanentes múltiplas. Não desloca livremente uma manga ou gola nem cria novos pontos de contato. O picking usa a malha skinned anterior a esse relevo, portanto a precisão na superfície deformada tem a tolerância desse pequeno deslocamento.
- A biblioteca desta entrega tem quatro movimentos complementares/cíclicos e seis bases; não importa automaticamente clips arbitrários do Blender. Intensidade e amplitude multiplicam a contribuição; não modificam a força muscular máxima.
- As ações alteram alvos, não garantem equilíbrio para todo perfil/preset. Ainda é possível cair em estados fracos ou poses sem sustentação. O limite de penetração do teste legado não equivale a ausência absoluta de interpenetração visual.
- O custo medido no host Linux não representa um celular. Não foi feito teste em dispositivo Android físico nesta entrega. GPU móvel, teclado virtual, toque simultâneo real, desempenho sustentado e área segura do dispositivo precisam do roteiro abaixo.

## Roteiro manual Android

1. Importe a pasta nova no editor Godot 4.7.2 e execute o projeto; confirme entrada direta, roupa visível e ausência de overlays técnicos.
2. Teste retrato e paisagem. Abra/feche Ações e Câmera; confirme botões alcançáveis e scroll. O painel aberto pode cobrir parte da personagem; recolha-o para jogar.
3. Combine Sentada + Flexão + Olhar. Altere somente a flexão para 0,5x e 2x; pause/retome o olhar; desligue repetição e espere o ciclo acabar. Verifique os apoios. Tente Flexão durante Caminhada e confira a mensagem.
4. Crie duas poses com nomes diferentes e dois perfis musculares. Duplique, renomeie, carregue e exclua cópias. Feche e reabra o projeto; confirme os arquivos e as preferências.
5. Alterne Corpo/Vestuário/Câmera com ações ligadas. Faça um ajuste pequeno na roupa, solte e alise. Confirme a cobertura e a continuidade da peça ao sentar. Faça pinça na câmera; arraste sliders sem puxar a personagem.
6. Aplique um estímulo breve e teste a recuperação. Verifique que trocar menus não reinicia as ações. Teste interface mínima, ocultar e restaurar controles.
7. Só para diagnóstico, abra Visualização e observe apoios, erro e custo durante pelo menos cinco minutos. Registre modelo do celular, FPS, temperatura e sintomas. Compare orientação e carga de ações. Não aumente rigidez para mascarar uma instabilidade.

## Executar testes no PC

Importe primeiro com `godot --headless --editor --path . --import --quit`. Execute os scripts de `tests/` com `godot --headless --path . --fixed-fps 60 --script res://tests/NOME.gd`. O teste `gameplay_visual_check.gd` pode ser executado com renderer para capturar retrato/paisagem em `user://`; headless verifica apenas o layout lógico.

Consulte `VALIDACAO_1_3_3_2.md` e os logs em `validation_1_3_3_2/` para resultados efetivamente medidos. Os testes de interação usam eventos sintéticos; não equivalem a tocar uma tela Android real.
