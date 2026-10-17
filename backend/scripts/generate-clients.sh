#!/usr/bin/env bash
# Genera los clientes de las Edge Functions desde backend/openapi.yaml (paso 39, plan.md §7 "Contrato").
#
#   backend/scripts/generate-clients.sh                 # los dos, en backend/build/clients/{swift,kotlin}
#   backend/scripts/generate-clients.sh swift [carpeta]
#   backend/scripts/generate-clients.sh kotlin [carpeta]
#
# - Swift: swift-openapi-generator de Apple (tipos + cliente, públicos). El código generado usa OpenAPIRuntime y
#   OpenAPIURLSession. Destino previsto: un target `LumbreAPIClient` dentro de ios/Packages/LumbreCore (o el plugin
#   de SwiftPM del generador apuntando a este openapi.yaml). Hoy la app usa su cliente a mano (EdgeFunctions.swift);
#   el generado sirve para comparar y para migrar cuando convenga.
# - Kotlin: openapi-generator (kotlin, jvm-retrofit2 + kotlinx.serialization), para la app de Android (paso 70).
#   Necesita Java 11+ y Node (npx).
# El directorio de salida (backend/build/) no va al repo. Antes de generar se corre el test de contrato.
set -euo pipefail
cd "$(dirname "$0")/.."

WHAT="${1:-all}"
SWIFT_GENERATOR_VERSION="1.14.1"
KOTLIN_GENERATOR_VERSION="7.26.0"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/lumbre"

deno test -A --quiet supabase/functions/_tests/contract.test.ts

swift_client() {
  local out="${1:-build/clients/swift}"
  local tool="$CACHE/swift-openapi-generator-$SWIFT_GENERATOR_VERSION"
  if [[ ! -x "$tool/.build/release/swift-openapi-generator" ]]; then
    mkdir -p "$CACHE"
    git clone --quiet --depth 1 --branch "$SWIFT_GENERATOR_VERSION" https://github.com/apple/swift-openapi-generator.git "$tool"
    swift build --package-path "$tool" -c release --product swift-openapi-generator
  fi
  mkdir -p "$out"
  cat > "$out/openapi-generator-config.yaml" <<YAML
generate:
  - types
  - client
accessModifier: public
namingStrategy: idiomatic
YAML
  "$tool/.build/release/swift-openapi-generator" generate openapi.yaml \
    --config "$out/openapi-generator-config.yaml" --output-directory "$out"
  echo "Swift: $out ($(ls "$out"/*.swift | xargs -n1 basename | tr '\n' ' '))"
}

kotlin_client() {
  local out="${1:-build/clients/kotlin}"
  npx --yes "@openapitools/openapi-generator-cli@2.41.0" version-manager set "$KOTLIN_GENERATOR_VERSION" >/dev/null
  npx --yes "@openapitools/openapi-generator-cli@2.41.0" generate -i openapi.yaml -g kotlin -o "$out" \
    --additional-properties=library=jvm-retrofit2,serializationLibrary=kotlinx_serialization,packageName=app.lumbre.api,enumUnknownDefaultCase=true
  echo "Kotlin: $out"
}

case "$WHAT" in
  swift) swift_client "${2:-}" ;;
  kotlin) kotlin_client "${2:-}" ;;
  all) swift_client; kotlin_client ;;
  *) echo "Uso: $0 [swift|kotlin|all] [carpeta]"; exit 2 ;;
esac
