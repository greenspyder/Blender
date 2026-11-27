# ROSE 1.2.11 · Deformação local por contato

PC e Android usam o mesmo projeto. Importe `project.godot` e execute.

- **Android** · Em **Tocar**, encoste na região para aplicar pressão leve. Em **Agarrar**, encoste, arraste alguns centímetros e solte para ver o retorno. Gire em **Câmera** para testar o contato por trás. Use **Duas independentes** para testar os dois lados ao mesmo tempo.
- **PC** · Clique na região, mova o mouse e clique outra vez para soltar. Use o botão direito para orbitar e **W/S** para ajustar a profundidade. No plano da tela, os arrastes lateral e vertical também ativam a deformação local.

As etiquetas **Peito D/E** e **Glúteo D/E** identificam a região ativada. Camisola e short acompanham a pressão enquanto vestidos.

## O que faltava da passagem Blender → Godot

O GLB já tinha `chest_press` e `hip_press` exportadas nas malhas. Nos estudos Blender **05 · Esfera e short** e **06 · Almofada e camisola**, os drivers liam a profundidade do objeto de contato e o retorno. Essa lógica dos drivers não estava no GLB. A rotina na Godot também não atribuía valores às duas blend shapes. O contato podia mover o tronco e os braços sem produzir a deformação localizada.

`mechanics/soft_tissue.gd` recupera as formas exportadas do lado em que os estudos foram feitos. Cria a forma complementar do outro lado e dois canais de arraste, lateral e vertical, limitados à mesma área. A posição no triângulo identifica a região. A profundidade e o arraste geram o valor de contato, e uma mola amortecida retorna a forma após soltar. Os valores são aplicados ao corpo e às peças correspondentes antes de reposicionar a mão na superfície deformada. Os arquivos Blender e o GLB continuam intactos.

## Como conferir e ajustar

No Blender, abra uma cópia do estudo de contato e percorra os quadros **1** (repouso), **46** (pressão) e **84** (retorno). Na Godot, abra `mechanics/soft_tissue.gd`. `AREAS` e `RADII` descrevem a localização e extensão das zonas. `SHEAR` limita a intensidade dos dois canais complementares de arraste. `step` controla rigidez e amortecimento. Em `direct/direct_lab.gd`, `attach_touch` classifica o triângulo, e `_physics_process` atualiza os pesos antes de projetar a mão.

A verificação automatizada leu vértices deformados, além de comparar os valores das blend shapes. Nas puxadas do teste, o deslocamento localizado chegou a aproximadamente **24 mm** no ponto dianteiro e **35 mm** no traseiro. O teste também confirmou independência entre os lados, resposta da roupa e retorno depois de tocar ou agarrar. São medidas de um roteiro sintético no Godot headless. O modelo usa blend shapes com resposta contínua. A fluidez visual e a sensação do toque em um Android físico ainda precisam ser conferidas no aparelho.
