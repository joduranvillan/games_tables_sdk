# Checklist y Auditoría de Integración de `ThemeManager` en los 13 Tableros

Este documento audita y certifica la integración completa de `ThemeManager` y el sistema de temas visuales/escalado responsivo en los 13 juegos de tablero de la suite OpenTable SDK en Godot 4.

---

## 1. Criterios de Auditoría

Cada uno de los 13 tableros se evaluó contra los siguientes 5 pilares fundamentales:

1. **Gestión de Tema (`current_theme`)**: El tablero obtiene el tema inicial (`get_theme()`) y utiliza sus propiedades de color (`board_color`, `light_color`, `dark_color`, `line_color`, `select_color`, `valid_move_color`) para colorear casillas, fondos, líneas, tableros y resaltados.
2. **Suscripción a Cambios de Tema (`theme_changed`)**: El tablero se suscribe a `ThemeManager.theme_changed` en `_ready()`.
3. **Manejo Dinámico del Cambio (`_on_theme_changed`)**: Implementa el método callback `_on_theme_changed(theme: BoardTheme)`, actualizando `current_theme`, refrescando nodos o estilos visuales y solicitando redibujado (`queue_redraw()`).
4. **Suscripción a Cambio de Layout (`layout_changed`)**: El tablero escucha `GameManager.layout_changed` para reaccionar a cambios de dispositivo (Móvil / Tablet / Escritorio).
5. **Escalado Tipográfico Responsivo (`apply_font_scale_to_board`)**: Aplica `ThemeManager.apply_font_scale_to_board(self)` tanto al cambiar el layout como al cambiar de tema, garantizando legibilidad en todas las resoluciones y dispositivos.

---

## 2. Matriz de Auditoría y Verificación (13/13 Tableros)

| # | Juego / Script | `current_theme` (Colores/Fondo) | Escucha `theme_changed` | Callback `_on_theme_changed` | Escucha `layout_changed` | Aplica `apply_font_scale_to_board` | Estado |
|---|----------------|:-------------------------------:|:-----------------------:|:----------------------------:|:------------------------:|:----------------------------------:|:------:|
| 1 | **Ajedrez** (`chess_board.gd`) | ✅ `light_color`, `dark_color`, `select_color` | ✅ Conectado | ✅ Presente y activo | ✅ Conectado | ✅ Sí (`_on_layout_changed`) | **100% Completo** |
| 2 | **Damas** (`checkers_board.gd`) | ✅ `light_color`, `dark_color`, `select_color` | ✅ Conectado | ✅ Presente y activo | ✅ Conectado | ✅ Sí (`_on_layout_changed`) | **100% Completo** |
| 3 | **Backgammon** (`backgammon_board.gd`) | ✅ `board_color`, `light_color`, `dark_color`, `select_color` | ✅ Conectado | ✅ Presente y activo | ✅ Conectado | ✅ Sí (`_on_layout_changed`) | **100% Completo** *(Ajustado en auditoría)* |
| 4 | **Go (9×9)** (`go_board.gd`) | ✅ `board_color`, `line_color`, `select_color` | ✅ Conectado | ✅ Presente y activo | ✅ Conectado | ✅ Sí (`_on_layout_changed`) | **100% Completo** *(Ajustado en auditoría)* |
| 5 | **Shogi** (`shogi_board.gd`) | ✅ `board_color`, `line_color`, `select_color` | ✅ Conectado | ✅ Presente y activo | ✅ Conectado | ✅ Sí (`_on_layout_changed`) | **100% Completo** *(Ajustado en auditoría)* |
| 6 | **Damas Chinas** (`chinese_checkers_board.gd`) | ✅ `board_color`, `line_color`, `select_color` | ✅ Conectado | ✅ Presente y activo | ✅ Conectado | ✅ Sí (`_on_layout_changed`) | **100% Completo** |
| 7 | **Ludo / Parchís** (`ludo_board.gd`) | ✅ `board_color`, `line_color`, `select_color` | ✅ Conectado | ✅ Presente y activo | ✅ Conectado | ✅ Sí (`_on_layout_changed`) | **100% Completo** *(Ajustado en auditoría)* |
| 8 | **Batalla Naval** (`battleship_board.gd`) | ✅ `board_color`, `dark_color`, `select_color` | ✅ Conectado | ✅ Presente y activo | ✅ Conectado | ✅ Sí (`_on_layout_changed`) | **100% Completo** *(Ajustado en auditoría)* |
| 9 | **Crisis / TEG** (`crisis_board.gd`) | ✅ `board_color`, `line_color`, `dark_color`, `select_color` | ✅ Conectado | ✅ Presente y activo | ✅ Conectado | ✅ Sí (`_on_layout_changed`) | **100% Completo** |
| 10 | **1000 Millas (Mille Bornes)** (`mille_bornes_board.gd`) | ✅ `board_color`, `dark_color`, `line_color`, `select_color` | ✅ Conectado | ✅ Presente y activo | ✅ Conectado | ✅ Sí (`_on_layout_changed`) | **100% Completo** |
| 11 | **Monopoly** (`monopoly_board.gd`) | ✅ `board_color`, `dark_color`, `line_color`, `select_color` | ✅ Conectado | ✅ Presente y activo | ✅ Conectado | ✅ Sí (`_on_layout_changed`) | **100% Completo** |
| 12 | **Uno** (`uno_board.gd`) | ✅ `board_color`, `dark_color`, `line_color`, `select_color` | ✅ Conectado | ✅ Presente y activo | ✅ Conectado | ✅ Sí (`_on_layout_changed`) | **100% Completo** |
| 13 | **Xiangqi (Ajedrez Chino)** (`xiangqi_board.gd`) | ✅ `board_color`, `line_color`, `select_color`, `valid_move_color` | ✅ Conectado | ✅ Presente y activo | ✅ Conectado | ✅ Sí (`_on_layout_changed`) | **100% Completo** |

