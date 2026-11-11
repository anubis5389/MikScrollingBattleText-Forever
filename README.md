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

### Cambios propios de este fork (v1.1.0)

1. **Manejo de misses en Forever** — el fallback `UNIT_COMBAT` ahora genera eventos
   de tipo `miss` (`MISS`, `DODGE`, `PARRY`, `BLOCK`, `RESIST`, `ABSORB`, `IMMUNE`,
   `REFLECT`) tanto entrantes (en el jugador) como salientes (en el target). Antes
   los fallos nunca se mostraban en el cliente Forever.
2. **Flags compuestos por substring** — la detección de crítico ahora usa
   `string_find(flagText, "CRITICAL")` en lugar de comparación exacta, para soportar
   flags compuestos (crítico + glancing/bloqueo, etc.).
3. **Color por escuela de daño** — el `schoolMask` de `UNIT_COMBAT` se propaga como
   `damageType`, restaurando el coloreado de daño por escuela en Forever.
4. **Valores secretos visibles en pantalla** — antes, los amounts "secretos" (daño,
   curación bajo las reglas de Secret Values de Midnight 12.x) se descartaban
   silenciosamente. Ahora pasan por el pipeline y se muestran: `FormatEvent`,
   los umbrales de daño/curación y el AoE merge están endurecidos para no operar
   aritmética ni patrones sobre valores secretos, y el `%a` del template se empalma
   al final con `string.find` + concatenación.
5. **Triggers con auras por API moderna** — las condiciones `buffActive` /
   `buffInactive` de triggers usan `C_UnitAuras.GetAuraDataByIndex` en lugar del
   global eliminado `UnitBuff`.

## Cómo funciona en WoW: Forever

El cliente Forever ejecuta contenido Classic, pero su motor es el de Midnight 12.x:

- **`WOW_PROJECT_ID` reporta `MAINLINE`** (no Classic). Por eso el TOC se llama
  `MikScrollingBattleText_Mainline.toc` (además de un `MikScrollingBattleText.toc`
  base) — un archivo `_Forever.toc` **no cargaría nunca**, y en silencio.
- **`COMBAT_LOG_EVENT_UNFILTERED` está bloqueado** para addons. La ingesta de combate
  se reconstruyó sobre los feeds sancionados:
  - `UNIT_COMBAT` — golpes (`WOUND`) y fallos sobre el jugador y el target.
  - `UNIT_SPELLCAST_SUCCEEDED/START/SENT` — correlación del último hechizo lanzado
    para atribuir el daño saliente.
  - `C_DamageMeter` — fallback sintético de totales de daño/curación propios
    (aproximación por delta de sesión, portada del fork Midnight).
  - `UNIT_POWER_UPDATE`, `PLAYER_REGEN_*`, `CHAT_MSG_MONSTER_EMOTE`, etc. para
    notificaciones fuera del combate.
- **Secret Values (`issecretvalue`)**: en combate, muchos números (daño, curación,
  vida, poder) llegan como valores opacos que lanzan error si se comparan, suman o
  les aplican `string.gsub`. Todo el pipeline de MSBT está protegido: los valores
  secretos se muestran directamente, sin acortar, colorear, fusionar ni filtrar por
  umbral; el valor se empalma en el mensaje en el último paso antes de `SetText`.
- **Hechizos multi-rango de Classic**: cada rango de cada hechizo tiene su propio
  `spellID`; la correlación de casts guarda el ID real del último cast.

### Cómo funciona el texto de combate en Forever (v1.2.0)

- **Daño y curación salientes = solo tuyos, siempre.** La única fuente es el
  medidor nativo `C_DamageMeter`, filtrado por tu GUID: nunca puede mostrar el
  daño de otros jugadores, ni duplicar golpes. Verificado en juego: el feed
  entrega datos incluso con el medidor de Blizzard desactivado en la interfaz.
- **Cada hechizo es independiente y se agrupa.** Los daños se acumulan por
  `spellID` y se muestran en una línea cuando el hechizo deja de producir
  (3.5 s) o al acabar el combate: `Hechizo (golpes) total` - un DoT que hace
  30 en 10 s se muestra como una sola línea con su número de golpes (estimado
  por ventanas de sondeo de 0.5 s; la API no expone conteos exactos).
- **Hechizos instantáneos de golpe único se muestran al momento**: si el daño
  del medidor llega ≤1 s después de castear ese hechizo, es su golpe directo y
  se muestra al instante (`Hechizo cantidad`). Solo se agrupan los daños en el
  tiempo: ticks de DoT/HoT, hechizos canalizados y golpes de arma.
- **El daño de arma es independiente**: llega bajo su propio ID del medidor y
  se muestra como número simple (estilo melee clásico), nunca mezclado con el
  último hechizo casteado.
- **Entrante**: daño recibido y misses sobre ti vía `UNIT_COMBAT` (con
  críticos y escuela de daño). En solitario también se muestran tus misses
  salientes; en grupo no (no se pueden atribuir).
- **Sin críticos salientes ni escuelas de color en los números salientes**: la
  API del medidor solo expone totales agregados, sin detalle por golpe.
- Las curaciones de otros jugadores sobre ti no se muestran (no se pueden
  atribuir a un caster).
- **Diagnóstico**: `/run MikSBT.DebugMeterInfo()` imprime qué devuelve el
  medidor en vivo (disponibilidad, fuentes de la sesión, hechizos y totales).
- Los triggers que dependían de subeventos del combat log (p. ej. detectar el
  hechizo exacto de un proc) no disponen de ese feed; el resto de triggers
  funciona.

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
