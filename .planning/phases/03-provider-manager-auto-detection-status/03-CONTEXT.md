# Phase 03: Provider Manager Auto Detection & Status - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning
**Mode:** auto (all gray areas auto-resolved)

<domain>
## Phase Boundary

Phase 03 delivers automatic availability validation when users switch their default model, and visual status indicators displayed in UI components. It builds on Phase 2's detection engine (detector.lua, cache.lua, results.lua) and Phase 1's Provider Manager picker UI.

**Scope is limited to:**
- Injecting auto-detection into the model switching flow (PMGR-07)
- Displaying cached status indicators in existing UI panels (PMGR-08)

**Out of scope:**
- New detection algorithms (Phase 2 owns this)
- Batch auto-detection of all providers on startup (explicitly excluded in PROJECT.md)
- Agent-Model configuration per task type (future phases)

</domain>

<decisions>
## Implementation Decisions

### Auto-Detection Trigger (PMGR-07)
- **D-01:** Model switching triggers **async background detection**, NOT blocking sync check. The switch takes effect immediately; detection runs in parallel.
- **D-02:** Detection result is written to the Phase 2 cache layer (ai_detection_cache.lua), reusing existing TTL logic (available=5min, timeout=1min, error=30s, unavailable=2min).
- **D-03:** On detection failure/unavailability, show warning via `vim.notify` — do NOT prevent the model switch.
- **D-04:** Integration point: `model_switch.lua` callback (after user selects provider+model) should call `Detector.check_provider_model` asynchronously before the callback confirms the switch.

### Status Indicator Display (PMGR-08)
- **D-05:** Status displayed as **inline icons** in Provider Manager picker list and model_switch picker list.
- **D-06:** Icon mapping: `available` → ✓ (green), `unavailable` → ✗ (red), `timeout` → ⏱ (yellow), `error` → ⚠ (orange), no-check → [ ] (dim/untested).
- **D-07:** Status data sourced from Phase 2 cache. If no cache entry exists, display as "未检测" (dim). Users can trigger manual re-check via `<leader>kP` or `<leader>kA`.
- **D-08:** Picker integration takes priority — implement Phase 1 picker status display first, then model_switch status display second.

### User Interaction Model
- **D-09:** Detection warning is **informational only** — user retains full control to switch to unavailable models. System does NOT auto-revert to last-known-good model.
- **D-10:** User can always manually re-trigger detection via existing Phase 2 keymaps (`<leader>kP`, `<leader>kA`) and commands (`:AICheckProvider`, `:AICheckAllProviders`).
- **D-11:** No new keymaps added for this phase — reuse existing detection commands, add status display passively.

### the agent's Discretion
- Planner decides how to structure the status-check module (new file vs extending existing picker/results)
- Planner decides on fzf-lua display format specifics (emoji vs highlight vs prefix) based on what looks best
- Planner decides exact integration code path in model_switch.lua vs picker.lua

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Provider Manager Architecture
- `lua/ai/provider_manager/detector.lua` — Async detection engine, status constants, check_provider_model API
- `lua/ai/provider_manager/cache.lua` — Cache layer with differentiated TTLs
- `lua/ai/provider_manager/results.lua` — Floating window results display (icon patterns to inherit)
- `lua/ai/provider_manager/init.lua` — Commands and keymap registrations
- `lua/ai/provider_manager/picker.lua` — Provider Manager picker UI (primary integration target)

### Model Switching
- `lua/ai/model_switch.lua` — Current model switch flow (auto-detection integration point)

### Core AI Infrastructure
- `lua/ai/providers.lua` — Provider registry with static model lists
- `lua/ai/state.lua` — Centralized state management (current provider/model)
- `lua/ai/keys.lua` — API key and base URL management

### Project Requirements
- `.planning/PROJECT.md` — PMGR-07, PMGR-08 requirements definitions
- `.planning/ROADMAP.md` — Phase 3 goal and success criteria

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Detector.check_provider_model(provider, model, callback)**: Complete async detection API — call this from model_switch callback
- **Cache.is_valid() / Cache.get()**: Read cached status for display in pickers
- **Results icon patterns**: Phase 2 already uses ✓ ✗ ⏱ ⚠ icons — reuse the same mapping and color scheme
- **Picker architecture**: Phase 1 picker uses fzf-lua with custom formatter — can add status prefix via fzf_exec entry formatter

### Established Patterns
- **vim.schedule for UI updates**: Phase 2 uses vim.schedule to avoid stack overflow in callback chains
- **State subscription pattern**: ai.state.lua provides get/set/subscribe — subscribe to model changes for auto-detection trigger
- **Injectable testability**: Phase 2 detector uses `M._http_fn` stub — new modules should follow same pattern

### Integration Points
- `model_switch.lua` line 84-88: The callback `{provider, model}` returned to caller — inject auto-detection HERE before returning
- `ai/init.lua`: Main AI setup — may need to register new autocmd for BufRead or model state change
- `provider_manager/picker.lua`: Picker formatter function — insert status prefix in display entries

</code_context>

<specifics>
## Specific Ideas

- Status display should be **passive** — users see it when they open panels, not forced upon them
- Auto-detection should happen **once per switch** — not continuously polling
- If user rapidly switches models, each switch triggers its own async check (no debouncing needed — checks are lightweight)
- Phase 2's cache TTLs are sufficient for Phase 3's needs — no new TTL values required

</specifics>

<deferred>
## Deferred Ideas

- Periodic background detection refresh (user-initiated, not on startup) — note for future Phase 3.x enhancement
- Agent-Model configuration per task type — belongs to future phases (PMGR-09 through PMGR-16)
- Status export to other tools (OpenCode config, Claude Code) — belongs to sync phase

</deferred>

---

*Phase: 03-provider-manager-auto-detection-status*
*Context gathered: 2026-04-25 (auto mode)*