---

## 3. Ajustes Menores Realizados Durante la Auditoría

Durante la corrida de verificación automatizada se identificaron y subsanaron los siguientes detalles menores en 5 tableros:

1. **`backgammon_board.gd`**:
   - Conexión a `GameManager.layout_changed` e implementación de `_on_layout_changed()`.
   - Adición de llamada a `ThemeManager.apply_font_scale_to_board(self)`.
   - Actualización de `_draw()` para pintar el marco de madera exterior, fondo interior y triángulos (puntas A y B) derivando de `current_theme.board_color`, `current_theme.light_color` y `current_theme.dark_color`.

2. **`battleship_board.gd`**:
   - Conexión a `ThemeManager.theme_changed` e implementación de `_on_theme_changed()`.
   - Conexión a `GameManager.layout_changed` e implementación de `_on_layout_changed()`.
   - Invocación de `apply_font_scale_to_board(self)` para escalar dinámicamente etiquetas de estado y botones del radar.

3. **`go_board.gd`**:
   - Conexión a `GameManager.layout_changed` e implementación de `_on_layout_changed()`.
   - Invocación de `apply_font_scale_to_board(self)` al cambiar el tema y al cambiar el layout.

4. **`ludo_board.gd`**:
   - Conexión a `GameManager.layout_changed` e implementación de `_on_layout_changed()`.
   - Invocación de `apply_font_scale_to_board(self)` para tipografía adaptable.
   - Vinculación de colores de fondo del marco y bordes de casillas con `current_theme.board_color` y `current_theme.line_color`.

5. **`shogi_board.gd`**:
   - Conexión a `GameManager.layout_changed` e implementación de `_on_layout_changed()`.
   - Actualización de `_on_theme_changed()` para refrescar tanto `cell.color` (`board_color`) como `border.border_color` (`line_color`).
   - Invocación de `apply_font_scale_to_board(self)`.

---

## 4. Conclusión

- **Total de Tableros Auditados**: 13
- **Total de Tableros Cumpliendo 100%**: 13
- **Tableros Pendientes**: 0
