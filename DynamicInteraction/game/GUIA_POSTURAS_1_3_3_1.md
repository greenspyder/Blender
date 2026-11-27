# ROSE 1.3.3.1 · Referências posturais dinâmicas

> Atualização 1.3.3.2: o jogo agora abre direto na simulação. Veja [a nova interface](GUIA_GAMEPLAY_1_3_3_2.md); os caminhos de bancada abaixo descrevem a interface anterior.

Extraia o ZIP em uma pasta nova e importe `project.godot`. Use **Executar projeto (▶) → Active Ragdoll**. No PC, também dá para abrir `rig/active/lab.tscn` e executar a cena atual. A bancada inicia em **Automático → Em pé**, com a personagem vestida.

## Abaixar a personagem e conservar a pose

1. Escolha **Personalizado**, abra **Editor de posturas** e ative **Capturar ao soltar**.
2. Segure o tronco com um dedo ou com o botão esquerdo do mouse. Arraste para baixo e um pouco à frente, espere a personagem se acomodar e solte. A captura usa a posição física da pelve e os ângulos que o corpo atingiu no instante da soltura.
3. Aguarde a transição e observe o contato dos pés. O esqueleto claro mostra a referência. O corpo continua sujeito a peso, forças limitadas e colisões. Puxe de novo para refazer a pose ou desligue **Capturar ao soltar** para testar a resistência da mesma pose com outro arrasto.
4. Digite um nome e toque em **Salvar postura**. Para carregar depois, abra **Carregar postura salva**. Salvar com o mesmo nome atualiza a pose existente.

Para partir de uma postura pronta, use **Automático**, escolha **Agachar**, **Inclinar o tronco** ou **Sentar** e abra o editor. Quando a referência estiver na posição desejada, toque em **Copiar referência visível**. Essa ação copia o alvo do esqueleto naquele instante. **Capturar postura do corpo** usa o estado físico naquele instante. As duas ações selecionam **Personalizado**.

## Ajustar a pose

| Controle | Efeito |
| --- | --- |
| Articulação | Escolhe pelve, lombar, tórax, cabeça ou uma articulação de membro. X, Y e Z seguem os eixos anatômicos do perfil e apresentam os intervalos permitidos. O joelho mostra apenas o eixo de flexão. |
| Deslocamento da pelve | Edita os alvos lateral, vertical e frontal em relação ao repouso do modelo. Para descer com os pés apoiados, combine a altura com flexão de quadris e joelhos. |
| Banco como apoio | Exibe o colisor do banco. A pelve precisa encontrar o assento fisicamente. A opção integra a postura salva. |
| Transição | Define de 0,15 a 3 segundos para interpolar a referência. O alvo muda imediatamente no editor e progressivamente na simulação. A velocidade é um ajuste da sessão. |
| Restaurar postura automática | Retoma a última opção do seletor automático. **Músculos e diagnóstico → Recuperar em pé** seleciona **Em pé** e ativa o estado **Recovery**. |

No touchscreen, deslize verticalmente pelo painel para alcançar os controles inferiores. No desktop, use a roda sobre o painel. A mesma bancada recebe o arrasto pela área 3D. Ao salvar, o teclado do sistema pode ser usado no campo de nome.

## Modos de referência e estados musculares

| Modo | Referência e sustentação |
| --- | --- |
| Automático | Usa os movimentos da 1.3.3 e o IK dos pés com Dynamic Ground Contact. Caminhada, agachamento, inclinação, assento e queda controlada seguem o comportamento anterior. |
| Personalizado | Aplica a pose editada ao esqueleto de referência. A sustentação usa forças limitadas e cede conforme o alvo do centro de massa sai da região dos apoios físicos. As solas consultam a superfície pelo Ground Contact. Os ângulos editados continuam definindo o alvo de cada junta. |
| Livre | Mantém a última referência para o diagnóstico, aplica 12% do ganho do estado muscular como tônus e reduz a assistência posicional a zero. Articulações e contatos físicos continuam atuando. |

