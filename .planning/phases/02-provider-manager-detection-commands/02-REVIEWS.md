---
phase: 02-provider-manager-detection-commands
reviewers: [GLM-5, Qwen3.6-Plus, Kimi-K2.5]
reviewed_at: "2026-04-24T03:15:00Z"
plans_reviewed: ["02-PLAN.md"]
---

# Cross-AI Plan Review — Phase 2: Provider Manager Detection Commands

Reviewed by **3 AI models** via OpenCode: GLM-5, Qwen3.6-Plus, Kimi-K2.5.

---

## GLM-5 Review

### Summary
The plan is well-structured with a logical task ordering that follows proper dependency flow (cache → detector → results → init). The TDD approach for core modules and explicit threat model demonstrate mature planning practices. However, there are notable gaps in error handling for edge cases (network failures, API incompatibility, partial batch failures), the io.popen pattern raises reliability concerns in Neovim's async context, and the results display lacks scalability considerations for the 12-provider registry.

### Strengths
- Clear dependency ordering: Task sequence respects module dependencies
- TDD approach for core modules (Tasks 1-2) ensures reliable implementation
- Explicit threat model covering API key exposure, DoS, cache integrity
- Reuse of existing fetch_models.lua curl/io.popen pattern
- Performance constraints addressed: max 3 concurrent + timeout + caching
- TTL-based cache with provider.timeout field
- Human verification checkpoint for manual testing

### Concerns

**HIGH:**
- **C1: io.popen is blocking** — Fundamental mismatch with "async via vim.loop" claim. Will freeze Neovim UI during batch operations.
- **C2: No error recovery for partial batch failures** — If one check times out, remaining checks may be affected. No retry mechanism.
- **C3: Missing API endpoint compatibility check** — Assumes all providers use `/v1/chat/completions`. Ollama and custom endpoints may differ.

**MEDIUM:**
- **C4: Cache invalidation incomplete** — No mechanism to invalidate cache when API key changes via Phase 1 key manager.
- **C5: Results display scalability** — 12 providers × multiple models could produce 30+ rows; no pagination/scrolling.
- **C6: No failure type distinction** — All errors lumped into single "✗" symbol.
- **C7: Progress indicator ambiguous** — "检测中: 3/12" doesn't show which providers are being tested.
- **C8: Test coverage for async unclear** — Mocking vim.loop + curl subprocess in tests needs strategy.

**LOW:**
- **C9:** JSON parsing library not specified (should use vim.json)
- **C10:** Cache file path should use `vim.fn.stdpath("state")` for cross-platform
- **C11:** No cleanup for abandoned batch checks on Neovim exit

### Suggestions
- Replace io.popen with vim.loop.spawn for true async batch checks
- Add error recovery map for partial batch failures with retry
- Validate endpoint format before sending request
- Add cache invalidation hook on key changes
- Add scrolling/filtering to results window
- Extend status symbols with failure sub-categories (auth/network/model/rate)
- Track per-provider progress by name, not just count

### Risk Assessment: **MEDIUM**
Primary risk is async architecture mismatch (io.popen blocking). With suggested fixes (vim.loop.spawn, better error handling, endpoint validation), risks are mitigatable.

---

## Qwen3.6-Plus Review

### Summary
The plan is structurally sound with clear task ordering, appropriate TDD coverage, and reasonable reuse of existing patterns. The threat model coverage is commendable, and the decision to use max_tokens=1 for detection minimizes API costs. However, there are several notable concerns: a potential keymap collision, under-specified async concurrency, and missing error state classification details.

### Strengths
- Clear dependency ordering: cache → detector → results → init
- TDD-first for cache.lua and detector.lua
- max_tokens=1 detection minimizes API costs
- Comprehensive threat model (5 threats with mitigations)
- Pattern reuse reduces integration risk
- Caching prevents redundant API calls
- Max 3 concurrent checks prevents rate limiting
- Ephemeral results window avoids state pollution

### Concerns

| # | Concern | Severity |
|---|---------|----------|
| 1 | **Keymap collision: `<leader>kc` already bound to "AI Chat"** | **HIGH** |
| 2 | **io.popen blocks Neovim event loop, contradicts async** | **HIGH** |
| 3 | **vim.loop semaphore implementation underspecified** | MEDIUM |
| 4 | **Error status definitions ambiguous** (✗ vs ⚠ distinction) | MEDIUM |
| 5 | **Cache TTL conflates request timeout with cache freshness** | MEDIUM |
| 6 | **Testing HTTP-dependent code needs mocking strategy** | MEDIUM |
| 7 | **Progressive vs final results display unclear** | LOW |
| 8 | **vim.loop → vim.uv deprecation in newer Neovim** | LOW |
| 9 | **Command argument validation gap** | LOW |

### Suggestions
1. **Change keymaps**: Use `<leader>kP` (Provider) and `<leader>kA` (All) instead of `<leader>kc`/`<leader>kC`
2. **Replace io.popen with vim.system()** (Neovim 0.10+):
   ```lua
   vim.system({ "curl", "-s", "-X", "POST", ... }, { timeout = timeout_ms }, function(obj)
     -- non-blocking callback
   end)
   ```
3. **Simple async queue pattern** instead of manual semaphore (run_next() recursive)
4. **Define error status taxonomy**:
   - `✓` — HTTP 200, valid JSON, id present
   - `✗` — 4xx/5xx, auth failure, connection refused
   - `⏱` — Request exceeded timeout
   - `⚠` — 200 but unexpected shape, or 429 rate limit
