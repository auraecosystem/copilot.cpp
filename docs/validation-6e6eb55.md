# Validation report: official SDK `6e6eb55`

**Date:** 2026-08-24
**Branch:** `sdk-parity/6e6eb55`
**Official source:** `github/copilot-sdk` commit
`6e6eb55f4d0f1ee222cfce3e64493781ef7c5be8`
**Result:** **PASS — current-official parity validated on Windows x64**

## Environment

- Windows x64
- Visual Studio 2022 / MSVC 19.44.35228
- CMake 4.0
- Python 3.13.15
- SDK protocol version 3
- Official schema package baseline `@github/copilot@1.0.81-6`
- `copilot --version`: 1.0.81-8
- Runtime reported by the connection handshake: 1.0.81-9, protocol 3

No credentials, tokens, account names, or other authentication material were
captured in this report.

## Validation results

| Area | Command / evidence | Result |
|---|---|---|
| Fresh configure | `cmake -S . -B build-validation-final -DCOPILOT_BUILD_TESTS=ON -DCOPILOT_BUILD_EXAMPLES=ON` | Pass |
| Fresh Release build | `cmake --build build-validation-final --config Release` | Pass; library, all tests, and all examples compiled |
| Full non-auth suite | `COPILOT_SDK_CPP_SKIP_E2E=1 ctest --test-dir build-validation-final -C Release --output-on-failure` | **494/494 passed**, 71 authenticated E2E tests intentionally skipped |
| Code generation | CMake `copilot_codegen_check` plus direct `generate_protocol_types.py --check --official-sdk-root ...` | Pass: 1,203 API definitions, 494 event definitions, 363 RPC methods, 122 event variants |
| Official-shape goldens | Generated/public/advanced parity test filters | **26/26 passed** |
| FFI architecture loader | `FfiTransportTest.*` using a DLL exporting the official `copilot_runtime_*` ABI | **3/3 passed**, including blocked-read cancellation and missing-library errors |
| Installed CMake package | Install to a clean prefix, configure/build/run an external `find_package(copilot_sdk_cpp CONFIG REQUIRED)` consumer | Pass after fixing the bundled `nlohmann_json` fallback |
| Examples / consumer compilation | Fresh build compiled all repository examples; external consumer compiled generated, canvas, session, and runtime APIs | Pass |

## Authenticated Copilot CLI validation

The complete authenticated matrix was run with a per-test 120-second bound.
The consolidated result was **69 passed, 2 intentionally skipped, 0 failed**
across 71 scenarios. The two skips are the legacy foreground-session tests;
their RPCs are absent from the official `6e6eb55` generated API.

Validated live workflows include startup/shutdown, concurrent RPC, create and
resume, tools and permissions, hooks, user input, elicitation registration,
MCP and custom agents, attachments, streaming, compaction, model discovery,
event parsing, lifecycle, status/auth, caching, and graceful/forced teardown.

The validation run discovered and fixed:

- ISO-8601 ping timestamp compatibility
- fail-open preservation of evolved event payloads
- protocol-v3 external-tool, permission, and user-input event handling
- current `connect`/account status RPC usage
- environment-dependent model selection in E2E tests
- bounded process waits and client shutdown mutex deadlocks
- resumable test cleanup
- caller session-ID pre-registration/remapping
- installed-package fallback when `nlohmann_json` is not separately installed
- stdio reader shutdown after process termination
- handler-enabled session creation with bounded E2E waits
- protocol-v3 handler registration and payload compatibility

### Root-cause resolution

RPC tracing showed that handler-enabled `session.create` calls completed and
returned valid responses. The apparent create hangs occurred during test
cleanup: `JsonRpcClient::stop()` joined its stdio reader while
`PipeTransport::close()` intentionally left the process-owned pipe handles
open. A descendant runtime process could therefore keep `ReadFile` blocked.

The fix adds `Process::close_pipes()` on Windows and POSIX and calls it after
bounded process termination but before joining the JSON-RPC reader. A
time-bounded process regression test and 30-second handler-create E2E bounds
prevent recurrence. Hook, user-input, and elicitation-enabled creation all
pass against the authenticated runtime.

### Intentional skips

1. `ForegroundSessionSetAndGet`
2. `ForegroundSessionInitiallyEmpty`

Both exercise legacy compatibility RPCs that do not exist in the official
`6e6eb55` generated RPC surface.

`tests/byok.env` was not present. This did not block authenticated testing;
the installed Copilot CLI authentication was used instead.

## Static analysis and sanitizers

No static-analysis or sanitizer target is defined by this repository.
`clang-tidy`, `cppcheck`, and `clang-cl` were not installed on this machine, so
those optional checks were skipped. The fresh MSVC build completed without
compiler warnings in the validation output.

## Residual risks

- The native FFI loader was validated against the exact ABI with a test DLL,
  but not against a real packaged `runtime.node` in this run.
- Linux, Linux-musl, and macOS builds were not executed; only Windows x64 was
  compiled and tested.
- Cloud-session creation and parent-process extension joining were compile/
  golden tested but not exercised against a live host.
- The local runtime was newer (`1.0.81-9`) than the official SDK schema package
  baseline (`1.0.81-6`), although both negotiated protocol version 3.

## Validation disposition

The current-official surface is validated for the tested Windows x64
environment. Build, generated protocol coverage, packaging, external
consumption, non-auth tests, and all applicable authenticated E2E scenarios
pass.

Validation fixes are recorded in commits `38f8b5d` and `ebda3eb`.
