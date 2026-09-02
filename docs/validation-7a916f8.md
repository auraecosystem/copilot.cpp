# Validation report: official SDK `7a916f8`

**Date:** 2026-09-01
**Branch:** `sdk-parity/7a916f8`
**Official SDK commit:**
`7a916f8af8fb11315e9d043156487f9076264145`
**Previous pin:** `6e6eb55f4d0f1ee222cfce3e64493781ef7c5be8` (see
[validation-6e6eb55.md](validation-6e6eb55.md))

## Environment

- Windows, Visual Studio 17 2022 generator, Release configuration
- CMake 4.0.3, Ninja 1.13.2 available, Python 3.12/3.13
- Official schema package baseline `@github/copilot@1.0.83-0`
- Protocol version 3 (unchanged from the previous pin)

The official checkout advanced 27 commits since `6e6eb55`. Both protocol
schemas changed, so the generated surface was refreshed rather than reused:

| Schema | Pinned at `6e6eb55` (1.0.81-6) | Pinned at `7a916f8` (1.0.83-0) |
|---|---|---|
| `api.schema.json` | `603b014a…bad558` | `a72281ca…969ca4` |
| `session-events.schema.json` | `9fd414f5…e5e8ec` | `93fb5153…8cc088` |

## Surface growth

| Metric | `6e6eb55` | `7a916f8` | Δ |
|---|---:|---:|---:|
| API definitions | 1,203 | 1,218 | +15 |
| Session-event definitions | 494 | 535 | +41 |
| Shared definitions | 53 | 54 | +1 |
| Unique definitions | 1,644 | 1,699 | +55 |
| RPC methods | 363 | 367 | +4 |
| Session-event variants | 122 | 133 | +11 |

New RPC methods (no removals):

- `session.sandbox.getEnforcementStatus`
- `session.factory.runFromTool`
- `session.factory.resumeFromTool`
- `gitHubToken.getToken`

New event wire types (no removals): six `*.fusion_*` routing events on
`session.`, three `assistant.fusion_phase_*` events, plus
`model.call_finished` and `subagent.configured`.

## Validation results

| Area | Command / evidence | Result |
|---|---|---|
| Fresh configure | `cmake -S . -B build-repin -G "Visual Studio 17 2022" -DCOPILOT_BUILD_TESTS=ON -DCOPILOT_BUILD_EXAMPLES=ON` | Pass |
| Fresh Release build | `cmake --build build-repin --config Release` | Pass; library, all tests, and all examples compiled with no errors |
| Full non-auth suite | `COPILOT_SDK_CPP_SKIP_E2E=1 ctest --test-dir build-repin -C Release` | **496/496 passed**, 0 failed; 71 authenticated E2E entries intentionally skipped |
| Code generation | `generate_protocol_types.py --check --official-sdk-root ..\copilot-sdk` and CMake `copilot_codegen_check` | Pass: 1,218 API definitions, 535 event definitions, 367 RPC methods, 133 event variants |
| Codegen idempotency | `--refresh` followed by `--check` with no intervening edits | Pass, no drift |
| Official-shape goldens | `Generated|PublicParity|Advanced` test filters | **30/30 passed** |
| FFI architecture loader | `FfiTransportTest.*` | **3/3 passed** |

The suite total moved from 494 to 496 because this change adds two catalog
assertions (`RpcMethodCatalogIncludesRepinAdditions`,
`WireTypesIncludeRepinAdditions`). No pre-existing test was removed or
weakened.

### Goldens updated for the new pin

`tests/test_generated.cpp` pins the upstream commit, schema package version,
coverage counts and both schema hashes. All were repointed to `7a916f8` /
`1.0.83-0`. These are intentional golden updates, not regressions — they are
the mechanism by which a stale pin is detected.

### Intentional skips

Unchanged from the previous pin: `ForegroundSessionSetAndGet` and
`ForegroundSessionInitiallyEmpty` remain skipped because the legacy foreground
RPCs are still absent from the official API schema. Their skip messages now
name `7a916f8`.

