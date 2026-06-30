#!/usr/bin/env bash
# =============================================================================
# generate-shared-types.sh — Generate TypeScript types from backend specs
#
# Usage: ./generate-shared-types.sh --source <openapi|prisma|graphql> [options]
#
#   --source <type>        Required: openapi, prisma, or graphql
#   --input <path|url>     Input spec path or URL (required for openapi)
#   --output <path>        Output file path (default: ../frontend/src/types/api.ts)
#   --config <path>        Optional: custom config file for codegen
#   --watch                Watch mode (only for some generators)
#
# Examples:
#   ./generate-shared-types.sh --source openapi --input http://localhost:8000/api/schema/
#   ./generate-shared-types.sh --source prisma --output ./frontend/src/types/db.ts
#   ./generate-shared-types.sh --source graphql --input ./schema.graphql
# =============================================================================

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────
SOURCE=""
INPUT=""
OUTPUT="../frontend/src/types/api.ts"
CONFIG=""
WATCH_MODE=false

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }
step()  { echo -e "${BLUE}[STEP]${NC} $*"; }

# ── Parse arguments ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --source)
            SOURCE="${2:-}"
            shift 2
            ;;
        --input)
            INPUT="${2:-}"
            shift 2
            ;;
        --output)
            OUTPUT="${2:-}"
            shift 2
            ;;
        --config)
            CONFIG="${2:-}"
            shift 2
            ;;
        --watch)
            WATCH_MODE=true
            shift
            ;;
        -h|--help)
            sed -n '2,17p' "$0"  # print header comments
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ── Validate arguments ──────────────────────────────────────────────────────
if [[ -z "$SOURCE" ]]; then
    error "--source is required (openapi, prisma, or graphql)"
    exit 1
fi

if [[ "$SOURCE" != "openapi" && "$SOURCE" != "prisma" && "$SOURCE" != "graphql" ]]; then
    error "Invalid source: $SOURCE. Must be one of: openapi, prisma, graphql"
    exit 1
fi

if [[ "$SOURCE" == "openapi" && -z "$INPUT" ]]; then
    error "--input is required for openapi source (URL or path to spec)"
    exit 1
fi

# ── Ensure output directory exists ──────────────────────────────────────────
OUTPUT_DIR=$(dirname "$OUTPUT")
mkdir -p "$OUTPUT_DIR"

# ── Route to appropriate generator ──────────────────────────────────────────
case "$SOURCE" in
    openapi)
        generate_from_openapi
        ;;
    prisma)
        generate_from_prisma
        ;;
    graphql)
        generate_from_graphql
        ;;
esac

info "TypeScript types written to: $OUTPUT"

# ── OpenAPI generator ───────────────────────────────────────────────────────
generate_from_openapi() {
    step "Generating TypeScript types from OpenAPI spec…"

    # Check for openapi-typescript
    if ! command -v npx &>/dev/null; then
        error "npx is not available. Please install Node.js and npm."
        exit 1
    fi

    # Install openapi-typescript if not present
    if ! npx openapi-typescript --version &>/dev/null 2>&1; then
        info "Installing openapi-typescript…"
        npm install --save-dev openapi-typescript
    fi

    # Determine if input is URL or local file
    local spec_file="$INPUT"
    if [[ "$INPUT" =~ ^https?:// ]]; then
        info "Fetching OpenAPI spec from $INPUT…"
        spec_file="/tmp/openapi-spec-$$.json"
        if command -v curl &>/dev/null; then
            curl -fsSL "$INPUT" -o "$spec_file"
        elif command -v wget &>/dev/null; then
            wget -q "$INPUT" -O "$spec_file"
        else
            error "Neither curl nor wget is available."
            exit 1
        fi
        info "Spec downloaded to $spec_file"
    fi

    # Generate types
    local args=()
    [[ "$WATCH_MODE" == true ]] && args+=("--watch")
    [[ -n "$CONFIG" ]] && args+=("--config" "$CONFIG")

    npx openapi-typescript "$spec_file" \
        --output "$OUTPUT" \
        "${args[@]}"

    # Cleanup temp file
    if [[ "$INPUT" =~ ^https?:// ]]; then
        rm -f "$spec_file"
    fi

    info "OpenAPI types generated successfully."
}

# ── Prisma generator ──────────────────────────────────────────────────────────
generate_from_prisma() {
    step "Generating TypeScript types from Prisma schema…"

    # Check for prisma
    if ! command -v npx &>/dev/null; then
        error "npx is not available. Please install Node.js and npm."
        exit 1
    fi

    # Install prisma if not present
    if ! npx prisma --version &>/dev/null 2>&1; then
        info "Installing prisma…"
        npm install --save-dev prisma
    fi

    # Find schema file if not provided
    local schema_file="$INPUT"
    if [[ -z "$schema_file" ]]; then
        if [[ -f "prisma/schema.prisma" ]]; then
            schema_file="prisma/schema.prisma"
        elif [[ -f "schema.prisma" ]]; then
            schema_file="schema.prisma"
        else
            error "No Prisma schema found. Use --input to specify the path."
            exit 1
        fi
    fi

    # Generate Prisma client with TypeScript types
    npx prisma generate \
        --schema="$schema_file" \
        --output="$OUTPUT"

    # If a TypeScript-specific generator is configured in schema, it will output
    # to the configured path. We also copy to the desired output if needed.
    if [[ -f "node_modules/.prisma/client/index.d.ts" ]]; then
        cp "node_modules/.prisma/client/index.d.ts" "$OUTPUT"
        info "Prisma types copied to $OUTPUT"
    fi

    info "Prisma types generated successfully."
}

# ── GraphQL generator ───────────────────────────────────────────────────────
generate_from_graphql() {
    step "Generating TypeScript types from GraphQL schema…"

    # Check for graphql-codegen
    if ! command -v npx &>/dev/null; then
        error "npx is not available. Please install Node.js and npm."
        exit 1
    fi

    # Install graphql-codegen if not present
    if ! npx graphql-codegen --version &>/dev/null 2>&1; then
        info "Installing @graphql-codegen packages…"
        npm install --save-dev @graphql-codegen/cli
        npm install --save-dev @graphql-codegen/typescript
        npm install --save-dev @graphql-codegen/typescript-operations
    fi

    # Find schema file if not provided
    local schema_file="$INPUT"
    if [[ -z "$schema_file" ]]; then
        if [[ -f "schema.graphql" ]]; then
            schema_file="schema.graphql"
        elif [[ -f "src/schema.graphql" ]]; then
            schema_file="src/schema.graphql"
        else
            error "No GraphQL schema found. Use --input to specify the path."
            exit 1
        fi
    fi

    # Generate config file if not provided
    local codegen_config="$CONFIG"
    if [[ -z "$codegen_config" ]]; then
        codegen_config="/tmp/codegen-$$.yml"
        cat > "$codegen_config" << EOF
overwrite: true
schema: "${schema_file}"
generates:
  ${OUTPUT}:
    plugins:
      - "typescript"
    config:
      skipTypename: false
      enumsAsTypes: true
      constEnums: false
EOF
    fi

    # Run codegen
    npx graphql-codegen --config "$codegen_config"

    # Cleanup temp config
    if [[ -z "$CONFIG" ]]; then
        rm -f "$codegen_config"
    fi

    info "GraphQL types generated successfully."
}
