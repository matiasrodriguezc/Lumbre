# iOS

App de Lumbre en SwiftUI (Swift 6, iOS 17 o más; Liquid Glass en iOS 26).

## Estructura

| Carpeta | Qué va |
|---|---|
| `Lumbre.xcodeproj` | Proyecto de Xcode con carpetas sincronizadas: los archivos nuevos dentro de `Lumbre/` entran solos. |
| `Lumbre/App` | Punto de entrada y navegación (TabView flotante + Capturar). |
| `Lumbre/Features` | Una carpeta por pantalla: Hoy, Bóveda, Proyectos, Perfil, Capturar. |
| `Packages/LumbreDesign` | Tokens generados, tipografía y componentes (botones, chips, SparkCard, SparkMeter, ConceptCard). |
| `Packages/LumbreCore` | Modelos, el contrato `LumbreAPI` y `MockLumbreAPI` con datos de prueba. |
| `scripts/generate_tokens.py` | Genera los colores y tokens de LumbreDesign desde `design/system/tokens.json`. |

## Comandos

Regenerar los tokens después de cambiar `tokens.json`:

```bash
python3 ios/scripts/generate_tokens.py
```

Compilar para el simulador:

```bash
xcodebuild -project ios/Lumbre.xcodeproj -scheme Lumbre -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath ios/.build/DerivedData build
```

Correr los tests de LumbreCore:

```bash
cd ios/Packages/LumbreCore && xcodebuild test -scheme LumbreCore -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

O abrir `ios/Lumbre.xcodeproj` en Xcode y correr el esquema **Lumbre** (arranca en español de Argentina).

## Datos de prueba

Hasta que exista el backend, la app usa `MockLumbreAPI` (se inyecta en `LumbreApp.swift` con `@Environment(\.api)`). El paso 43 suma el cliente real y el cambio es de una línea.

## Pendientes conocidos

- **Fraunces:** el archivo de la fuente no está en el repo todavía. Mientras tanto los estilos display usan New York, la serif del sistema. Para activarla, copiar el variable font como `Packages/LumbreDesign/Sources/LumbreDesign/Resources/Fraunces.ttf`: el código la detecta sola.
- **Botón Capturar:** usa el lugar que iOS 26 le da a la pestaña de búsqueda, así que es de vidrio neutro y no magenta como en el componente NavBar. Un botón propio tintado no se puede fundir con la barra del sistema.
- **Ícono de app:** llega con el paso 8.
