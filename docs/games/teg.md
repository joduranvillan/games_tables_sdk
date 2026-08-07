# Crisis (TEG) — Documentación del Juego

## 1. Descripción de TEG y Diferencias con Risk Estándar
TEG (Plan Táctico y Estratégico de Guerra) es el juego clásico de estrategia militar rioplatense. A diferencia del Risk estándar estadounidense:
- **Combate**: El atacante tira hasta 3 dados y el defensor hasta 3 dados (en lugar de 2 del defensor en Risk). El defensor gana en caso de empate dado a dado.
- **Canje de Tarjetas**: Escalado fijo de ejércitos adicionales al canjear tríos de tarjetas de país.
- **Objetivos Secretos**: Además de la conquista global (30 territorios), cada jugador recibe una tarjeta de objetivo secreto que le otorga una condición de victoria particular (conquistar continentes específicos o eliminar a un rival).

## 2. Mapa de 30 Territorios y Continentes

### Soporte Multilingüe (i18n)
El juego expone `crisis_game::territory_name(id: TerritoryId, lang: &str) -> &'static str` con traducciones en español ("es"), inglés ("en"), francés ("fr"), alemán ("de") y portugués ("pt").

### América del Sur (5 territorios, Bono: +2 ejércitos)
- `0`: Argentina (es: Argentina, fr: Argentine, de: Argentinien)
- `1`: Brasil (es: Brasil, en: Brazil, fr: Brésil, de: Brasilien)
- `2`: Chile (es: Chile, fr: Chili)
- `3`: Colombia (es: Colombia, fr: Colombie, de: Kolumbien)
- `4`: Perú (es: Perú, en: Peru, fr: Pérou)

### América del Norte (4 territorios, Bono: +3 ejércitos)
- `5`: México (es: México, en: Mexico, fr: Mexique)
- `6`: California (es: California, fr: Californie, de: Kalifornien)
- `7`: Nueva York (es: Nueva York, en: New York, pt: Nova Iorque)
- `8`: Canadá (es: Canadá, en: Canada, de: Kanada)

### Europa (5 territorios, Bono: +5 ejércitos)
- `9`: Gran Bretaña (es: Gran Bretaña, en: Great Britain, fr: Grande-Bretagne)
- `10`: España (es: España, en: Spain, fr: Espagne, de: Spanien)
- `11`: Francia (es: Francia, en: France, de: Frankreich)
- `12`: Alemania (es: Alemania, en: Germany, fr: Allemagne, de: Deutschland)
- `13`: Rusia (es: Rusia, en: Russia, fr: Russie, de: Russland)

### África (4 territorios, Bono: +3 ejércitos)
- `14`: Sahara (es: Sahara, pt: Saara)
- `15`: Egipto (es: Egipto, en: Egypt, fr: Égypte, de: Ägypten)
- `16`: Congo (es: Congo, de: Kongo)
- `17`: Sudáfrica (es: Sudáfrica, en: South Africa, fr: Afrique du Sud, de: Südafrika)

### Asia (8 territorios, Bono: +7 ejércitos)
- `18`: Aral
- `19`: Tartaria (es: Tartaria, en: Tartary, fr: Tartarie)
- `20`: Taymir (es: Taymir, en: Taymyr, de: Taimyr)
- `21`: Siberia (es: Siberia, fr: Sibérie, de: Sibirien)
- `22`: Kamchatka (es: Kamchatka, fr: Kamtchatka)
- `23`: China (es: China, fr: Chine)
- `24`: India (es: India, fr: Inde, de: Indien, pt: Índia)
- `25`: Japón (es: Japón, en: Japan, fr: Japon)

### Oceanía (4 territorios, Bono: +2 ejércitos)
- `26`: Australia (es: Australia, fr: Australie, de: Australien)
- `27`: Java
- `28`: Sumatra
- `29`: Borneo (es: Borneo, fr: Bornéo, pt: Bornéu)

