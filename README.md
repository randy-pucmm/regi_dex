# RegiDex · Enciclopedia Pokémon de todas las Épocas

Pokédex móvil para **Android e iOS** construida con **Flutter**, que consume la API **GraphQL de PokéAPI** con una arquitectura **Offline-First + Online-Preferred**. Tiene temática de los Regis, interfaz de Pokédex moderna, trivia y un creador de equipos para **Pokémon Champions**.

> Proyecto final de **Desarrollo de Aplicaciones Móviles**: Pontificia Universidad Católica Madre y Maestra (PUCMM), Escuela de Ingeniería en Computación y Telecomunicaciones. Docente: Freddy Peña.

## Integrantes

| Integrante | Rol principal |
|---|---|
| **Randy A. Germosén** | Datos y sincronización: GraphQL, conectividad, sync, búsqueda y filtros, integridad, datos del Team Builder. |
| **Rafael J. Ramírez** | Persistencia e interfaz: Drift, kit UI Regi, catálogo, detalle, favoritos, trivia, UI del Team Builder. |

Ambos trabajamos en todas las capas y revisamos el código del otro mediante pull requests.

## Estado del proyecto

| Hito | Fecha | Estado |
|---|---|---|
| Sprint 0: documentación, diagramas y planificación | 23–26 oct 2026 | ✅ Completado |
| Entrega de **Avance** (≈40 %) | 11 nov 2026 | ⏳ En curso |
| **Entrega final** y defensa | 30 nov 2026 | ⏳ Pendiente |

Las secciones marcadas como *planificado* describen el diseño acordado y se actualizarán a medida que avance la implementación.

## Documentación

| Documento | Contenido |
|---|---|
| [Especificación de Requisitos (SRS)](docs/SRS_RegiDex.pdf) | Alcance, requisitos funcionales y no funcionales, casos de uso, criterios de aceptación y trazabilidad. |
| [Documento de Arquitectura](docs/Arquitectura_RegiDex.pdf) | Offline-First, persistencia y sincronización, GraphQL, conectividad, sistema de diseño Regi, **ADRs** y los 18 diagramas del proyecto (secuencias, modelo de datos, navegación…). |
| [Enunciado del Proyecto Final](docs/project/) | Requisitos oficiales de la asignatura. |

---

## 1. Descripción del proyecto

RegiDex permite:

- Consultar los **1025 Pokémon** de la Pokédex Nacional y su detalle: estadísticas, habilidades, evoluciones, movimientos, efectividad de tipos, formas y versión shiny.
- Gestionar **favoritos**.
- Jugar una **trivia** de siluetas.
- Armar **equipos para Pokémon Champions** (Singles y Dobles) con validación de Stat Points.

Todo funciona **con o sin conexión**: la interfaz siempre se construye desde la base local, y la app la actualiza en segundo plano cuando PokéAPI está disponible.

**Lo propio de nuestra versión:**

