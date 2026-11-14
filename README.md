# Mik's Scrolling Battle Text — WoW: Forever

**MSBT Forever** es el port de [Mik's Scrolling Battle Text](https://github.com/Placidina/MikScrollingBattleText)
al cliente **WoW: Forever** (`1.60.1`, interfaz `16001`) — el cliente Classic+ de
Blizzard que ejecuta contenido de Vanilla sobre el motor moderno de Midnight (12.x).

MSBT muestra tu daño, curación, críticos, fallos, procs y más como texto animado
que cruza la pantalla — completamente independiente del texto de combate de Blizzard
y totalmente configurable: colores, fuentes, iconos, estilos de animación, áreas de
scroll y alertas personalizadas.

## Instalación

1. Descarga la release (o clona este repo).
2. Copia la carpeta `MikScrollingBattleText/` en:
   ```
   World of Warcraft\_forever_\Interface\AddOns\
   ```
3. Reinicia el cliente o escribe `/reload`.
4. Comandos:
   - `/msbt` — abre la ventana de opciones.
   - `/msbt show` / `/msbt hide` — prueba de áreas de scroll.

## Origen del código

Este fork combina dos líneas de desarrollo:

| Fuente | Aporte |
|---|---|
| [NeeRgY/MSBT](https://github.com/NeeRgY/MSBT) (v1.0.6) | Paquete base multi-cliente, árbol `Forever/` de código, TOC `_Mainline` a `16001`, fallback `UNIT_COMBAT` + `C_DamageMeter`, botón de minimapa, UI de opciones y exportación de perfiles (`/msbt export`). |
| [AndyMarigoldLabs/MikScrollingBattleText-Midnight](https://github.com/AndyMarigoldLabs/MikScrollingBattleText-Midnight) | Patrones de endurecimiento contra *Secret Values* y el modelo de ingesta sin Combat Log. |

### Cambios propios de este fork

**v1.5.0 — motor "Solo Combat Feed"** (rediseño completo del pipeline de daño y
curación tras los motores medidor-only de v1.3/v1.4):

1. **Una sola regla de hierro — solo tus datos**: cada número mostrado proviene de
   una señal que solo puede describir a tu personaje (ver "Cómo funciona" más
   abajo). Si una señal no puede probar que es tuya, no se muestra nada.
2. **Clasificador por hechizo con agrupación de daño sostenido**: el golpe que
   aterriza justo tras su cast se muestra al momento (golpe directo); los golpes
   del mismo hechizo a cadencia melee (Stormstrike, etc.) siguen mostrándose
   individualmente; los golpes espaciados (DoTs, procs lentos) pasan a modo
   sostenido y se agrupan en una línea `Hechizo (golpes) total`, mostrada tras
   3.5 s de silencio o al terminar el combate. Un recast cierra antes el grupo
   abierto para no perder su total.
3. **Daño de arma independiente**: los golpes no atribuibles a un hechizo
   (swings, procs) se muestran como el número melee clásico, sin nombre.
4. **Overheal en vivo**: un registro de vida con doble buffer estima cuánto de
   cada autocuración excedió tu vida máxima y lo muestra con el tráiler de
   overheal de MSBT.
5. **Autocuraciones en solitario** atribuidas al cast recién terminado; el cast
   se marca como cura para que jamás attribuya daño después (el bug de los DoTs
   etiquetados como sanación de v1.4.2).
6. **Hechizados canalizados** cuentan siempre como daño sostenido (sus ticks se
   agrupan en vez de pop one por uno).

**v1.1.0-v1.4.2 (histórico)**: misses en Forever, flags compuestos por
substring, color por escuela de daño, values secretos visibles en pantalla,
triggers con `C_UnitAuras`, curas solitarias y diagnóstico persistente.

## Cómo funciona en WoW: Forever

El cliente Forever ejecuta contenido Classic, pero su motor es el de Midnight 12.x:

- **`WOW_PROJECT_ID` reporta `MAINLINE`** (no Classic). Por eso el TOC se llama
  `MikScrollingBattleText_Mainline.toc` (además de un `MikScrollingBattleText.toc`
  base) — un archivo `_Forever.toc` **no cargaría nunca**, y en silencio.
- **`COMBAT_LOG_EVENT_UNFILTERED` está bloqueado** para addons. Todo el combate
  pasa por el **Solo Combat Feed**, cuyas únicas fuentes son señales que no
  pueden describir a nadie más que a ti:
  - `UNIT_SPELLCAST_*` sobre `"player"` — tus propios casts (atribución de
    golpes y de curas).
  - `UNIT_COMBAT` sobre `"player"` — daño, fallos y curas que te **llegan** (el
    receptor eres tú, en solitario y en grupo).
  - `UNIT_COMBAT` sobre `"target"` — **solo en solitario**: fuera de grupo,
    toda herida del target es tuya (o de tu mascota).
  - `C_DamageMeter` — **solo en grupo**, totales por hechizo keyados por tu
    GUID: la única fuente de daño/curación infringida atribuible a ti en
    grupo. Las entradas que no se pueden desenvolver (Secret Values en pleno
    combate) se saltan: en grupo se muestra tu daño o nada, nunca el de otro.
  - `UNIT_HEALTH` + `PLAYER_REGEN_*`, `CHAT_MSG_MONSTER_EMOTE`, etc. para el
    overheal y las notificaciones fuera del combate.
- **Secret Values (`issecretvalue`)**: en combate, muchos números (daño, curación,
  vida, poder) llegan como valores opacos que lanzan error si se comparan, suman o
  les aplican `string.gsub`. Todo el pipeline de MSBT está protegido: los valores
  secretos se muestran directamente, sin acortar, colorear, fusionar ni filtrar por
  umbral; el valor se empalma en el mensaje en el último paso antes de `SetText`.
- **Hechizos multi-rango de Classic**: cada rango de cada hechizo tiene su propio
  `spellID`; la correlación de casts guarda el ID real del último cast.

### Limitaciones conocidas (por diseño de la API de Forever)

- **En grupo, sin detalle por golpe**: el daño/curación infringidos provienen
  exclusivamente del medidor `C_DamageMeter` (deltas de totales por hechizo
  cada 0.5 s; sin críticos ni escuelas, con conteo de golpes estimado), porque
  `UNIT_COMBAT` sobre el target no permite saber quién golpeó. Si el medidor no
  entrega en pleno combate (Secret Values), en grupo se muestra **nada** antes
  que un dato mal atribuido.
- **En solitario, todo con detalle por golpe** (`UNIT_COMBAT`): críticos,
  escuelas de daño y overheal en vivo; el medidor ni siquiera se consulta.
- Las curaciones de otros jugadores sobre ti no se muestran (no se pueden
  atribuir a un caster, y mostrarlas duplicaría tu propia línea de cura en
  grupo).
- Los triggers que dependían de subeventos del combat log (p. ej. detectar el
  hechizo exacto de un proc) no disponen de ese feed; el resto de triggers
  funciona.
- **Diagnóstico**: `/run MikSBT.DebugMeterInfo()` guarda en las SavedVariables
  qué devuelve `C_DamageMeter` (también muestras automáticas en pleno combate,
  marcadas por lucha) — escribe `/reload` después y lee
  `WTF\Account\<cuenta>\SavedVariables\MikScrollingBattleText.lua`.

## Restaurar el texto de combate de Blizzard

Si desinstalas MSBT, reactiva el combat text nativo con:

```
/run SetCVar("floatingCombatTextCombatDamage_v2","1")
/run SetCVar("floatingCombatTextCombatHealing_v2","1")
```

## Desarrollo

- `docs/ARCHITECTURE_FOREVER.md` — arquitectura técnica detallada del port.
- `docs/SKILL_CREATION_PROCESS.md` — proceso de creación del skill
  `wow-forever-addon-adapter` usado para este desarrollo.
- `tools/check_syntax.py` — validación de sintaxis Lua de todo el paquete.
- Bucle de desarrollo: junction hacia `_forever_\Interface\AddOns` (ver
  `scripts` del skill), `/console scriptErrors 1`, `/reload`.

## Créditos

- **Mikord** — autor original de MSBT.
- **Resike, Placidina, Dshonored** — mantenimiento histórico en distintas eras.
- **NeeRgY** — paquete multi-cliente y el port Forever v1.0.6.
- **AndyMarigoldLabs** — ingeniería del engine core para Midnight 12.x.