## 3. Tabla de Adyacencias
| Territorio Origen | Territorios Adyacentes |
|---|---|
| **Argentina** (0) | Brasil (1), Chile (2), Perú (4) |
| **Brasil** (1) | Argentina (0), Chile (2), Colombia (3), Perú (4), Sahara (14) |
| **Chile** (2) | Argentina (0), Brasil (1), Perú (4), Australia (26) |
| **Colombia** (3) | Brasil (1), Perú (4), México (5) |
| **Perú** (4) | Argentina (0), Brasil (1), Chile (2), Colombia (3) |
| **México** (5) | Colombia (3), California (6) |
| **California** (6) | México (5), Nueva York (7), Canadá (8) |
| **Nueva York** (7) | California (6), Canadá (8), España (10) |
| **Canadá** (8) | California (6), Nueva York (7), Kamchatka (22) |
| **Gran Bretaña** (9) | España (10), Francia (11), Alemania (12) |
| **España** (10) | Nueva York (7), Gran Bretaña (9), Francia (11), Sahara (14) |
| **Francia** (11) | Gran Bretaña (9), España (10), Alemania (12) |
| **Alemania** (12) | Gran Bretaña (9), Francia (11), Rusia (13) |
| **Rusia** (13) | Alemania (12), Aral (18), Tartaria (19) |
| **Sahara** (14) | Brasil (1), España (10), Egipto (15), Congo (16) |
| **Egipto** (15) | Sahara (14), Congo (16), Sudáfrica (17), Aral (18) |
| **Congo** (16) | Sahara (14), Egipto (15), Sudáfrica (17) |
| **Sudáfrica** (17) | Egipto (15), Congo (16) |
| **Aral** (18) | Rusia (13), Egipto (15), Tartaria (19), India (24) |
| **Tartaria** (19) | Rusia (13), Aral (18), Taymir (20), Siberia (21), China (23) |
| **Taymir** (20) | Tartaria (19), Siberia (21) |
| **Siberia** (21) | Tartaria (19), Taymir (20), Kamchatka (22), China (23) |
| **Kamchatka** (22) | Canadá (8), Siberia (21), Japón (25) |
| **China** (23) | Tartaria (19), Siberia (21), India (24), Japón (25), Sumatra (28) |
| **India** (24) | Aral (18), China (23), Sumatra (28) |
| **Japón** (25) | Kamchatka (22), China (23) |
| **Australia** (26) | Chile (2), Java (27) |
| **Java** (27) | Australia (26), Borneo (29) |
| **Sumatra** (28) | China (23), India (24), Borneo (29) |
| **Borneo** (29) | Java (27), Sumatra (28) |

## 4. Fases de Turno y Comandos Disponibles

1. **PlaceArmies**: Colocación de ejércitos al inicio del turno.
   - Comando: `PlaceArmiesCommand`
2. **Attack**: Declaración y ejecución de ataques a territorios enemigos adyacentes.
   - Comandos: `DeclareAttackCommand`, `RollAttackCommand`, `ExchangeCardsCommand`
3. **Fortify**: Reubicación de ejércitos entre territorios propios conectados.
   - Comando: `FortifyCommand`
4. **EndPhase**: Transición entre fases o fin de turno.
   - Comando: `EndPhaseCommand`

## 5. Tipos de Objetivos Secretos
- `ConquerContinent(ContinentId)`: Dominar un continente completo.
- `ConquerTwoSmallContinents`: Dominar 2 continentes pequeños (≤5 territorios cada uno).
- `Exterminate(PlayerId)`: Destruir completamente al jugador indicado.
- `ConquerTerritories(u8)`: Controlar una cantidad determinada de territorios ocupados con al menos 2 ejércitos.

## 6. Sistema de Tarjetas y Canje
- Al conquistar al menos un territorio en el turno, el jugador roba una tarjeta de territorio.
- Trío válido: 3 tarjetas del mismo símbolo (`Infantry`, `Cavalry`, `Cannon`) o 3 símbolos distintos o combinación con `Wild`.
- Premio de canje: 4, 7, 10, 15... ejércitos adicionales acumulativos.

## 7. API de Comandos y Eventos (`crisis_game`)

### Ejemplos JSON de Comandos

`PlaceArmiesCommand`:
```json
{
  "type": "PlaceArmiesCommand",
  "player": 1,
  "territory": 0,
  "count": 3
}
```

`DeclareAttackCommand`:
```json
{
  "type": "DeclareAttackCommand",
  "player": 1,
  "from": 0,
  "to": 1,
  "dice": 3
}
```

`FortifyCommand`:
```json
{
  "type": "FortifyCommand",
  "player": 1,
  "from": 0,
  "to": 2,
  "armies": 2
}
```

### Eventos Principales
- `ArmiesPlacedEvent`: `{ "player": 1, "territory": 0, "count": 3, "armies_remaining": 0 }`
- `AttackResolvedEvent`: `{ "attacker": 1, "defender": 2, "from": 0, "to": 1, "attacker_rolls": [6, 4, 2], "defender_rolls": [5, 3], "attacker_losses": 0, "defender_losses": 2, "territory_conquered": true }`
- `TegGameOverEvent`: `{ "winner": 1, "objective": "Conquistar América del Sur" }`

## 8. Simplificaciones Aplicadas Respecto a TEG Real
- Sin pactos o alianzas diplomáticas explícitas en el motor.
- Sin guerras nucleares ni misiles (reglas de exp. TEG 2).
- Tablero optimizado a 30 territorios principales para partidas más dinámicas en partidas rápidas móviles.

## 9. Ejemplo de Partida Mínima
1. **Inicio**: Sesión iniciada para Jugador 1 y Jugador 2. 30 territorios repartidos.
2. **Movimiento 1**: Jugador 1 coloca 3 ejércitos en Argentina (`PlaceArmiesCommand`).
3. **Movimiento 2**: Jugador 1 declara ataque desde Argentina a Brasil (`DeclareAttackCommand`).
4. **Movimiento 3**: Lanzamiento de dados (`RollAttackCommand`), conquista Brasil y fortifica.
5. **Fin**: Jugador 1 cumple su objetivo secreto y se emite `TegGameOverEvent`.
