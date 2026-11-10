# Proceso de Creación del Skill `wow-forever-addon-adapter`

> Documento generado durante el desarrollo del proyecto MSBT-Addon.
> Fecha: 10 de noviembre de 2026.

## 1. Objetivo

Capturar, en un skill reutilizable para OpenCode, todo el conocimiento investigado
sobre la adaptación de addons de World of Warcraft al cliente **WoW: Forever**
(`1.60.1`, interfaz `16001`), de modo que futuras sesiones puedan portear, depurar
y publicar addons sin repetir la investigación desde cero.

La metodología seguida es la del skill oficial **`skill-creator`** de OpenCode:
*Capture Intent → Draft → Estructura (Progressive Disclosure) → Evals → Iteración*.

## 2. Captura de intención (Capture Intent)

Se respondieron las tres preguntas del framework `skill-creator`:

| Pregunta | Respuesta |
|---|---|
| ¿Qué debe hacer el skill? | Portear, depurar y publicar addons de WoW para el cliente Forever `1.60.1` y clientes Midnight `12.x`. |
| ¿Cuándo debe activarse? | Menciones de "WoW: Forever", interfaz `16001`, carpeta `_forever_`, errores con `COMBAT_LOG_EVENT_UNFILTERED`, *Secret Values* (`issecretvalue`), o addons de texto de combate tipo MSBT. |
| ¿Qué conocimiento encapsula? | La paradoja arquitectónica de Forever (contenido Classic sobre motor Midnight), reglas de `.toc`, feeds de combate sancionados, endurecimiento contra Secret Values y el bucle de desarrollo en vivo. |

## 3. Conocimiento fuente (investigación previa)

El contenido del skill proviene directamente de la investigación realizada en
las fases de planificación de este proyecto:

1. **Paradoja de Forever:** `WOW_PROJECT_ID == WOW_PROJECT_MAINLINE` con interfaz
   `16001` y contenido Classic+. Consecuencia crítica: el cargador de `.toc` solo
   busca sufijos `_Mainline`; un archivo `_Forever.toc` **se ignora silenciosamente**.
   Verificado con el `.toc` real de `NeeRgY/MSBT` v1.0.6.
2. **Eliminación de CLEU:** `COMBAT_LOG_EVENT_UNFILTERED` y
   `CombatLogGetCurrentEventInfo()` están bloqueados para addons (fuente: guía de
   cambios de Midnight 12.0 y código real de los forks).
3. **Secret Values:** verificado en el código publicado de `NeeRgY/MSBT`
   (`Forever/Code/MSBTParser.lua` usa `issecretvalue(guid)` con guardas) y en la
   documentación de Midnight 12.0.
4. **Evaluación de forks:** comparativa de 4 repositorios existentes
   (AndyMarigoldLabs-Midnight, NeeRgY, Nakuromi, Placidina) que determinó la
   estrategia *motor Midnight + capa de datos Classic*.

## 4. Estructura del skill (Progressive Disclosure)

```text
C:\Users\viban\.config\opencode\skills\wow-forever-addon-adapter\
├── SKILL.md                                  # Flujo principal (6 fases), reglas de oro
├── references/
│   ├── secret-values-and-combat-feeds.md     # Patrones Lua listos para usar
│   ├── forever-client-quirks.md              # TOC, C_* namespaces, CVars, multi-rank
│   └── msbt-forever-blueprint.md             # Arquitectura específica del port de MSBT
├── scripts/
│   ├── link-addon-forever.ps1                # Junction hacia _forever_\Interface\AddOns
│   └── audit-forever-compat.ps1              # Escáner estático de APIs prohibidas
└── evals/
    └── evals.json                            # 3 escenarios de prueba
```

Diseño conforme a *progressive disclosure*: `SKILL.md` mantiene el flujo de trabajo
y las reglas críticas (~150 líneas); los detalles profundos de Lua y las tablas de
API viven en `references/` y solo se leen cuando son necesarios; los scripts son
ejecutables directamente sin que el agente tenga que reescribirlos.

## 5. Contenido clave por archivo

- **`SKILL.md`** — las 6 fases del flujo: evaluación de forks → saneamiento de
  TOC/APIs → ingesta de combate sin CLEU (4 feeds sancionados) → endurecimiento
  contra Secret Values → bucle de depuración en vivo → documentación y release.
- **`secret-values-and-combat-feeds.md`** — tabla permitido/prohibido, patrón de
  formateo con "Format Order Rule" (empalmar el valor secreto al final), helper
  `spliceAmount`, guardas de `GetStringWidth`, y los 4 feeds (`UNIT_COMBAT`,
  `UNIT_SPELLCAST_SUCCEEDED`, `COMBAT_TEXT_UPDATE`, `PARTY_KILL`) con payload
  documentado.
- **`forever-client-quirks.md`** — reglas de `.toc` (`_Mainline.toc`, nunca
  `_Forever.toc`), tabla de migración de globals a `C_*`, helper seguro
  `MSBTGetSpellInfo`, rutas de cliente y CVars.
- **`msbt-forever-blueprint.md`** — comparativa de forks, mapa de módulos y la
  tabla de conversión subeventos-CLEU → feeds nuevos, más los 3 modos de filtrado
  de daño en grupo.
- **`link-addon-forever.ps1`** — autodetecta la instalación de WoW en varias
  unidades, crea/borra junctions de forma segura (nunca borra contenido).
- **`audit-forever-compat.ps1**` — 14 reglas estáticas con severidades, ignora
  comentarios, devuelve código de salida apto para CI.

## 6. Evals definidos (`evals/evals.json`)

| ID | Escenario | Comportamiento esperado |
|---|---|---|
| `secret-values-formatter-crash` | Error "secret string value" al curarse en combate | Reordenar el formateo: tokens no secretos primero, `%a` al final |
| `toc-not-loading-forever` | `_Forever.toc` no aparece en la lista de addons | Explicar `MAINLINE` → renombrar a `_Mainline.toc`/base |
| `port-ground-effects-no-cleu` | Portear efectos de suelo sin CLEU | `UNIT_COMBAT` + correlación de casts + tabla por nombre de hechizo |

## 7. Registro de iteraciones

| Iteración | Acción | Resultado |
|---|---|---|
| 1 | Borrador inicial del `SKILL.md` (con contenido inline completo) | El flujo de 6 fases y las reglas de oro quedaron definidos; se decidió mover los patrones Lua extensos a `references/` para cumplir la guía de <500 líneas |
| 2 | Escritura de las 3 referencias y 2 scripts | Scripts con autodetección de ruta de WoW y severidades ERROR/WARN |
| 3 | Evals + registro | Skill registrado y disponible en la sesión (`system-update` confirmó su carga) |

## 8. Validación

- El skill fue reconocido por OpenCode: aparece en el listado de skills disponibles
  con id `wow-forever-addon-adapter` tras su creación (confirmación en la sesión).
- Los scripts PowerShell se validarán sintácticamente en el primer uso real
  (Fase B del desarrollo del addon, paso de vinculación al cliente).
- Los evals se ejecutarán en sesiones futuras para medir la calidad del skill.

## 9. Uso

```
# El skill se activa automáticamente ante peticiones sobre addons de WoW: Forever,
# o puede invocarse explícitamente con el id wow-forever-addon-adapter.
```

Este proyecto (`D:\Projects\MSBT-Addon`) es el primer caso de aplicación real del
skill: el port de Mik's Scrolling Battle Text a WoW: Forever 1.60.1.