5. **Differentiated cache TTLs**: success=5min, timeout=1min, error=30s
6. **Injectable HTTP function for testability**: `M._http_fn = vim.system` so tests can mock
7. **Progressive results window**: Start empty, replace rows as callbacks fire via vim.schedule()
8. **Add command validation**: Check provider exists in Registry before checking
9. **Add `:AIClearDetectionCache`** command for manual cache refresh

### Risk Assessment: **MEDIUM**
Two HIGH items (keymap collision, io.popen blocking) are easily fixable. Remaining concerns are implementation details resolvable during TDD. Plan is viable after addressing HIGH items.

---

## Kimi-K2.5 Review

### Summary
Phase 2 implements a provider/model availability testing system with TTL-based caching, sync single checks, async batch checks (max 3), floating window UI, and user commands/keymaps. The goal is to let users manually verify which providers/models are reachable before use.

### Strengths

| Area | Strength |
|------|----------|
| Caching | TTL-based cache tied to provider timeout prevents redundant calls |
| Minimal API Call | max_tokens=1 validates full cycle with minimal cost |
| Async Control | Limiting to 3 concurrent requests prevents rate limits |
| UI Design | Floating window with symbols and 'q' to close follows Neovim conventions |
| Pattern Reuse | curl+io.popen from existing codebase maintains consistency |
| Separation | Clean split between cache, detector, results UI, integration |

### Concerns

**HIGH:**
1. **io.popen is synchronous** — Blocks Neovim main thread; UI freezes during checks
2. **vim.loop mixing with io.popen** — Async batch may not actually be async if detector uses blocking calls
3. **Cache directory may not exist** — No `vim.fn.mkdir()` shown for state dir on fresh systems

**MEDIUM:**
4. **No cache invalidation on key/config changes** — Stale "unavailable" results after fixing API key
5. **No retry logic for transient failures** — Single failure = hard failure, no backoff
6. **Progress notification may not update** — Neovim's vim.notify can coalesce messages

**LOW:**
7. **Error message exposure** — API keys might leak in error responses from some providers
8. **No partial results during batch** — Users wait for all 12 or see nothing
9. **curl dependency assumed** — No fallback check for systems without curl

### Suggestions
- Use vim.loop.spawn instead of io.popen for true async (code sample provided)
- Ensure cache directory exists with `vim.fn.mkdir(dir, "p")`
- Add cache invalidation hooks on ai_keys.lua change
- Add retry with exponential backoff (2s, 4s, 8s)
- Sanitize error messages before display (remove API keys via gsub)
- Add curl dependency check in :checkhealth or startup

### Risk Assessment

| Risk | Probability | Impact |
|------|-------------|--------|
| UI Freezing | High | High |
| Cache Directory Missing | Medium | Medium |
| Rate Limiting | Medium | Medium |
| False Negatives (no retry) | Medium | Medium |
| Key Leak in Error Logs | Low | High |
| curl Not Installed | Low | High |

**Recommendation**: Address HIGH severity concerns before execution. The io.popen blocking issue is most critical.

---

## Consensus Summary

### Agreed Concerns (2+ reviewers)

| Concern | Reviewers | Severity |
|---------|-----------|----------|
| **io.popen blocks Neovim, contradicts async requirement** | GLM, Qwen, Kimi | **HIGH** |
| **Cache invalidation missing when API key changes** | GLM, Kimi | MEDIUM |
| **Error status taxonomy needs precise definitions** | GLM, Qwen | MEDIUM |
| **Progress indicator UX insufficient for batch checks** | GLM, Kimi | MEDIUM |
| **No retry logic for transient failures** | GLM, Kimi | MEDIUM |
| **Test mocking strategy for HTTP calls needs specification** | GLM, Qwen | MEDIUM |

### Unique Critical Concerns

| Concern | Reviewer | Severity |
|---------|----------|----------|
| `<leader>kc` keymap collision with existing "AI Chat" | Qwen | **HIGH** |
| Cache directory may not exist on fresh install | Kimi | **HIGH** |
| No endpoint compatibility check (assumes /v1/chat/completions) | GLM | **HIGH** |
| API key leak in error responses | Kimi | LOW |
| curl dependency not validated | Kimi | LOW |

### Agreed Strengths (2+ reviewers)

- Clean dependency ordering (cache → detector → results → init)
- TDD approach for core modules
- max_tokens=1 minimizes API costs
- Comprehensive threat model
- Pattern reuse (curl + io.popen from fetch_models.lua)
- TTL-based caching strategy
- Max 3 concurrent to prevent rate limiting

### Overall Risk Assessment: **MEDIUM**

**Justification:**
All three reviewers agree on the fundamental issue: **io.popen is synchronous and will block Neovim's event loop**, contradicting the plan's async claim. This is the highest-priority fix. The suggested replacement is `vim.system()` (Neovim 0.10+) or `vim.loop.spawn`.

The **keymap collision** identified by Qwen is an easy fix but must be addressed to avoid breaking existing functionality.

The **cache invalidation** and **retry logic** gaps are important for user experience but don't block initial delivery.

**Recommendation:** Replan with --reviews flag to incorporate HIGH-severity fixes before execution. Estimated additional effort: 2-3 hours.
