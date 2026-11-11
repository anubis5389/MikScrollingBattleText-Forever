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

### Limitaciones conocidas (por diseño de la API de Forever)

- **Solo tu daño, una sola vez**: en grupo, el daño/curación salientes provienen
  exclusivamente del medidor `C_DamageMeter` (solo-jugador; totales por hechizo
  cada 0.5 s, sin detalle por golpe ni críticos) porque `UNIT_COMBAT` no permite
  atribuir golpes a un atacante concreto. En solitario, `UNIT_COMBAT` manda
  (detalle por golpe, críticos, escuelas) y el medidor se retira, evitando
  duplicados.
- La **curación saliente** (incluida la autocuración) llega siempre vía el
  medidor como totales agregados; no hay feed por golpe de curación saliente en
  Forever.
- Las curaciones de otros jugadores sobre ti no se muestran (no se pueden
  atribuir a un caster).
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
