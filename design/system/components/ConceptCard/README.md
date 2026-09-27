# ConceptCard
El átomo de la bóveda: un concepto destilado con título, tesis en una frase, dominio y fuente.

- El consumidor provee: dominio (chip), título (`headline`), tesis (`callout`, una frase), fuente y fecha (`caption` en `ink-muted`).
- Estado "destilando": título y tesis como placeholders con shimmer del sistema (`redacted(reason: .placeholder)` en iOS, placeholder de Compose en Android).
- La tarjeta se puede editar: tocar abre el detalle con la tesis editable y el texto original colapsado.
- No muestres el texto crudo en la lista. No uses `spark` en esta tarjeta.
