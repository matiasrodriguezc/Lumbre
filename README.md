# Lumbre

App de creatividad por recombinación para iOS (SwiftUI) y Android (Jetpack Compose).

## Estructura

| Carpeta | Qué va |
|---|---|
| `ios/` | App de iOS: proyecto de Xcode y paquetes SPM (LumbreDesign, LumbreCore, uno por feature). |
| `android/` | App de Android: módulos Gradle por capa y feature. |
| `backend/` | Supabase: migraciones, Edge Functions, tests de RLS y el esquema base. |
| `web/` | Landing con waitlist y demo web de la chispa. |
| `design/` | Design system, logo, copy y prototipos. |
| `docs/` | Plan maestro visual, backlog exportado y documentación de producto. |

## Archivos clave

| Archivo | Qué es |
|---|---|
| `plan.md` | Documento de referencia con todas las decisiones. Si algo contradice a otro archivo, manda este. |
| `plan-ejecucion.md` | Plan de ejecución del backlog de Linear, un paso por sesión. |
| `CLAUDE.md` | Reglas de trabajo del proyecto para Claude Code. |
| `docs/plan-maestro.html` | Plan visual: flujo de pantallas, mockups iOS/Android, arquitectura, costos, fases y marketing. Abrir en el navegador. |
| `docs/backlog.csv` | Backlog completo (estados, área, fase, versión, prioridad). La fuente viva es Linear, proyecto Lumbre. |
| `design/system/README.md` | Brand book: principios, voz, color, tipografía, logo, plataformas. |
| `design/system/tokens.json` | Tokens de diseño (fuente única para Swift y Kotlin). |
| `design/system/tokens.css` | Los mismos tokens en CSS, para web y prototipos. |
| `design/system/components/` | Guías y previews HTML de cada componente (abrir junto con `bundle.css` y `tokens.css`). |
| `design/system/logo/` | Símbolo, ícono de app y logos en SVG, más la hoja de preview. Las versiones descartadas están en `anteriores/`. |
| `design/system/tipografias.html` | Comparación de las opciones tipográficas evaluadas. |
| `backend/supabase/migrations/` | Esquema de Postgres + pgvector en migraciones: conceptos, chispas, cuotas y RLS. Ver `backend/README.md`. |

Versiones publicadas:
- Plan maestro: https://claude.ai/artifact/5iV97U3ZbfsQG7YLNhQRrv
- Design system: https://claude.ai/artifact/9WfjY7YYfFwNrd92prTw3D
