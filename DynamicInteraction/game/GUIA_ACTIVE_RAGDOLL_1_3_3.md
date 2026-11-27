# ROSE 1.3.3 · Active Ragdoll

A versão 1.3.3.1 tem um [editor de referências posturais](GUIA_POSTURAS_1_3_3_1.md).

## Abrir e experimentar

Extraia o ZIP inteiro e importe `project.godot`. No editor, toque em **Executar projeto (▶)**. Na barra inferior do jogo, toque em **Active Ragdoll**. Para voltar, use **Voltar à tela inicial** no painel da bancada. A cena também pode ser executada diretamente em `rig/active/lab.tscn`.

Comece em **Em pé / Active / Natural**. Arraste pelo meio do tórax e sustente o gesto acima da cabeça. O ponto tocado segue uma mola com força limitada no plano paralelo à câmera. Observe os pés perderem apoio e a pelve acompanhar o tronco. Solte e espere a aterrissagem. Um arrasto pelo punho exerce menos força e gira o braço mais facilmente. O controle de câmera modifica a direção do plano de arrasto. O botão **Perturbar o tronco** reproduz sempre o mesmo impulso relativo ao tamanho do corpo.

## Como ler a bancada

| Indicação | Como interpretar |
| --- | --- |
| Esqueleto azul-claro | Postura de referência gerada pela coordenação de pelve, coluna, braços, pernas e pés. |
| Esqueleto verde | Pivôs calculados a partir dos corpos simulados. Durante um impacto, compare as duas silhuetas. |
| Cruz amarela | Centro de massa físico, calculado com posição e massa dos 16 segmentos. |
| Marcas de apoio | Contatos com uma superfície cuja normal aponta suficientemente para cima. Um quadril no banco conta como contato. O contador de pés usa somente as solas. |
| COM dentro/fora da base | Projeção do centro de massa no plano horizontal em relação ao polígono das solas e demais apoios. É um diagnóstico geométrico. Em movimento, a velocidade também importa. |
| Arcos | Amplitude em graus do grupo selecionado no referencial da junta. Nos joelhos aparece o arco da dobradiça. Na pelve aparece o limite da postura-alvo da raiz livre. |
| Força e torque | Setas proporcionais ao teto do motor daquele grupo. A força move o centro do segmento, o torque produz rotação. Vermelho identifica a ação externa da mão. |
| RMS | Raiz da média dos erros quadráticos de posição dos centros dos segmentos em relação à referência. |
| Desvio de junta | Maior distância entre pivô físico e pivô reconstruído na pele. O painel avisa quando passa de 3,5% do comprimento de perna. O tempo mostrado mede geração da referência, controle e apresentação da pele por tick. |

## O que cria sustentação

Num ragdoll passivo, massa, juntas, atrito e gravidade determinam o movimento depois de uma perturbação. Aqui o IK calcula uma postura possível e os motores tentam aproximar os segmentos dela. Um torque no cotovelo produz uma reação oposta no braço. A autoridade dos motores é finita. Uma força externa pode dobrar a cadeia, e um alvo fora do alcance deixa um erro visível no painel.

A parcela elástica cresce com o erro. A parcela de amortecimento reage à velocidade relativa e dissipa oscilações. Para rotação usamos o erro pelo arco curto do quaternion e a inércia efetiva do par pai–filho. Isso evita acelerar um punho fino como se tivesse a inércia do tórax. O controle posicional recebe assistência distribuída enquanto há apoio real. A soma é limitada pela capacidade dos contatos. Ao erguer o tronco, o controlador desconta a fração do peso sustentada pela mão. Em voo a gravidade atua, os motores articulares continuam ativos conforme o estado, e a tração fica sob o dedo.

A assistência de contato é uma aproximação para interação em tempo real. Ela aplica forças externas distribuídas e usa o polígono de apoio para diagnóstico. As forças mostradas são comandos do controlador. A bancada não mede a força real de cada músculo nem reconstrói uma plataforma de força.

| Estado | Experimento |
| --- | --- |
| Animated | Aumenta o ganho do acompanhamento. Puxe o antebraço e observe a resistência dentro do teto de torque. |
| Active | Ganho nominal. Use para caminhar, agachar e inclinar. |
| Relaxed | Reduz a sustentação. Compare com a mesma perturbação em Active. |
| Passive | Os ganhos caem progressivamente até zero. Juntas, gravidade e colisões continuam atuando. |
| Recovery | Reintroduz o controle com uma rampa. **Recuperar em pé** combina essa rampa com a referência de pé. |

