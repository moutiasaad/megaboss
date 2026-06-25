<!-- code-review-graph MCP tools -->
## MCP Tools: code-review-graph

**IMPORTANT: This project has a knowledge graph. ALWAYS use the
code-review-graph MCP tools BEFORE using Grep/Glob/Read to explore
the codebase.** The graph is faster, cheaper (fewer tokens), and gives
you structural context (callers, dependents, test coverage) that file
scanning cannot.

### When to use graph tools FIRST

- **Exploring code**: `semantic_search_nodes` or `query_graph` instead of Grep
- **Understanding impact**: `get_impact_radius` instead of manually tracing imports
- **Code review**: `detect_changes` + `get_review_context` instead of reading entire files
- **Finding relationships**: `query_graph` with callers_of/callees_of/imports_of/tests_for
- **Architecture questions**: `get_architecture_overview` + `list_communities`

Fall back to Grep/Glob/Read **only** when the graph doesn't cover what you need.

### Key Tools

| Tool | Use when |
|------|----------|
| `detect_changes` | Reviewing code changes — gives risk-scored analysis |
| `get_review_context` | Need source snippets for review — token-efficient |
| `get_impact_radius` | Understanding blast radius of a change |
| `get_affected_flows` | Finding which execution paths are impacted |
| `query_graph` | Tracing callers, callees, imports, tests, dependencies |
| `semantic_search_nodes` | Finding functions/classes by name or keyword |
| `get_architecture_overview` | Understanding high-level codebase structure |
| `refactor_tool` | Planning renames, finding dead code |

### Workflow

1. The graph auto-updates on file changes (via hooks).
2. Use `detect_changes` for code review.
3. Use `get_affected_flows` to understand impact.
4. Use `query_graph` pattern="tests_for" to check coverage.

## Session Changes (2026-06-22)

### Pickups — completed pickups not showing
- Added `Endpoints.pickups` (`/driver/pickups`) + `PickupService.list()` / `PickupRepository.list()` / `PickupRepository.cachedList`
- Controller tries list endpoint first, falls back to `/active` endpoint and old `cachedActive` cache key

### Pickups — false offline banner
- `PickupsController._backgroundRefresh()` calls `Connectivity().checkConnectivity()` before setting `offline=true`
- Server errors (5xx, timeout) no longer show the offline banner

### PickupDetail — accept/refuse silent failure
- `accept()`/`refuse()` in `PickupDetailController` save previous state, restore on error, and `rethrow`
- `_doAccept`/`_doRefuse` show a snackbar on error

### PickupDetail — hide scan FAB + Clôture when manifest is closed
- Scan FAB hidden when `pickup.status == PickupStatus.completed`
- Clôture button hidden when `pickup.status == PickupStatus.completed` (`allCollected && !isClosed`)

### ScanDelivery — remove Échec button + dead code
- Removed "Échec" button from `_ConfirmationSheet` (only "Livré" + "Retour")
- Removed `onFail` callback/parameter from `_ConfirmationSheet`
- Removed `_doFail` method from state class
- Removed `_FailReasonSheet` + `_ReasonTile` dead code

### RunsheetDetail — add Retour button with bottom sheet
- Added `onReturn` callback to `_MbStopCard`
- Added red OutlinedButton with `Icons.replay_rounded` between phone and "Livrer"
- `_ReturnSheet` bottom sheet with two options:
  - **Retour définitif** → `POST /driver/scan/delivery` `{status: "returned", return_type: "definitive", comment: "Client absent"}`
  - **Reprogrammer** → `POST /driver/scan/delivery` `{status: "failed", return_type: "reschedule", reschedule_date: "2026-06-25", comment: "Client a demandé un autre jour"}`
- Uses `ScanRepository.scanDelivery()` directly
- Invalidates `runsheetDetailProvider` on success

### Auto-refresh on return
- `PickupsScreen` → after popping from `PickupDetailScreen`: `ref.invalidate(pickupsProvider)`
- `PickupDetailScreen` → after popping from `PickupScanScreen`: `ref.invalidate(pickupDetailProvider(id))`
- `RunsheetDetailScreen` → after popping from `ScanDeliveryScreen`: `ref.invalidate(runsheetDetailProvider(widget.id))`

### Blockers
- Login returns HTTP 500: `POST /driver/login` → `{"success":false,"message":"Une erreur interne est survenue."}` — server-side bug (Laravel exception), confirmed via curl
- Auth token `8|VTweIVHDVuaRSGDvFB2AxdRmvGmrPTcrffHfTVtI947d8565` is expired (401 on all endpoints), cannot refresh because login itself fails