## Public surface status

Implemented in this pass:

| RPC | C++ surface |
|---|---|
| `session.sandbox.getEnforcementStatus` | `Session::get_sandbox_enforcement_status()` |
| `session.factory.runFromTool` | `SessionFactoryApi::run_from_tool()` |
| `session.factory.resumeFromTool` | `SessionFactoryApi::resume_from_tool()` |

## Residual risks and deferred work

1. ~~**`gitHubToken.getToken` is not wired.**~~ **CLOSED 2026-09-01.** Wired as a
   client-level provider: `ClientOptions::github_token_provider` +
   `GitHubTokenRequest` / `GitHubToken` / `GitHubTokenAcquireReason` in
   `types.hpp`, dispatched from the `set_request_handler` chain in
   `src/client.cpp` via `Client::handle_github_token_request`. Registration is
   not a handshake flag: the runtime addresses the callback by an opaque
   `registrationId`, which the client mints when a provider is configured and
   exposes as `Client::github_token_registration_id()` for the caller to install
   as a `token-provider` `AuthInfo`. The schema's `expiresIn >= 3601` minimum is
   enforced — a smaller value is declined as `{"kind":"cancelled"}` rather than
   emitted out of contract.
2. ~~**The 11 new events are typed in the generated layer but not in the
   hand-written one.**~~ **CLOSED 2026-09-01, and it was 52 not 11.** The map was
   already missing 41 wire types predating this re-pin. All **52** now have typed
   payload structs, enum values, variant arms, map entries and dispatch cases in
   `include/copilot/events.hpp`; **no generated wire type falls through to
   `SessionEventType::Unknown`**. Field names were recovered from the official
   `session-events.schema.json` and cross-checked against the pinned generated
   tag metadata — 49 of 50 structs matched exactly; `ManagedSettingsResolvedData`
   carries one extra optional field (`policyHelperManaged`) added in 1.0.83-1,
   harmless on a deserialize-only path. Enforced by
   an `EveryGeneratedWireTypeIsMapped` coverage assertion maintained out of tree.
   Note: instantiating the now-132-alternative `SessionEventData` variant needs
   `/bigobj` on MSVC, added to the library target as a PUBLIC option.
3. **No authenticated E2E run was performed for this pin.** The previous pin
   recorded 69 passed / 2 intentional skips / 0 failed. That matrix should be
   re-run against a live authenticated CLI before treating this pin as fully
   validated.

   **Attempted 2026-09-01 — still blocked, but not by the SDK.** With
   `COPILOT_SDK_CPP_E2E=1` all 71 entries still skip: the preflight loads
   `tests/byok.env`, which points the CLI at a third-party BYOK provider
   (`api.z.ai`) whose credential now returns **HTTP 401**. Every E2E test pays a
   ~9s preflight and then skips with
   *"Copilot CLI cannot make model calls (quota/auth)"*. The local CLI itself was
   updated to **1.0.83-1** (at or above this pin), so the blocker is purely the
   BYOK credential — supply a working `COPILOT_SDK_BYOK_API_KEY`, repoint
   `byok.env` at a reachable provider, or unset it to use native Copilot auth.
   (`tests/byok.env` is gitignored and untracked; no credential is in the repo.)
4. **Schema provenance came from the installed CLI package**, not an `npm pack`
   download — `@github/copilot@1.0.83-0` is a prerelease that the public registry
   would not serve. The local package at
   `%LOCALAPPDATA%\..\.copilot\pkg\win32-x64\1.0.83-0` self-identifies as
   `@github/copilot@1.0.83-0` and matches the version pinned in the official
   `nodejs/package-lock.json`, and the tool's own `validate_schema_package`
   check passed against it.

## Validation disposition

The re-pin is **green for unauthenticated validation**: everything compiles,
the generated surface is complete and idempotent, and the full non-auth suite
passes 496/496. It is **not yet fully validated** pending the authenticated E2E
matrix, and public-surface parity is **partial** by the deliberate scoping in
items 1 and 2 above.
