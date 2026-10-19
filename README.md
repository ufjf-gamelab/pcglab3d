# PCG LAB 3D

Ferramenta de geração procedural de dungeons 3D em Godot 4. O projeto possui dois modos:
**Edição** (geração e análise da dungeon) e **Jogável** (percorrer a dungeon
gerada com um personagem).

## Requisitos

- Godot Engine 4.6 ou superior

## Controles

### Modo Edição

#### Câmera e Construção

| Tecla | Comando |
| --- | --- |
| <kbd>W</kbd> <kbd>A</kbd> <kbd>S</kbd> <kbd>D</kbd> | Mover câmera |
| <kbd>F</kbd> | Centralizar câmera |
| <kbd>Botão do meio do mouse</kbd> | Segurar para rotacionar a câmera |
| <kbd>Scroll do mouse</kbd> | Zoom in / out |
| <kbd>Botão esquerdo do mouse</kbd> | Posicionar estrutura |
| <kbd>Delete</kbd> | Remover estrutura |
| <kbd>Botão direito do mouse</kbd> | Rotacionar estrutura selecionada |
| <kbd>Q</kbd> / <kbd>E</kbd> | Alternar entre estruturas (anterior / próxima) |
| <kbd>F1</kbd> | Salvar mapa |
| <kbd>F2</kbd> | Carregar mapa salvo |
| <kbd>F3</kbd> | Carregar mapa de exemplo (recurso interno) |

#### Geração da Dungeon

| Tecla | Comando |
| --- | --- |
| <kbd>G</kbd> | Gerar dungeon (salas geométricas: retângulo / cruz / T) |
| <kbd>H</kbd> | Gerar dungeon (autômato celular) |
| <kbd>I</kbd> | Rodar experimento quantitativo (diversas seeds e configurações) |

#### Mapas de Influência (Heatmaps)

| Tecla | Comando |
| --- | --- |
| <kbd>1</kbd> | Exibir/ocultar heatmap de inimigos |
| <kbd>2</kbd> | Exibir/ocultar heatmap de moedas |
| <kbd>3</kbd> | Exibir/ocultar heatmap de estandartes |
| <kbd>4</kbd> | Exibir/ocultar heatmap combinado (moedas − inimigos) |
| <kbd>5</kbd> | Exibir/ocultar heatmap de recarga (portais + estandartes) |
| <kbd>R</kbd> | Recalcular heatmaps (sem regenerar a dungeon, útil para alguma alteração após a geração procedural) |

#### Caminhos (Pathfinding)

| Tecla | Comando |
| --- | --- |
| <kbd>P</kbd> | Calcular e exibir o caminho (tipo predefinido) de todas as salas (gráfico + setas 3D) |
| <kbd>O</kbd> + cursor sobre uma sala | Calcular e exibir o caminho apenas da sala selecionada |

---

### Modo Jogável

| Tecla | Comando |
| --- | --- |
| <kbd>W</kbd> <kbd>A</kbd> <kbd>S</kbd> <kbd>D</kbd> | Mover personagem |
| <kbd>Botão esquerdo do mouse</kbd> | Atacar |

---

### Alternar de modo

| Tecla | Comando |
| --- | --- |
| <kbd>Tab</kbd> | Alternar entre Modo Edição e Modo Jogável |
