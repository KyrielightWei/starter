# Phase 03: Provider Manager Auto Detection & Status - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-25
**Phase:** 03-provider-manager-auto-detection-status
**Areas discussed:** auto-detection trigger, status indicator display, UI integration points, failure interaction model
**Mode:** auto (user requested automated discussion)

---

## Auto-Detection Trigger

| Option | Description | Selected |
|--------|-------------|----------|
| Async background check | Switch immediately, detect in parallel, notify on result | ✓ |
| Sync blocking check | Block switch until detection completes | |
| Manual only (Phase 2) | Keep manual commands only, no auto-detection | |

**User's choice:** Async background check (recommended)
**Notes:** Maintains Phase 2's non-blocking architecture, avoids user waiting during model switch

## Status Indicator Display

| Option | Description | Selected |
|--------|-------------|----------|
| Inline icons in picker list | ✓ ✗ ⏱ ⚠ prefix on each row | ✓ |
| Color-coded rows only | Background color per status | |
| Separate status column | Dedicated column with text labels | |

**User's choice:** Inline icons in picker list (recommended)
**Notes:** Reuses Phase 2 results.lua icon patterns for visual consistency

## UI Integration Points

| Option | Description | Selected |
|--------|-------------|----------|
| Both picker + model_switch (phased) | Integrate into both, picker first | ✓ |
| Picker only | Only Provider Manager panel | |
| Model switch only | Only model selection UI | |

**User's choice:** Both picker + model_switch, phased (recommended)
**Notes:** Picker is primary user entry point, model_switch is complementary

## Failure Interaction Model

| Option | Description | Selected |
|--------|-------------|----------|
| Warning + allow switch | Show warning but let user proceed | ✓ |
| Block + auto-revert | Prevent switch, revert to last-known-good | |
| Silent failure | No feedback, just switch | |

**User's choice:** Warning + allow switch (recommended)
**Notes:** User retains control, aligns with "manual command driven" design philosophy

---

## the agent's Discretion

- Module structure (new file vs extending existing)
- fzf-lua display format specifics (emoji vs highlight)
- Exact integration code paths in model_switch.lua and picker.lua

## Deferred Ideas

None — discussion stayed within phase scope