## Auditoria da base e organização

| Sistema da 1.3.2 | Integração na 1.3.3 |
| --- | --- |
| Full Body Rig, poses e IK | O mesmo solver trabalha numa cópia de `Skeleton3D` sem malha. Conserva alvos, limites e transições de referência. |
| Ground Contact | A referência reutiliza raycasts, normais, contato da sola e trajetória da 1.3.2. No corpo visível, o contato vem do manifold físico. O apoio unilateral real corrige levemente a referência de pelve. |
| Massa e COM | `CharacterProfile.MASS_SEGMENTS` distribui a massa total. O centro de massa físico usa as posições de mundo dos corpos, inclusive durante a queda. |
| Restrições e colisão | 16 corpos, 16 formas primitivas e 15 juntas. Quadris, coluna e membros superiores usam juntas de seis graus de liberdade com translação bloqueada. Joelhos usam dobradiças. Segmentos ligados diretamente têm exceção de colisão. Os demais podem colidir. |
| Animação e pele | A saída visual recebe só rotação local e translação da raiz. Os comprimentos ósseos ficam em repouso. Players e árvores de animação do modelo ficam inativos nessa bancada. Os corpos recebem forças e torques a cada tick. Apenas a montagem inicial posiciona seus nós. |
| Rig legado e controles | O adaptador anterior continua restrito ao perfil que o habilita. As demais cenas, incluindo toque e vestuário, mantêm seus controles e arquivos de preferência. |
| Implementação | `rig/active/active_body.gd` monta e controla a cadeia. `segment.gd` lê contatos. `muscle_profile.gd` reúne as configurações. `lab.gd` integra referência, interface, tração e gráficos. |

O projeto declara o conjunto de recursos 4.2. A bancada foi executada na Godot **4.7.2**, com o backend padrão deste projeto, Godot Physics. `PhysicalBoneSimulator3D` deriva de `SkeletonModifier3D` e aplica o resultado de `PhysicalBone3D` à pele. Essa arquitetura é uma alternativa para projetos com uma versão mínima posterior. Nesta base, corpos explícitos facilitam o acesso a contatos, tensor de inércia, tração e massa de cada papel. Eles também dispensam um segundo escritor na pele. A execução em um binário 4.2 e a equivalência entre backends continuam sem certificação.

