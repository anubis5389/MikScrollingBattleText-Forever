# Arquitectura de MSBT en WoW: Forever (1.60.1)

Documento técnico del port. Fecha: 2026-11-10.

## 1. La paradoja del cliente Forever

| Aspecto | Valor | Consecuencia |
|---|---|---|
| Contenido | Vanilla Classic+ | Tablas de hechizos/talados/recursos de Classic (multi-rango) |
| Motor | Midnight 12.x | `C_Spell`, `C_UnitAuras`, `C_AddOns`, Secret Values |
| `WOW_PROJECT_ID` | `WOW_PROJECT_MAINLINE` | El cargador de TOC solo busca base y `_Mainline` |
| Interfaz | `16001` (game `1.60.1`) | TOC: `## Interface: 16001` |
| Carpeta | `_forever_\Interface\AddOns\` | Junction de desarrollo apunta aquí |
| CLEU | Bloqueado para addons | Ingesta reconstruida con feeds sancionados |

Detección en runtime (no usar `WOW_PROJECT_ID`):

```lua
local isForever = tonumber((select(4, GetBuildInfo()))) == 16001
```

`MikSBT.Client` (en `Forever/Code/MikSBT.lua`) expone `isForever`,
`isClassicContent` y `isVanillaContent` ya calculados así.

## 2. Estructura del paquete

```
MikScrollingBattleText/
├── MikScrollingBattleText.toc            # base, Interface 16001
├── MikScrollingBattleText_Mainline.toc   # sabor Mainline (el cliente Forever
│                                         #  se autoidentifica como MAINLINE)
├── Libs/                                 # LibStub, CallbackHandler, LibSharedMedia
├── Localization/                         # localización compartida (xml + idiomas)
├── Artwork/Fonts/Sounds/                 # media del addon
└── Forever/
    ├── Code/
    │   ├── MikSBT.lua                    # namespace núcleo; wrappers C_Spell
    │   │                                 #  (GetSpellInfo/Cooldown/Texture) con
    │   │                                 #  pcall + guardas IsAccessible/SafeNumber
    │   ├── MSBTProfiles.lua              # perfiles; eventos por defecto Classic
    │   ├── MSBTParser.lua                # parser: intenta CLEU (muerto en Forever,
    │   │                                 #  vivo en otros clientes del paquete)
    │   ├── MSBTMain.lua                  # display pipeline + fallback Forever
    │   │                                 #  (UNIT_COMBAT + correlación + DamageMeter)
    │   ├── MSBTMedia.lua                 # fuentes/sonidos
    │   ├── MSBTAnimations.lua            # motor de animación
    │   ├── MSBTTriggers.lua              # triggers (condiciones, auras vía C_UnitAuras)
    │   ├── MSBTCooldowns.lua             # alertas de cooldown (polling por OnUpdate)
    │   ├── MSBTLoot.lua                  # loot/dinero/XP/reputación
    │   ├── MSBTAnimationStyles.lua       # estilos de animación
    │   └── MSBTMinimapButton.lua         # botón de minimapa
    └── MSBTOptions/                      # UI de opciones (cargada bajo demanda)
```

## 3. Flujo de datos del combate en Forever

```
UNIT_COMBAT ──────────────┐
UNIT_SPELLCAST_* ─────────┤
C_DamageMeter (poll 0.5s) ┼──► ParserEventsHandler(parserEvent)
UNIT_POWER_UPDATE ────────┤         │
CHAT_MSG_MONSTER_EMOTE ───┘         ▼
                          MSBTParser.RegisterHandler
                                    │
                          handler(parserEvent, profile)   ← Damage/Miss/Heal/...
                                    │  devuelve (eventTypeString, effectName,
                                    │            unitName, class, mergeEligible)
                                    ▼
                          FormatEvent(message, amount, ...)   ← %a al FINAL si es secreto
                                    │
                          mergeEligible? → unmergedEvents → MergeEvents (AoE merge)
                          no mergeable → DisplayEvent inmediato
                                    │
                          FontString:SetText()   ← único "sink" donde el secreto
                                                   se materializa