O seletor muscular mantém **Animated**, **Active**, **Relaxed**, **Passive** e **Recovery**. Ele define a resposta dos músculos dentro do modo escolhido. **Passive** continua levando a ação muscular a zero. Os presets musculares ficam em **Músculos e diagnóstico**, com armazenamento próprio.

O painel mostra modo, estado, pose, projeção do centro de massa, número de pés e segmentos em contato e erro RMS entre os centros físicos e seus alvos. As marcas de apoio indicam contatos com superfícies. A projeção no plano do piso é um indicador geométrico e pode sair temporariamente da base durante movimentos dinâmicos.

## Formato e adaptação de humanoides

As poses ficam no diretório de dados da instalação em `user://active_ragdoll_poses.cfg`. A biblioteca tem versão de formato, guarda até 48 poses e aceita nomes de até 32 caracteres. A escrita usa um arquivo temporário no mesmo diretório antes de substituir a versão anterior. Um arquivo inválido é sinalizado no editor.

A pose guarda ângulos relativos ao repouso nos referenciais anatômicos de papéis como `pelvis`, `chest` e `shin_l`, deslocamento da pelve em frações do comprimento de perna e a opção do banco. O `CharacterProfile` resolve os nomes e índices do modelo em execução. Ao aplicar a pose, os limites do perfil atual são usados novamente. O código escreve no esqueleto de referência. O Active Ragdoll conduz a malha usando a mesma cadeia de corpos, gravidade, colisores, amortecimento e limites de força e torque.

A integração com outro humanoide requer o contrato semântico e os eixos de junta calibrados no perfil. Proporções, envelope de colisão e distribuição de massa alteram o equilíbrio de uma pose transferida. A validação visual em outros modelos de produção continua reservada à 1.3.4.

## Validação da versão

Godot oficial 4.7.2 em Linux, headless, Godot Physics a 120 Hz. As cenas usaram o GLB vestido da bancada. Cada linha abaixo resume 150 ticks após estabilizar. O ensaio sentado contou contato da pelve com o banco além dos dois pés.

| Referência personalizada | Altura do centro de massa | Maior erro RMS | Apoio esperado |
| --- | ---: | ---: | ---: |
| Em pé | 0,965 m | 26,9 mm | 150/150 |
| Agachada | 0,765 m | 28,2 mm | 150/150 |
| Inclinada | 0,950–0,951 m | 26,9 mm | 150/150 |
| Sentada | 0,712 m | 44,8 mm | 150/150 |
| Agachada recarregada | 0,765–0,766 m | 27,4 mm | 150/150 |

O ensaio também percorreu uma transição de 1 s, editou a lombar pelo slider, verificou os limites do joelho, gravou e leu poses e restaurou a referência automática. No arrasto com eventos sintéticos de toque, o centro de massa permaneceu mais baixo após soltar o tronco, de 0,962 m para 0,902 m. Com a referência extrema de tronco inclinado e pernas recolhidas, a assistência posicional chegou a zero e o corpo caiu até o centro de massa ficar a 0,133 m do piso. Os 21 testes herdados passaram.

Para repetir no PC, execute na pasta do projeto:

```sh
godot --headless --editor --import
godot --headless --fixed-fps 60 -s tests/dynamic_pose_test.gd
godot --headless --fixed-fps 60 -s tests/active_ragdoll_test.gd
godot --headless --fixed-fps 60 -s tests/active_integration_test.gd
```

Em telefone, confira manualmente a abertura do editor em retrato e paisagem, a captura ao soltar, a abertura do teclado ao salvar e o recarregamento após fechar o jogo. O toque físico, o desempenho e a aparência da roupa ao longo das transições ainda precisam de conferência em dispositivo Android. Poses fora dos limites anatômicos, incluindo determinadas orientações deitadas, podem ceder ou divergir do alvo. A sustentação considerada aqui usa pés e banco, com contatos de outros segmentos participando das colisões e do diagnóstico.
