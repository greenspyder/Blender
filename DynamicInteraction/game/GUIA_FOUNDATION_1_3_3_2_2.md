# ROSE 1.3.3.2.2 · Guia para jogar no Android e no PC

## Abrir o projeto

Extraia o ZIP inteiro em uma pasta nova. No gerenciador de projetos do Godot, toque em **Importar**, escolha o `project.godot` dessa pasta e execute ▶. No PC, F6 abre a cena atual e F5 executa o jogo. A primeira importação converte os quatro GLBs. A entrada do jogo é `gameplay/main.tscn`.

A personagem aparece vestida, com os músculos ativos. À esquerda ficam a modalidade e **Menus**. **Câmera** fica no canto superior direito. O nome interno antigo do aplicativo foi preservado para que o Godot encontre as preferências e posturas das versões anteriores no mesmo ambiente.

## Fazer um agachamento

| O que experimentar | Controles | O que observar |
|---|---|---|
| Manter a personagem agachada | **Menus → Ações → Agachada** no primeiro seletor | A pelve desce, os joelhos flexionam e os pés procuram manter o apoio. A base é sustentada depois da transição. |
| Descer e voltar a ficar de pé | Base **Em pé**, segundo seletor **Agachar**, ligue **Ativar** | A 1x, o ciclo de referência leva aproximadamente 3,14 s. Desligue **Repetir** para fazer uma vez. O corpo físico leva algum tempo para acompanhar. |
| Combinar ações | Mantenha **Agachar** ativo, selecione **Olhar ao redor** e ligue **Ativar** | As duas ações aparecem na lista. Mudar a ação selecionada permite editar uma de cada vez. |
| Fazer uma flexão sentada | Base **Sentada**, ação **Flexão cíclica**, ligue **Ativar** | O banco entra na simulação. A flexão acrescenta movimento à pelve e à lombar e pode acompanhar o olhar. |

**Amplitude** escala a excursão e **Intensidade** pesa a contribuição da ação. **Ritmo** vai de 0,1x a 3x. **Pausar** conserva a fase da ação selecionada. **Restaurar ritmo 1x** recupera a cadência original. O controle da caminhada fica em **Ritmo da base / caminhada**. As forças, a gravidade e os contatos continuam a ser calculados enquanto a referência está pausada.

O ciclo **Agachar** está disponível em **Em pé** e **Inclinação**. As bases **Agachada**, **Sentada**, **Caminhada** e **Personalizada** já têm sua própria organização de pernas ou de apoios. O menu informa a incompatibilidade. **Balanço lateral**, **Elevar braços** e **Olhar ao redor** continuam disponíveis conforme a base. Uma transição curta ajuda a ver a diferença entre a referência e o movimento físico.

## Acomodar uma alça, a barra ou o cós

1. Escolha **Vestuário** no seletor superior esquerdo. Abra **Câmera** e aproxime o enquadramento até ver a peça que deseja ajustar. Uma vista frontal ligeiramente girada costuma deixar as alças visíveis.
2. Encoste diretamente na alça visível, na lateral da barra da blusa ou no cós do short. No PC, use o botão esquerdo. O rodapé identifica a região durante o gesto quando a interface completa está visível.
3. Arraste alguns milímetros na tela, de preferência acompanhando a superfície, e solte. O trecho próximo acompanha a tração limitada e acomoda parte do ajuste. O movimento secundário prossegue durante as ações corporais.
4. Para voltar ao ajuste inicial, use **Menus → Preferências → Alisar vestuário**. A acomodação manual dura a sessão. Os materiais têxteis têm salvamento próprio.

Cada lado admite pequenos ajustes independentes. Uma borda na frente da câmera pode ocultar outra peça. Girar ou aproximar a câmera facilita tocar na região visível. Nas outras partes da roupa, o toque continua a produzir uma tração elástica temporária. O perfil desta personagem define as áreas e o curso para preservar a cobertura.

## Usar ou suspender o pano independente

Em **Menus → Personalizações → Tecidos**, alterne **Simular pano independente**. Ao desligar, o pano e o suporte saem da imagem, e o controlador suspende física, seleção e atualização visual do acessório. Ao religar, ele retoma da posição em que parou. A preferência sobrevive à reabertura do jogo.

Na mesma seção ficam os materiais **Leve**, **Natural**, **Elástico**, **Rígido** e **Personalizado**, o salvamento do material e as qualidades **Econômico**, **Equilibrado** e **Detalhado**. A frequência do corpo permanece em 120 Hz com o preset fornecido.

## Câmera, corpo e personalizações

- **Corpo** permite puxar um segmento com um dedo ou com o botão esquerdo. Soltar interrompe a força.
- **Câmera** permite orbitar com um dedo ou com o mouse. Use a pinça ou a roda para zoom. O painel flutuante também oferece os dois eixos de rotação, centralização e restauração em qualquer modalidade.
- **Personalizações** reúne o estado muscular e os modos **Automático**, **Personalizado** e **Livre**. O editor de postura conserva a biblioteca de poses por papéis anatômicos. Os perfis musculares têm outro nome, seletor e salvamento.
- **Preferências → Interface mínima** recolhe o painel e o rodapé. **Ocultar controles** deixa o botão **Mostrar controles** para recuperação.
- **Visualização → Desempenho e estabilidade** mostra custo, apoios e erro. Em **Preferências → Mostrar ferramentas de desenvolvimento**, as bancadas históricas continuam acessíveis para manutenção.

## Roteiro manual no Android

| Etapa | Procedimento | Sinal a conferir |
|---|---|---|
| Importação | Extraia em pasta nova e inicie por ▶ no editor Android | A cena abre no jogo, com os controles recolhidos e as duas pantufas visíveis. |
| Braços e pés | Olhe de frente, de lado e por trás. Alterne entre Em pé, Sentada, Agachada e Caminhada | Palmas acompanham os punhos, cotovelos dobram suavemente e cada pantufa acompanha o próprio pé. |
| Agachamento | Faça um ciclo sem repetição, depois combine com olhar, altere o ritmo e pause somente o olhar | O ciclo termina de pé, o estado da caixa Ativar acompanha o término e os pés mantêm apoio. |
| Toque | Ajuste alça e cós de cada lado, solte e pressione Alisar vestuário | Há resposta local, retorno parcial e cobertura. Verifique se um dedo em um slider não puxa o corpo. |
| Modalidades | Alterne entre Corpo, Vestuário e Câmera com duas ações ligadas. Experimente a pinça e gire a tela | Os menus permanecem alcançáveis. Um gesto concluído deixa de movimentar a peça ou a câmera. |
| Persistência | Duplique uma pose e um perfil muscular, desligue o pano independente e reabra o projeto | As duas bibliotecas e a preferência do acessório voltam. A roupa vestida continua ativa. |
| Desempenho | No mesmo enquadramento e qualidade, compare pelo menos um minuto de caminhada com o pano ligado e desligado | Registre modelo do aparelho, versão do editor, orientação, qualidade, FPS e custo de física/malha. Repita com o aparelho já aquecido. |

O relatório inclui os ensaios de desktop e as imagens originais. O roteiro acima ficou reservado à validação no aparelho. [Relatório e evidências](AUDITORIA_FOUNDATION_1_3_3_2_2.md)
