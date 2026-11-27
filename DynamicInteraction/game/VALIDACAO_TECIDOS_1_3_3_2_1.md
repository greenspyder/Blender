# Validação — ROSE 1.3.3.2.1

Data: 27/11/2026. Base: `f4ef78ff5859acc7845b08230b89e7e0ded7226b`. Branch da entrega: `rose/cloth-physics-refinement-1.3.3.2.1`.

## Execução efetiva

Godot 4.7.2.stable.official.ed1daf0bf, Linux. **92 scripts GDScript auditados, 30 scripts de teste aprovados.** Importação e execução headless realizadas. Renderização Compatibility/Mesa llvmpipe/X11 realizada em retrato e paisagem, incluindo pano sob tração, personagem em pé, sentada e caminhando. O driver virtual emite somente aviso de indisponibilidade de mudança do VSync nas capturas finais.

Todos os 25 testes anteriores foram executados. Em `gameplay_test.gd`, somente as verificações da antiga deformação por uniforme de shader foram adaptadas para verificar o vínculo do solver físico e sua liberação. Os testes anteriores de ragdoll, controles, tecidos legados, skinning, contato e poses continuam. Os cinco testes novos são `cloth_physics_test`, `cloth_contact_test`, `cloth_gameplay_test`, `cloth_cost_test` e `cloth_visual_test`.

Não houve teste em aparelho Android físico. Eventos de toque são sintéticos; nem o modo headless nem a renderização via software verificam desempenho de GPU móvel ou sensação tátil.

## Física e integridade

- Pano: 88 partículas físicas, 315 vértices visuais. Roupa: 79 partículas físicas com interpolação para as superfícies originais. A malha vestida preserva contagem de vértices, índices, UVs, pesos e ossos de skinning, materiais por superfície e posições skinned das bordas.
- Ensaio do pano a 30/60/120 FPS, com subpassos de 1/120 s: extensão de pico amostrada 16,06% / 16,06% / 16,11%; velocidade final antes da tração aproximadamente 0,003 m/s. O teste exige menos de 25% de extensão, posições finitas e ausência de penetração no piso. Os resultados finais entre taxas diferiram em menos de 1 mm.
- Tração com força limitada a 8 N: a deformação propagou-se para mais de dez partículas; o multiplicador do vínculo respeitou o limite de força. Depois da liberação, a velocidade caiu abaixo de 0,06 m/s dentro do intervalo de acomodação testado. Os quatro presets foram simulados.
- Atrito: ensaios idênticos com coeficientes 0,02 e 0,9 produziram deslocamentos de 0,1278 m e 0,0572 m. Também foram executados contatos dinâmicos com esfera, cápsula e caixa, verificando a ausência de penetração residual dos pontos amostrados.
- Integração: Em pé, Sentada, Agachada, Inclinação e Caminhada, com Olhar e Flexão quando compatível. Movimento secundário máximo do proxy vestível: aproximadamente 0,0126 m. Folgas máximas medidas nas juntas corporais: 1,0 / 0,2 / 0,5 / 0,3 / 0,7 mm, respectivamente.
- Foram testados seleção do acessório, alternância de modalidades com ações ativas, liberação de tração, mudança de qualidade sem remontagem, salvamento/reabertura do material e da qualidade, e preservação da massa/frequência do Active Ragdoll.

O limite de extensão é iterativo: o Natural tem alvo de 12%, mas o pico transitório medido atingiu 16,11%. Isso está exposto como limitação, não apresentado como obediência exata a 12%. O ensaio de colisão de partículas não garante ausência de interseção entre todas as faces visuais.

## Custo computacional

A versão 1.3.3.2 foi executada novamente no mesmo host: a cena principal anterior mediu **0,639 ms por passo host**, após aquecimento, durante 720 passos. O teste de comparação novo usa 360 passos por qualidade, com caminhada; os custos abaixo incluem script/engine headless, sem desenho de GPU.

| Configuração nova | Tempo total host/passo | Física do tecido/passo | Reconstrução da malha por atualização |
| --- | ---: | ---: | ---: |
| Tecidos desligados para comparação interna | 0,586 ms | 0 | 0 |
| Econômico | 3,579 ms | 2,081 ms | 5,986 ms |
| Equilibrado | 4,574 ms | 2,661 ms | 6,462 ms |
| Detalhado | 5,651 ms | 3,300 ms | 6,247 ms |

A reconstrução visual ocorre em até 15/24/30 Hz, não a cada passo de 120 Hz. Os números são amostras de um host compartilhado e não um limite máximo. A física real de tecido custa substancialmente mais que o shader antigo; esta entrega **não afirma ganho global de FPS**. A redução obtida durante o desenvolvimento foi em relação à primeira malha física de 229 partículas, que custava cerca de 10–12 ms por passo de tecido.

Os parâmetros do Active Ragdoll, sua massa e sua frequência foram preservados. Android usa Econômico por padrão sem preferência salva. A seleção de qualidade limita iterações e atualização visual do tecido; a resolução física não muda enquanto o tecido está em movimento.

## Evidências e reprodução

Logs e JSON completos em `validation_1_3_3_2_1/`. `baseline_1_3_3_2.log` contém a nova execução da versão anterior. `render_layout.log` e `render_poses.log` registram as execuções visuais. Execute `python3 tools/validate_gameplay.py` para auditar e rodar toda a suíte, com `godot` no PATH.

A validade dos resultados está limitada aos cenários e configurações registrados. Não há autocolisão, resposta de força do tecido no corpo, CCD ou validação completa de roupa solta. A camada vestida continua sendo skinning com física secundária limitada. O roteiro Android e as limitações geométricas estão em `GUIA_TECIDOS_1_3_3_2_1.md`.
