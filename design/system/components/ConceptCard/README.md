# ConceptCard
El átomo de la red: una neurona destilada con título, tesis en una frase, dominio y fuente.

- Con la identidad neuronal no es una tarjeta: es un nodo del axón de la lista. Neurona chica en `ink` como nodo, dominio en `ink-muted`, título (`headline`), tesis (`callout` en `ink-muted`) y fuente. La línea `border` une los nodos (`axonRow` en iOS).
- El consumidor provee: dominio, título, tesis (una frase), fuente y fecha.
- Estado "destilando": título y tesis como placeholders con shimmer del sistema (`redacted(reason: .placeholder)` en iOS, placeholder de Compose en Android).
- La tarjeta se puede editar: tocar abre el detalle con la tesis editable y el texto original colapsado.
- No muestres el texto crudo en la lista. No uses `spark` en esta tarjeta.
