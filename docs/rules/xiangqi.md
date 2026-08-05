# Reglas de Xiangqi / Ajedrez Chino (`xiangqi_game`)

## Resumen de Reglas Implementadas
- **Tablero**: Grilla de 9 columnas por 10 líneas con Palacio y Río central.
- **Piezas Tradicionales**: General (Rey), Consejeros, Elefantes, Caballos, Cañones, Carros (Torres) y Soldados.
- **Reglas del Palacio y Río**: El General y Consejeros no pueden salir del Palacio. Elefantes no cruzan el Río.
- **Regla del General Volador**: Prohibición de línea de visión directa entre los dos Generales en la misma columna.
- **Mecánica del Cañón**: Requiere una pieza intermedia ("pantalla") para efectuar capturas.

## Simplificaciones respecto al Juego Estándar
- Reglas avanzadas de persecución perpetua (*perpetual check/chase*) simplificadas a repetición estándar.

## Comandos y Eventos Públicos

| Tipo | Nombre | Descripción |
|---|---|---|
| Command | `MovePieceCommand` | Mueve o captura una pieza en las intersecciones del tablero. |
| Event | `PieceMovedEvent` | Notifica el desplazamiento o captura de pieza. |
| Event | `GameOverEvent` | Notifica el jaque mate o ahogado al General enemigo. |
