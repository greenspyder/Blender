# Rosé 1.1 · laboratório de precisão

Extraia o pacote. Importe game/project.godot no Godot 4.7.2 e use F5. A cena principal é precision_lab.tscn. A 1.0 continua em dynamic.tscn; o retrato em demo.tscn. No Blender 5.1, abra src/Rose_Rig_1_1.blend. A cena 07 contém o rig novo, as cenas 05/06 os estudos anteriores e a cena 04 o clipe original.

## Exercício 1 · sentir o controle

Escolha Mão direita e aponte para o ombro. Aproxime devagar com W, afaste com S. Com Ajustes aberto, confira o nome da zona e a força. Compare um gesto lento e um rápido sobre o mesmo trajeto. Use Q/E para girar o punho, roda para aproximar a câmera, botão direito para orbitar e setas verticais para enquadrar. O parâmetro Cursor multiplica os deslocamentos de mouse. Velocidade limita o percurso da mão por segundo, Suavização controla a rapidez com que a posição desejada acompanha o ponteiro. Troque um valor por vez.

Selecione Ambas as mãos. Em vista frontal, ajuste Distância e Espelho e repita o movimento sobre os dois ombros. O lado esquerdo e o direito têm estados, juntas e contatos próprios. Pose e abertura são compartilhadas pelo painel. Compare Aberta, Relaxada, Apontando e Segurando. Esta última demonstra a flexão para preensão. O encaixe de objeto disponível continua sendo o do pirulito na boca.

## Exercício 2 · editar dedos e colisões

Em game/precision/hand.gd, setup constrói cinco cadeias de três articulações por mão. CURL contém uma linha para cada pose e cinco valores, do polegar ao mínimo. Para manter só o indicador reto, diminua o segundo valor e aumente os demais. Abertura e interpolação temporal são aplicadas em advance. Ajuste os comprimentos da falange e do ponto final juntos. Os dedos são controles do jogador construídos no Godot.

Em contact.gd, ZONES guarda centros e semieixos em metros locais. Ajuste primeiro ombro e manga de um lado. Repita do outro com X invertido. A cada passo, a palma e cinco pontas percorrem segmentos da posição anterior à desejada. A primeira interseção com um elipsoide expandido limita o movimento. A componente tangencial passa por uma segunda verificação para permitir deslizamento. Para um tecido espesso, aumente os semieixos aos poucos e confira de perfil. A reação combina até duas mãos, com o contato mais cedo por mão. As zonas aproximam a pose de repouso e há margem para erro perto de costuras, falanges e deformações grandes.

## Exercício 3 · editar o rig no Blender

Escolha a cena 07, selecione ResponseRig e entre em Pose Mode. Mova os empties **Alvo • mão L/R** da cena em incrementos de 2 cm. Inspecione a constraint IK em ForeL/ForeR. Chain Length 2 inclui antebraço e braço. Para alterar o plano de dobra, ajuste a posição de repouso do cotovelo em Edit Mode numa cópia. Examine o vínculo Armature e teste os grupos Upper, Fore e Palm em Weight Paint ao dobrar cada braço. Verifique costuras da roupa. Os pesos iniciais são procedurais e precisam de revisão artística para amplitudes maiores.

O controle de olhar do Blender usa Damped Track em Head, com influência inicial zero. Aumente-a gradualmente para experimentar o alvo. Para editar o recuo, selecione Body e a shape key yield_back. Confira valores 0, 0,5 e 1 com a pose do esqueleto. Verifique a mesma expressão nas peças que devem acompanhar o corpo. Exporte somente a cena 07 como GLB com skin e shape keys, constraints de estudo em repouso e sem ações de teste ativas. Grave primeiro uma cópia de assets/rig11.glb.

## Exercício 4 · entender a reação e preparar entradas futuras

pose_solver.gd resolve as duas barras de cada braço com comprimentos constantes, alvo filtrado e plano de dobra derivado da pose de repouso. A cadeia aponta o punho para um alvo alcançável. Coluna e cabeça recebem orientação amortecida com amplitude limitada. response.gd mantém a mola de postura e a combinação das mãos. lab.gd aplica os pesos faciais e de equilíbrio e chama o solver. A cena de interação usa a pose inicial como base; o clipe facial continua disponível no Blender. Misturar continuamente uma animação esquelética externa exige aplicar o solver depois do animador sobre a pose corrente; o solver atual recompõe a pose a partir do repouso por quadro.

Em um script de teste, obtenha o nó raiz da cena. Chame set_look_target(Vector3(0.35,1.90,1)) para dirigir a orientação da cabeça. Use set_reach_target("R", alvo_local) para experimentar um alvo de alcance próximo ao punho. Passe null para liberar. set_hand_target(0, ponto) e set_hand_target(1, ponto) alimentam entradas independentes nos modos de mão correspondentes. O sinal contact_updated envia as duas amostras a um futuro observador. O projeto fornece essas entradas para atenção e alcance. Decisão de curiosidade, locomoção autônoma, preensão física e gestos multitouch exigem implementação adicional.

## Validação no seu editor

1. Abra precision_lab.tscn e use F6. Com a palma aberta, mova de frente e de perfil ao longo de cada ombro. Observe se para, desliza e sai sem saltos.
2. Repita apontando. A ponta estendida deve poder encostar antes da palma. Gire Q/E junto à borda da manga. Anote lado, pose, zona e ângulo quando houver penetração.
3. Alterne os lados e aproxime as duas mãos em velocidades diferentes. Veja se ombros e cotovelos mantêm o lado de dobra. Solte, aguarde dois segundos e confira o repouso.
4. Abra Ajustes, reduza Velocidade e depois aumente Suavização. Observe o atraso entre cursor e mão com zoom alto. Compare a estabilidade a 30 e 60 fps na sua GPU.
5. Volte ao pirulito e teste encaixe e retirada. Use F6 nas cenas anteriores para comparação.

Teste repetível dentro de game: execute godot --headless --editor --import --quit. Depois, execute godot --headless -s res://tests/precision_test.gd e repita com dynamic_test.gd e interaction_test.gd. O teste 1.1 mede varredura, alcance do punho, ativação do olhar, ângulos de pose, duas mãos, repouso e regressões básicas. A avaliação gráfica interativa e o conforto do mouse dependem da execução no editor.

## Arquivos da atualização

precision_lab.tscn, precision/*.gd, assets/rig11.glb, tools/rig_11.py, tests/precision_test.gd e src/Rose_Rig_1_1.blend compõem a 1.1. project.godot inicia o laboratório. interaction.gd localiza as malhas faciais também sob o esqueleto. Os arquivos da demonstração 1.0 estão incluídos. Para reconstruir o rig a partir do .blend anterior, execute a partir da raiz:

    blender -b src/Rose_Contato_1_0.blend -P game/tools/rig_11.py -- .

Essa construção escreve o novo .blend e o GLB; faça-a em uma cópia se já tiver alterado esses dois arquivos manualmente.