```

### 3.1 Fallback Forever en `MSBTMain.lua`

Activado solo si `MikSBT.Client.isForever` (registro de eventos en `Enable()`).
Cada dirección ("stand-down") se apaga cuando el combat log real entrega un
evento válido (`incomingLogSeen` / `outgoingLogSeen`) — en Forever nunca ocurre,
por lo que el fallback permanece activo toda la sesión.

- **Outgoing (target):** `UNIT_COMBAT(target, WOUND|MISS...)` → atribuido al
  último cast del jugador (`lastPlayerSpellID`, ventana de 4 s). En grupo, cede
  al medidor si este ya está entregando (`meterDeliveredThisCombat` + `IsInGroup()`),
  y respeta 1 s tras el último delta del medidor para no duplicar.
- **Incoming (player):** `WOUND` → daño; `HEAL` → curación (autocuración si hay
  cast propio reciente); `MISS`/`DODGE`/... → evento miss.
- **Medidor:** `C_DamageMeter.GetCombatSessionSourceFromType` polled cada 0.5 s
  en combate; convierte deltas de totales por hechizo en eventos sintéticos.
  `SafeAddZero` (pcall `value + 0`) detecta y descarta valores secretos en esa vía.

### 3.2 Secret Values — puntos de control

| Punto | Guarda |
|---|---|
| `UNIT_COMBAT` amounts | Se pasa el valor crudo; solo los números planos se filtran por `<= 0` |
| Umbrales (`DamageHandler`/`HealHandler`) | `not (issecretvalue and issecretvalue(amount))` antes de comparar |
| `mergeEligible` | Se fuerza a `false` si el amount es secreto (el merge suma amounts) |
| `FormatEvent` — overheal/overkill | Se salta la aritmética si el amount/overheal/overkill es secreto |
| `FormatEvent` — ShortenNumber/FormatLargeNumber | Solo con números planos |
| `FormatEvent` — `%a` | Se sustituye con `string_gsub` solo si no es secreto; si lo es, `pendingSecretAmount` se empalma al final con `string_find(rest, "%a", 1, true)` + `string_sub` + concatenación |
| Orden de sustitución | `%n/%s/%e/%t` (patrones) SIEMPRE antes de introducir el secreto en el mensaje |
| Medidor (`C_DamageMeter`) | `SafeAddZero` descarta entradas secretas |
| `UnitPower`/`UnitPowerMax` | Wrappers locales que devuelven nil ante secretos |
| `UnitName` en eventos sintéticos | `NonSecret()` lo convierte en nil si es secreto |

### 3.3 Parser (MSBTParser.lua)

El parser conserva la máquina de búsqueda CLEU (GlobalStrings, capturas,
reordenación) que funciona en otros clientes del paquete upstream. En Forever:
`MikSBT.RegisterCombatLogEvent` maneja el rechazo del registro con el callback
`onBlocked` y marca `MikSBT.combatLogBlocked`; el parser queda en stand-by y el
fallback de MSBTMain toma el control. Este diseño evita errores de taint y no
duplicará eventos si Blizzard habilita alguna vía del log en el futuro.

## 4. Decisiones de diseño (ADRs resumidos)

1. **Base = NeeRgY, no Midnight**: el paquete NeeRgY ya trae el árbol Forever,
   datos Classic (triggers, perfiles, minimapa, opciones) y fallbacks portados;
   Midnight solo aportó patrones de endurecimiento. Rebase completo habría
   requerido portar la capa de datos de cero.
2. **Mejorar el fallback en MSBTMain en vez de transplantar el parser Midnight**:
   el parser Midnight vive en un código base de distinta era (TOC 120100, helpers
   `MSBTGetSpellInfo`, contratos ligeramente distintos); el fallback de NeeRgY ya
   tenía correlación, medidor y stand-downs. El transplante habría duplicado la
   ingesta (riesgo de eventos dobles).
3. **Secretos se muestran, no se descartan**: el approach upstream (drop silencioso)
   deja al addon "mudo" justo cuando el grupo combate; mostrar el valor crudo es
   fiel al propósito de MSBT y Midnight demuestra que es seguro.
4. **TOC base + `_Mainline`**: un solo árbol de código `Forever/` cargado por ambos
   TOCs; nada de Retail se carga en Forever.
5. **Trigger auras vía `C_UnitAuras`**: `UnitBuff` puede no existir en el motor
   12.x; la condición por nombre recorre `GetAuraDataByIndex("player", i, "HELPFUL")`.

## 5. Bucle de desarrollo

1. Edita el código en `D:\Projects\MSBT-Addon\MikScrollingBattleText`.
2. Junction activa: `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\MikScrollingBattleText`
   → la carpeta del repo (creada con `scripts/link-addon-forever.ps1`).
3. `python tools\check_syntax.py MikScrollingBattleText` — 0 fallos requerido.
4. Auditoría estática: `audit-forever-compat.ps1` (skill `wow-forever-addon-adapter`).
5. En el juego: `/console scriptErrors 1` → `/reload` → probar
   (ver plan de iteraciones en `docs/SKILL_CREATION_PROCESS.md` y CHANGELOG).
6. `!BugGrabber` está instalado en el cliente: revisar errores capturados tras
   cada iteración con `/buggrabber` o su ventana.

## 6. Iteraciones pendientes / roadmap

- [ ] Iteración 1 en juego: carga, `/msbt`, opciones, perfiles.
- [ ] Iteración 2: combate en solitario (melee, spells, DoTs, críticos, misses, cooldowns).
- [ ] Iteración 3: grupo/mazmorra (secret values, filtrado de daño ajeno).
- [ ] Iteración 4: loot/XP/reputación/honor/skill-ups.
- [ ] Publicar release v1.1.0 en GitHub con zip instalable (GitHub Action opcional).
