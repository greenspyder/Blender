# ROSE 1.3.3.2.3 · Auditoria de ações e vestuário

Base reproduzível `cd2a9a3b969197d5d6f2755096e3d3f5ed8b7f6b`. O projeto abre em `gameplay/main.tscn`. A comparação parte da mesma importação do projeto, em Godot 4.7.2, com dados de usuário isolados.

| Sistema | Observação na base | Decisão |
|---|---|---|
| Action Library / Composer | Quatro índices de base vetam Agachar antes de consultar qualquer contato. A troca de base desliga camadas. Os relógios das ações já são independentes. | Manter os relógios e a curva de 2 rad/s. Avaliar a sustentação, a orientação corporal e a margem das pernas durante o gesto. |
| Pose Library / Full Body Pose | A biblioteca guarda ângulos e deslocamento por papel. Na personalização, o jogo apaga a contribuição da pelve. O solver de pernas já aceita alvos de sola. | Aplicar a contribuição sobre uma cópia da referência e resolver o apoio na camada de referência. Preservar a pose salva. |
| Active Ragdoll / Ground Balance | O núcleo conhece contatos físicos, centro de massa, banco e limites musculares. O chão é consultado por pé. O modo livre e o estado passivo cedem o peso ao mundo físico. | Usar essas observações para limitar o movimento. Conservar forças, massas, amortecimento e recuperação. |
| XPBD / Worn Layer | O pano independente tem dois pontos de ancoragem e topologia própria. Na roupa, as peças compartilham células espaciais. Todas as partículas recebem a mesma mola de 450 s⁻² e um curso de 0,028 comprimento de perna. As arestas recalculam o repouso a partir da skin em cada passo. | Separar as ligações por peça, distinguir sustentação e folga local e permitir que parte do comprimento de repouso resista à extensão. |
| Fit Region / Dynamic Surface / Surface Picker | O gesto já entra no XPBD e o envio parcial mantém o ArrayMesh. O desenho descarta a deformação em toda borda aberta, inclusive onde a peça poderia pender. | Conservar os pontos de ajuste, a seleção por superfície e o envio parcial. Distinguir costura compartilhada, área de suporte e borda solta. |
| Character Profile / figurinos | O perfil identifica as malhas e seis zonas de ajuste. O jogo usa uma configuração material comum. | Descrever peças e conjuntos com recursos de dados, validar a compatibilidade antes de trocar e expor o estado para a interface. |
