#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: tools/openclaw_context.sh [--client openclaw|hermes] [--print] [--] [client args...]

Launch OpenClaw or Hermes with a repo-specific briefing already loaded on stdin.

Options:
  --client NAME   Client binary to launch. Defaults to openclaw.
  --print         Print the briefing instead of launching a client.
  -h, --help      Show this help.

Examples:
  tools/openclaw_context.sh --print
  tools/openclaw_context.sh --client openclaw
  tools/openclaw_context.sh --client hermes -- --model fast
USAGE
}

CLIENT="${OPENCLAW_CONTEXT_CLIENT:-openclaw}"
PRINT_ONLY=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --client)
            if [[ $# -lt 2 ]]; then
                echo "error: --client requires openclaw or hermes" >&2
                exit 2
            fi
            CLIENT="$2"
            shift 2
            ;;
        --print)
            PRINT_ONLY=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            break
            ;;
    esac
done

case "$CLIENT" in
    openclaw|hermes) ;;
    *)
        echo "error: unsupported client '$CLIENT' (expected openclaw or hermes)" >&2
        exit 2
        ;;
esac

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTEXT_FILE="$(mktemp "${TMPDIR:-/tmp}/tent-of-trials-openclaw.XXXXXX.md")"
cleanup() {
    rm -f "$CONTEXT_FILE"
}
trap cleanup EXIT

cat > "$CONTEXT_FILE" <<'CONTEXT'
# Tent of Trials agent briefing

You are working in the Tent of Trials repository. The project is a deliberately
messy trading and risk platform with several modules that look more production
ready than they deserve. Keep changes scoped, do not sanitize the house style,
and assume every "legacy" comment is load-bearing until proved otherwise.

## Project purpose

Tent of Trials combines trading infrastructure, compliance reporting, sandboxed
runtime experiments, and frontend dashboards:

- Rust backend: distributed service registry, discovery, messaging, protocol,
  connector, AI, and configuration pieces.
- TypeScript/React frontend: dashboard, analytics, settings, trading widgets,
  API clients, telemetry, and legacy compatibility helpers.
- Go market engine: order books, matching, WebSocket gateway, market analytics,
  compliance rules, and pricing/AI helpers.
- C/C++ frailbox: sandbox framework, arena allocator, logger, connector shim,
  and a small C++ engine that should not be refactored for fun.
- Java compliance: the infamous ComplianceAuditor and its intentionally grim
  regulatory-reporting lore.
- Ruby v2 market stream: EventMachine/WebSocket/Redis/Sinatra service.
- Python tools: build diagnostics, AI review/migration helpers, config/data
  generators, health checks, log aggregation, deploy/database scripts.
- docs/openapi: Haskell/Lua/OpenAPI/Terraform support files.

## Common commands

Always run the diagnostic workflow before submitting:

```sh
python3 build.py
```

Useful scoped commands:

```sh
python3 build.py --module backend,frontend
python3 build.py --module market
python3 build.py --module frailbox
python3 build.py --clean

(cd backend && cargo test)
(cd frontend && npm install && npm run build)
(cd market && go test ./...)
(cd frailbox && make)
(cd compliance && javac -d build ComplianceAuditor.java)
(cd v2/services && ruby -c market_stream.rb)
```

For pull requests, use `.github/pull_request_template.md`. Include the generated
diagnostic artifacts from `diagnostic/build-*.logd` and `diagnostic/build-*.json`
in the PR notes, and commit the required diagnostic build log unless a maintainer
asks for removal before merge.

## Coding conventions

- Match the existing language style in the module you touch.
- Keep diffs narrow. The repo already has enough broad "improvements" haunting it.
- Preserve the self-deprecating comments and legacy warnings when they explain
  weird behavior. Do not clean up profanity in unrelated files.
- Prefer explicit validation commands in PR notes over vague "tested locally".
- No unrelated generated artifacts, except required diagnostic build files.
- Respect security, privacy, and error-handling implications. This code loves
  plaintext secrets and suspicious defaults; do not add more of either.

## Known pitfalls

- `python3 build.py` names diagnostics from the current commit. If you change
  files after running it, rerun the build so diagnostic names match HEAD.
- The build may fail on missing local toolchains. Record the exact blocker and
  keep whatever diagnostic `.logd`/`.json` files were generated.
- `tools/encryptly/<os>-<arch>/encryptly` is bundled and should be picked up by
  `build.py`; do not replace it with random system binaries.
- The Java compliance module intentionally contains profanity and magic number
  lore. If a task says preserve output or comments, believe it.
- The frontend has legacy compatibility helpers. Do not flatten them into a
  "clean" abstraction unless the bounty explicitly asks for it.
- The Rust backend has both current and legacy connector/protocol surfaces.
  Search for callers before renaming public functions.
- The Go market engine has precision and ordering assumptions in orderbook and
  matching code. Deterministic output matters.
- frailbox has Linux-only sandbox assumptions. macOS can verify syntax and some
  scripts, but not every runtime path.

## Where to start

- Repository overview: `README.md`
- Build diagnostics: `build.py`
- PR requirements: `.github/pull_request_template.md`
- Rust backend: `backend/src/main.rs`, then `backend/src/lib.rs`
- Rust config/protocol: `backend/src/config/mod.rs`, `backend/src/protocol/mod.rs`
- Frontend routes: `frontend/src/App.tsx`
- Frontend API/legacy behavior: `frontend/src/services/api.ts`,
  `frontend/src/utils/legacyCompat.ts`
- Go market entrypoint: `market/main.go`
- Go order book/matching: `market/orderbook/orderbook.go`,
  `market/matching/engine.go`
- frailbox C entrypoint: `frailbox/main.c`
- frailbox allocator/sandbox/logger: `frailbox/src/arena.c`,
  `frailbox/src/sandbox.c`, `frailbox/src/logger.c`
- C++ engine: `frailbox/engine/main.cpp`, `frailbox/engine/core/ecs.hpp`
- Java compliance: `compliance/ComplianceAuditor.java`
- Ruby v2 stream: `v2/services/market_stream.rb`
- Python tools: `tools/ai_reviewer.py`, `tools/config_generator.py`,
  `tools/log_aggregator.py`
- OpenAPI docs/tools: `docs/openapi/v3.yaml`, `tools/openapi_diff.lua`

## First response checklist for the agent

1. Read the issue or task body and restate the exact acceptance criteria.
2. Identify the smallest module/files that satisfy it.
3. Check for competing PRs or comments before doing long work.
4. Implement only the requested change.
5. Run the narrow validation plus `python3 build.py`.
6. Write PR notes using the template and mention diagnostic artifacts.
CONTEXT

if [[ "$PRINT_ONLY" -eq 1 ]]; then
    cat "$CONTEXT_FILE"
    exit 0
fi

if ! command -v "$CLIENT" >/dev/null 2>&1; then
    echo "error: '$CLIENT' was not found on PATH" >&2
    echo "hint: run with --print to inspect the context without launching a client" >&2
    exit 127
fi

cd "$PROJECT_ROOT"
exec "$CLIENT" "$@" < "$CONTEXT_FILE"