Referências da engine: [modificadores de esqueleto](https://godotengine.org/article/design-of-the-skeleton-modifier-3d/), [simulador de ossos](https://docs.godotengine.org/en/stable/classes/class_physicalbonesimulator3d.html), [PhysicalBone3D](https://docs.godotengine.org/en/stable/classes/class_physicalbone3d.html), [juntas 6DOF em 4.2](https://docs.godotengine.org/en/4.2/classes/class_generic6dofjoint3d.html).

## Ajustar no editor e no touchscreen

No editor Android ou PC, abra a cena e selecione a raiz. **Profile** aponta para o perfil do personagem. **Muscles** aponta para `rig/active/natural.tres`. Duplique o recurso se quiser conservar o original. Cada vetor tem nove entradas, nesta ordem: pelve, coluna, pescoço, ombros, cotovelos, punhos, quadris, joelhos e tornozelos. O pescoço é a junta que orienta a cabeça. Salve o recurso no editor para distribuir o ajuste junto com o projeto.

| Campo | Unidade e efeito |
| --- | --- |
| stiffness | Ganho elástico em s⁻². Aumentá-lo acelera a resposta ao desvio. |
| damping | Razão de amortecimento. Perto de 1, a mola isolada tende a assentar rapidamente. Corpos ligados e colisões alteram a resposta. |
| max_force | Newtons. Limita a força linear por segmento. |
| max_torque | N·m. Limita o comando angular da junta. |
| limit_scale | Multiplica as amplitudes anatômicas do CharacterProfile. O batente limita a rotação mesmo em Passive. A pelve livre usa esse ajuste no alvo de orientação. |
| recovery_speed | Variação máxima do ganho por segundo. Um valor menor faz a transição levar mais tempo. |

Durante a execução, os mesmos seis parâmetros aparecem em sliders sob **Grupo muscular**. Os presets **Rígido**, **Natural** e **Relaxado** partem do recurso do Inspector. Editar um valor seleciona **Personalizado**. Toque **Salvar personalizado** para gravar em `user://active_ragdoll.cfg`. Depois de reabrir, selecione **Personalizado**. Essa cópia pertence à instalação local do aplicativo.

## Colisores, Blender e integração da 1.3.4

Exporte o humanoide com escala aplicada e unidades métricas. Confira o eixo vertical +Y e a frente +Z após importar. Os pivôs de quadril, joelho, tornozelo, ombro e cotovelo devem estar nas articulações da pele. Uma dobra correta no colisor ainda pode deformar mal uma roupa com pesos errados. Compare o esqueleto físico com as barras da pele e com a roupa durante o agachamento.

1. Duplique o CharacterProfile. Informe a cena GLB, o mapa de papéis semânticos, os nomes de malhas e as massas. Para um rig nativo, desative o adaptador legado.
2. Verifique as cadeias diretas de dois segmentos usadas pelo IK anterior. Ossos auxiliares em outras partes podem permanecer. Um rig que interpõe twist bones nas cadeias exigidas pelo IK precisa de adaptação. A versão 1.3.4 deve tratar esse remapeamento.
3. Ajuste `sole_offset` no referencial local do pé e os fatores de largura e comprimento da sola. Pés usam caixas, cabeça e mãos usam esferas, demais segmentos usam cápsulas. O comprimento vem da pose de repouso. Os raios relativos podem ser editados em `radius_factor`.
4. Use `joint_axes_degrees` para orientar o referencial anatômico por papel, por exemplo `shin_l`. O eixo de flexão do joelho no referencial anatômico é X. Inspecione os arcos antes de aumentar limites.
5. A camada padrão dos segmentos tem valor de máscara 8 (camada 4). O piso usa o filtro do CharacterProfile, por padrão valor 1 (camada 1). Mantenha os bits de corpo e piso distintos. Marque **Depurar → Formas de colisão visíveis** para conferir volumes e interseções. Comece em repouso antes de experimentar a queda.

O teste de integração constrói um segundo esqueleto com nomes e índices diferentes, ancestral adicional, 74 kg e proporções ampliadas em 15%. Confere montagem, massa e escala da sola. A aparência e os pesos de um segundo personagem de produção ainda precisam ser validados.

## Diagnosticar instabilidade

- **Joelho dobra para trás ou o pé arrasta.** Verifique eixo, sinal da dobradiça e escala aplicada no GLB. No desenvolvimento, a inversão do sinal fez os pés permanecerem em contato durante quase toda a marcha. O teste atual exige apoios alternados dos dois lados.
- **Tremor em repouso.** Observe o erro RMS junto das setas de torque. Se torque e erro oscilarem em sentidos alternados, reduza o ganho ou ajuste o amortecimento. Se houver movimento em Passive já relaxado, investigue sobreposição de colisores e pivôs antes dos músculos.
- **O pé afunda na queda.** Confira a espessura do piso, a caixa da sola e a frequência física. O perfil Natural foi medido a 120 Hz com 48 iterações no Godot Physics. Os testes encontraram penetração residual no impacto. Os parâmetros do espaço e a frequência são restaurados ao sair.
- **A malha estica ou a roupa atravessa a perna.** Pause após o impacto e compare pivôs físicos, linhas de referência e skinning. A saída visual preserva comprimentos. Um desvio alto entre pivôs indica erro do solver de juntas. Uma dobra ruim com pivôs próximos aponta para pesos ou bind pose.
- **O telefone perde quadros.** Use **Econômico** para reduzir a frequência do desenho diagnóstico de aproximadamente 15 para 5 Hz. A simulação e os 16 corpos continuam iguais. Compare no Profiler o tempo de física com o tempo de renderização antes de ajustar a frequência do solver.

## Ensaios executados

Godot 4.7.2 oficial em Linux, headless. Renderização lógica fixada em 30, 60 e 120 fps, simulação a 120 Hz. A sequência parte do repouso e passa por marcha, agachamento, inclinação, assento, queda, recuperação e troca de estados. A pele usa o mesmo GLB vestido da bancada de corpo inteiro.

| Medida | Resultado |
| --- | --- |
| 1.3.2, apoio procedural em repouso | Reação total de 548,8 N. No teste da engine, 147 de 180 ticks da marcha foram unilaterais. |
| 1.3.3, repouso físico | COM a 0,965 m, erro RMS de 26,9 mm e apoio bilateral em 316 de 320 ticks, incluindo a acomodação inicial. |
| Marcha física, 480 ticks | 193 ticks exclusivamente sobre o pé esquerdo e 196 sobre o direito. Avanço máximo do COM de 0,540 m. |
| Sentar, perder equilíbrio e recuperar | O teste detectou contato da pelve com o assento e projeção fora da base durante a queda. COM a 0,131 m após cair e 0,955 m depois de recuperar. Erro final de 48,1 mm. |
| Geometria e energia | Pico de penetração de um canto da caixa do pé de 17,3 mm e desvio máximo entre pivôs físicos e pele de 14,7 mm. Pico de energia cinética de 123 J. O ensaio verifica dissipação após a queda e limites dos comandos. |
| Interação | Seleção do tórax por raio, arrasto e soltura com eventos sintéticos de toque. 297 de 320 ticks sem contato durante a elevação. O corpo voltou a apoiar-se ao soltar. |
| Configuração | Testados presets, edição, persistência e releitura do personalizado, segundo rig sintético e restauração da frequência ao sair. |
| Regressões | Os 18 testes anteriores passaram, incluindo os de articulação, integridade da malha, controles de plataforma, toque, tecidos e equilíbrio. |

| Renderização lógica | Mediana do controle por tick | Percentil 95 |
| --- | ---: | ---: |
| 30 fps | 0,248 ms | 0,297 ms |
| 60 fps | 0,253 ms | 0,296 ms |
| 120 fps | 0,257 ms | 0,302 ms |

Num ensaio separado de seis segundos simulados de marcha, a bancada 1.3.2 consumiu **28,8 ms de tempo decorrido no host por segundo simulado** a 60 Hz. A 1.3.3 consumiu **69,3 ms** a 120 Hz. Essa segunda medida inclui os passos da engine headless. São medições sem GPU de exibição e sem carga térmica de telefone. Os valores em fps acima especificam a cadência do teste. A taxa sustentada no aparelho, a aparência da roupa em todas as poses e o toque físico ainda exigem conferência no dispositivo.

Para reproduzir, execute no diretório de `project.godot`:

```sh
godot --headless --editor --import
godot --headless --fixed-fps 60 -s tests/balance_test.gd
for fps in 30 60 120; do
  godot --headless --fixed-fps "$fps" -s tests/active_ragdoll_test.gd || exit 1
done
godot --headless --fixed-fps 60 -s tests/active_integration_test.gd
godot --headless --fixed-fps 60 -s tests/active_cost_test.gd
```

## Roteiro manual no Android

1. No editor, importe a pasta extraída, abra a cena da bancada e toque em executar cena. Registre modelo do aparelho, versão da Godot, backend e orientação. Confirme que a roupa acompanha pelve, joelhos e tronco.
2. Em **Natural / Active**, espere cinco segundos. Compare a cruz do COM com os apoios. Gire a câmera para observar a sola de lado. Se houver tremor persistente, anote estado, grupo e valor de amortecimento.
3. Escolha **Caminhar**, depois **Agachar** e **Inclinar o tronco**. Observe cada pé se desprender na marcha, a descida da pelve e a continuidade da roupa. Passe para **Sentar** e veja a pelve encontrar o banco.
4. Volte a **Em pé**. Segure o tórax e arraste para cima, mantendo o dedo. Confira o contador de pés chegar a zero e solte. Repita pelo punho para comparar o limite de força. Teste os controles do painel com um segundo dedo.
5. Use **Perturbar o tronco** em Active e Relaxed. Selecione **Queda controlada**, espere o repouso no piso e toque **Recuperar em pé**. Observe se a articulação cede e se o erro diminui gradualmente. Compare com **Passive** e **Animated**.
6. Escolha **Joelhos**, altere o amortecimento e salve o personalizado. Reinicie a bancada, selecione **Personalizado** e confira o valor. Use **Natural** para voltar ao recurso original.
7. Em paisagem e retrato, repita a marcha por um minuto em **Completo** e **Econômico**. No Profiler registre tempo de física, tempo de quadro e picos. Saia para o laboratório de toque habitual e confira câmera, mãos e controles de PC/Android.

A recuperação foi medida em piso plano, com a perturbação e o assento fornecidos. A física permite outras orientações, inclusive ficar de bruços. Erguer-se de qualquer postura, entre obstáculos ou sobre plataformas móveis ainda requer ensaios próprios. A trajetória de caminhada é procedural e repetível. A integração de clipes de um segundo modelo permanece como trabalho da 1.3.4.