- Interfaz de **Pokédex moderna**. El lente superior es el **LED** del indicador global de conexión: se reconoce por su color, y al tocarlo muestra un *tooltip* con el detalle.
- **Seis temas** inspirados en los Regis: Regirock, Regice, Registeel, Regigigas, Regieleki y Regidrago, en claro y oscuro.
- **Búsqueda por nombre o número nacional** («25», «#025» o «pika»).
- **Filtros** por tipo, generación, **grupo huevo** y habilidad, con orden por nombre, número o total base.
- **Team Builder de Pokémon Champions**:
  - Pool de la regulación vigente.
  - Habilidad, objeto, naturaleza y 4 movimientos por miembro.
  - **Stat Points**: hasta 32 por estadística y 66 en total.
  - Sugerencias según el uso real en la escalera.
  - Exportación en formato Showdown.

![Mockup del indicador en sus cuatro estados](docs/assets/M01_pokedex_indicador.png)

## 2. Requisitos de ejecución

| Herramienta | Versión |
|---|---|
| Flutter | Canal estable compatible con Dart `^3.13` (ver `pubspec.yaml`) |
| Android | SDK con API 24 (Android 7.0) o superior; emulador o dispositivo físico |
| iOS *(opcional)* | macOS con Xcode; iOS 13 o superior |
| Red | Opcional después de la primera sincronización |

## 3. Instalación

```bash
git clone git@github.com:randy-pucmm/regi_dex.git
cd regi_dex
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # planificado: Drift, Freezed y JSON
flutter run
```

## 4. Tecnologías y justificación (*planificado*)

| Paquete | Uso | Justificación |
|---|---|---|
| `flutter_riverpod` | Estado e inyección de dependencias | Providers testeables y sustituibles; encaja con los streams de Drift (ADR-002). |
| `drift` + `sqlite3_flutter_libs` | Persistencia local | SQL tipado, consultas reactivas, transacciones y migraciones (ADR-001). |
| `graphql` | Cliente GraphQL | Cliente Dart puro; lo usamos sin caché porque la fuente de verdad es Drift (ADR-003). |
| `connectivity_plus` | Eventos de red | Disparador del health-check contra PokéAPI (ADR-007). |
| `cached_network_image` + `flutter_cache_manager` | Imágenes | Caché de disco LRU acotada; las imágenes no van a la BD (ADR-004). |
| `go_router` | Navegación | Rutas declarativas y shell con pestañas. |
| `freezed` + `json_serializable` | Modelos | Entidades inmutables, estados sellados y DTOs. |
| `crypto` | Integridad | `content_hash` para detectar datos alterados (ADR-006). |
| `fl_chart` · `share_plus` · `intl` | UI | Gráfico de estadísticas, compartir, i18n es/en. |

## 5. Arquitectura

Clean Architecture **por funcionalidades**: `presentation` → `domain` ← `data`.

- El dominio es Dart puro.
- La UI **solo observa la base local**.
- La red alimenta la base a través del coordinador de sincronización.

![Contexto del sistema](docs/diagrams/D01_contexto.png)

![Arquitectura por capas](docs/diagrams/D03_arquitectura_capas.png)

## 6. Estructura del proyecto

```text
lib/
├── app/        # bootstrap, DI, router
├── core/       # network, connectivity, database, sync, images, error
├── ui/         # sistema de diseño Regi: tokens, temas, componentes Pokédex
├── features/   # pokemon · favorites · trivia · team_builder · settings
│   └── <feature>/{presentation, domain, data}
└── l10n/       # app_es.arb · app_en.arb
```

## 7. Estrategia Offline-First

- **Lecturas:** la UI siempre lee de la base local (Drift/SQLite).
- **Actualización:** si PokéAPI responde, se descargan datos actualizados, se validan y se guardan **en transacción**; la UI recibe el cambio por observación.
- **Errores:** un fallo remoto nunca borra datos válidos.
- **Primera ejecución:** la app abre de inmediato y el catálogo llega por lotes en segundo plano.

El flujo completo y la secuencia de consulta están en el [documento de arquitectura](docs/Arquitectura_RegiDex.pdf) (§3).

## 8. GraphQL y estrategia de paginación

- **Endpoint:** `https://graphql.pokeapi.co/v1beta2` (solo POST).
- **Límite: 100 llamadas por hora por IP.** Por eso trabajamos con un presupuesto de ≤ 90 llamadas/h (ADR-005).
- **Paginación:** `limit/offset` ordenada por `id` sobre los 1025 Pokémon por defecto, en **lotes de 200**. El catálogo completo cuesta 6 llamadas y los datos de referencia 1.
- **Validación:** todas las consultas se validaron contra el servicio real el 23-oct-2026 y están documentadas en el [documento de arquitectura](docs/Arquitectura_RegiDex.pdf) (§6).

| Operación | Propósito |
|---|---|
| `GetReferenceData` | Tipos, generaciones, grupos huevo, eficacias, habilidades y movimientos (1 llamada). |
| `GetPokemonPage(limit, offset)` | Catálogo ligero paginado. |
| `GetPokemonDetail(id)` | Detalle completo con cadena evolutiva en **una** llamada. |
| `GetPokemonsByIds(ids)` | Verificación y restauración de datos alterados (OF-19). |
| `SearchPokemonRemote(pattern)` | Respaldo online de la búsqueda. |
| `HealthCheck` | Disponibilidad real del servicio. |

## 9. Estrategia de sincronización

| Aspecto | Decisión |
|---|---|
| Disparadores | Inicio, reconexión, abrir un detalle, cada 30 min y manual («Sincronizar ahora»). |
| Concurrencia | *Single-flight* por recurso. |
| Reintentos | Backoff exponencial con jitter: 2 s × 2ⁿ, tope de 60 s, máximo 5 intentos. |
| Interrupciones | Cada lote es una transacción con su avance en `sync_metadata`; se reanuda desde el último lote confirmado. |
| Datos alterados | `content_hash` por fila y verificación por lotes contra PokéAPI; **el remoto gana**. Los datos del usuario nunca se tocan. |

![Estados de sincronización](docs/diagrams/D08_estados_sync.png)

## 10. Persistencia local

SQLite con Drift: claves estables de PokéAPI, tablas puente e índices para búsqueda y filtros. Los datos del usuario (favoritos, trivia, logros, equipos y preferencias) viven en tablas separadas.

Las **imágenes no se guardan en la base de datos**:

- El artwork pesa entre 120 y 210 KB por Pokémon, unos 165 MB en total.
- Se usa una caché de archivos LRU de 150 MB.
- Los favoritos quedan fijados para uso offline (ADR-004).

El modelo de datos completo (diagramas ER) y la política de imágenes están en el [documento de arquitectura](docs/Arquitectura_RegiDex.pdf) (§5).

## 11. Gestión de conectividad

El estado del servicio se decide con un **health-check real contra PokéAPI**, no solo con la presencia de Wi-Fi o datos. La sincronización es una dimensión independiente.

**Cuatro estados del LED.** Cada uno combina color, glifo, texto y una etiqueta `Semantics`:

| Estado | Glifo |
|---|---|
| En línea | ● |
| Sin conexión | ○ |
| Servicio no disponible | ▲ |
| Sincronizando | ↻ |

**Comportamiento.**

- Una histéresis de 1.5 s evita parpadeos.
- Al tocar el LED se ve el detalle: red, API, origen y hora de los datos, y próximo reintento.

**Herramientas para la demo.** Ajustes → Depuración → **Simular API caída** permite demostrar PA-08 con la red activa.

![Estados de conectividad](docs/diagrams/D07_estados_conectividad.png)

## 12. Funcionalidades adicionales

| Funcionalidad | Detalle |
|---|---|
| Temas Regi | 6 temas con variante clara y oscura; contraste WCAG AA verificado por script. |
| Team Builder Champions | Datos de [Pokémon Champions Battle Data](https://championsbattledata.com/api_guide) con caché de 24 h; validación de SP (≤ 32 por stat, ≤ 66 en total); exportación a Showdown. |
| Búsqueda por número | Además del nombre, acepta el número de la Pokédex Nacional. |
| Filtro por grupo huevo | Combinable con tipo, generación y habilidad. |
| Pokémon Card | Tarjeta compartible como imagen. |

![Temas Regi](docs/assets/M02_temas_regi.png)

## 13. Limitaciones conocidas

- **Límite de PokéAPI** de 100 llamadas por hora por IP. El refresco periódico puede posponerse para no superarlo.
- **Reinicio diario de PokéAPI** a las 01:00 UTC (21:00 en RD), unos 2 minutos. La app lo muestra como «Servicio no disponible».
- **Efectos de habilidades:** PokéAPI suele tenerlos solo en inglés; se muestran en inglés cuando no hay traducción.
- **Pokémon Champions Battle Data** es un servicio comunitario sin SLA y no publica la regulación; las reglas se empaquetan en la app y se revisan manualmente.
- **iOS** requiere macOS con Xcode para compilar; la demostración principal es en Android.

---

## Decisiones de arquitectura (ADR)

El texto completo de cada ADR (contexto, decisión, alternativas y consecuencias) está en el [documento de arquitectura](docs/Arquitectura_RegiDex.pdf) (§11).

| ADR | Decisión | Responsable |
|---|---|---|
| ADR-001 | Drift (SQLite) como fuente de verdad observable | Randy |
| ADR-002 | Riverpod para estado e inyección de dependencias | Rafael |
| ADR-003 | Cliente `graphql` sin caché normalizada y DTOs propios | Randy |
| ADR-004 | Imágenes fuera de la base de datos (caché LRU y favoritos fijados) | Rafael |
| ADR-005 | Presupuesto de llamadas a PokéAPI (≤ 90/h) | Randy |
| ADR-006 | Detección de alteraciones locales con hash de contenido | Randy |
| ADR-007 | Monitor de conectividad con health-check e histéresis | Randy |
| ADR-008 | Champions Battle Data como fuente secundaria | Randy |
| ADR-009 | Sistema de diseño Regi sobre Material 3 | Rafael |
| ADR-010 | Simulador de caída de API e inspector de BD | Rafael |
| ADR-011 | Internacionalización con ARB (es/en) | Rafael |

## Cronograma

![Cronograma](docs/diagrams/D18_cronograma.png)

## Créditos y avisos

- Datos de Pokémon: [PokéAPI](https://pokeapi.co).
- Battle data provided by [Pokémon Champions Battle Data](https://championsbattledata.com).
- Pokémon y sus nombres son marcas de Nintendo, Game Freak y Creatures Inc. RegiDex es un proyecto académico sin fines de lucro, no afiliado ni respaldado por ellos.
