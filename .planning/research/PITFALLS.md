# Pitfalls Research — Neovim AI Plugin Enhancement

**Domain:** LazyVim Neovim Plugin Development — Provider/Model Management & Commit Diff Review
**Researched:** 2026-04-21
**Confidence:** HIGH (based on existing codebase analysis, official documentation, and community patterns)

---

## Critical Pitfalls

### Pitfall 1: API Key File Format Breaking Change

**What goes wrong:**
When modifying `ai_keys.lua` file structure, existing user configurations become invalid or partially parsed, causing silent failures where keys are empty strings. The `Keys.read()` function uses `dofile()` which can silently return incomplete data.

**Why it happens:**
Lua's `dofile()` is fragile — if the file has syntax errors, it returns `nil` without clear error handling. The current `keys.lua` has a backward compatibility layer for old string format, but new fields (e.g., `agent_model_config`) could break parsing.

**How to avoid:**
1. Use `pcall(dofile, path)` consistently with error reporting
2. Implement schema validation after `dofile()` returns
3. Add migration function for format changes with version field in file
4. Always test with both old and new format files during development

**Warning signs:**
- `M.get_config()` returns `{ api_key = "", base_url = "" }` unexpectedly
- User reports "AI features stopped working" after config change
- `dofile()` errors are silent in test output

**Phase to address:** PMGR-01 to PMGR-04 (Provider/Model Management Panel)

---

### Pitfall 2: Async API Availability Check Blocking UI

**What goes wrong:**
Availability detection (PMGR-05 to PMGR-07) triggers HTTP requests that block the picker UI, making the interface feel frozen. Even with `plenary.async`, the FZF picker can't display status updates during checks.

**Why it happens:**
FZF-lua picker runs synchronously — the `fzf_exec` callback blocks until completion. HTTP requests from within the picker callback freeze the UI. Neovim's event loop doesn't allow updating the picker content while it's open.

**How to avoid:**
1. **Never run API checks inside picker callback** — use command-driven approach (already decided)
2. Run checks in background via `vim.loop` or separate process
3. Cache availability results with expiration (e.g., 5 minutes)
4. Display cached status in picker, offer manual refresh command

**Warning signs:**
- Picker UI frozen for >2 seconds when selecting provider
- `E5113: Error while calling lua chunk` timeout errors
- Users abandon picker thinking it crashed

**Phase to address:** PMGR-05 to PMGR-07 (Availability Detection)

---

### Pitfall 3: State Subscription Memory Leak

**What goes wrong:**
Subscribers to `State.subscribe()` are never cleaned up when the subscribing module is unloaded or picker is closed. Over time, stale callbacks accumulate, causing unexpected notifications to dead code.

**Why it happens:**
The `state.lua` module uses a simple `subscribers = {}` table with numeric IDs. When a picker registers a subscriber but doesn't call `unsubscribe()` on close, the callback persists indefinitely.

**How to avoid:**
1. **Every subscriber must unsubscribe** — use `vim.api.nvim_create_autocmd("BufWipeout")` for picker buffers
2. Return cleanup function from subscription: `local unsub = State.subscribe(fn); ...; unsub()`
3. Track subscriber source (module name) for debugging
4. Add `State.gc()` function to remove subscribers from unloaded modules

**Warning signs:**
- Subscribers table grows unbounded: `#subscribers` >> expected count
- Notifications fired when no UI is open
- Test teardown `State.clear()` needed for every test

**Phase to address:** PMGR-01, PMGR-11 (State Management in Management Panel)

---

### Pitfall 4: Diffview Buffer LSP Conflict

**What goes wrong:**
When opening Diffview for commit review, each buffer (a/b sides) triggers LSP attachment, potentially spawning multiple `ccls` or other heavy LSP servers that index the entire project, causing massive slowdown.

**Why it happens:**
Diffview creates temporary buffers with real file content. Neovim's LSP auto-attach mechanism sees these as regular buffers and starts clients. The current code (`lua/plugins/git.lua`) already has `vim.diagnostic.enable(false)` but LSP still attaches.

**How to avoid:**
1. **Set `vim.b[bufnr].lsp_enabled = false` before LSP attaches** (already done, verify timing)
2. Use `vim.api.nvim_create_autocmd("LspAttach", { buffer = bufnr })` to detach immediately
3. Consider `vim.lsp.stop_client(client_id)` for buffers matching diffview pattern
4. Document this in CDRV phase — test with heavy LSP like `ccls`

**Warning signs:**
- Diffview opens but CPU spikes to 100%
- `:LspInfo` shows multiple clients attached to diff buffers
- Buffer switch takes >500ms

**Phase to address:** CDRV-01 to CDRV-06 (Diff View Integration)

---

### Pitfall 5: Git Worktree Path Resolution Error

**What goes wrong:**
In Git worktree setups, `get_git_cmd()` incorrectly resolves `--git-dir` and `--work-tree`, causing `DiffviewOpen` to fail with "not a git repository" error. The `.git` file parsing can have trailing whitespace issues.

**Why it happens:**
The current code reads `.git` file content: `vim.fn.readfile(git_file)[1]`. This can have leading/trailing whitespace, and the regex `gitdir:%s*(.+)` captures trailing content. Some worktrees use relative paths.

**How to avoid:**
1. Trim whitespace from `.git` file content: `content:match("gitdir:%s*(%S+)")`
2. Expand relative paths: `git_dir = vim.fn.expand(git_dir)` (already done, verify)
3. Handle `.git/worktrees/...` format (Git 2.5+ worktrees)
4. Add worktree detection tests in CDRV phase

**Warning signs:**
- `DiffviewOpen` fails in worktree directory
- `:DiffviewGitInfo` shows wrong git_dir
- Error message: "fatal: not a git repository"

**Phase to address:** CDRV-01, CDRV-02 (Commit Selection in Worktree)

---

### Pitfall 6: Provider Registry Collision

**What goes wrong:**
When registering a provider with `M.register()`, the name can collide with built-in module methods (`list`, `get`, `register`), causing `Providers.list()` to return non-provider entries.

**Why it happens:**
`providers.lua` uses `M[name] = {...}` directly. If a provider is named "list" or "get", it overwrites the method. The current code checks `def.endpoint` to filter, but future providers might have different structure.

**How to avoid:**
1. **Use separate registry table** — `M._providers = {}` for storage, `M` for methods only
2. Validate provider name against reserved words
3. Add provider name prefix/suffix convention (e.g., no lowercase single words)
4. Test collision scenarios in unit tests

**Warning signs:**
- `Providers.list()` returns non-table entries
- Provider config appears in method namespace
- `Providers.get("list")` returns a method instead of nil

**Phase to address:** PMGR-02 (Adding New Provider via Panel)

---

### Pitfall 7: Multi-Provider Model List Race Condition

**What goes wrong:**
When OpenCode (PMGR-16) queries multiple providers for available models, responses arrive at different times. If the picker is closed before all responses, callbacks try to update dead UI state.

**Why it happens:**
The `Fetch.fetch()` function for multiple providers runs concurrent HTTP requests. Each callback modifies shared `models_for_display` and `id_map` tables. If picker closes mid-fetch, the callback errors.

**How to avoid:**
1. **Track picker state** — use a `picker_active` flag set to false on close
2. Check flag before modifying UI tables in fetch callback
3. Use `vim.loop.new_async()` to safely queue updates
4. Add timeout for multi-provider fetch (e.g., 15 seconds max)

**Warning signs:**
- `attempt to index nil value 'id_map'` errors
- Partial model lists shown (only first provider)
- Picker shows stale data from previous session

**Phase to address:** PMGR-16 (Multi-Provider Support for OpenCode)

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Skip subscriber cleanup in picker | Faster implementation, less code | Memory leak, stale callbacks, mysterious notifications | Never — must unsubscribe on picker close |
| Hardcode model lists in `static_models` | No API dependency, instant startup | Model drift, outdated lists, manual updates | During MVP when API unavailable; must have fallback |
| Store Agent-Model in same file as keys | User familiarity, single location | Format complexity, validation burden, migration risk | Acceptable with version field and validation |
| Use `dofile()` for config reading | Simple, fast | Silent failures, no schema validation | Only with `pcall` wrapper and error handling |
| Disable LSP for all diff buffers | Quick fix for performance | Lose diagnostics in review, can't see errors | Never — only for temporary diff buffers, not review persistence |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| **diffview.nvim** | Assume `DiffviewOpen` always succeeds | Check `dv_config._config` exists before modifying; wrap in `pcall` |
| **fzf-lua** | Update picker entries during async operation | Only modify entries between picker sessions; use `reload` action |
| **plenary.job** | Run HTTP check in picker callback | Use separate command or background job with status caching |
| **avante.nvim** | Assume config hot-reload always works | Verify `avante.setup()` was called before config change; use `State.subscribe` |
| **OpenCode** | Assume single provider endpoint | Check `Keys.get_base_url()` vs `Keys.get_base_url_claude()` for different tools |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| **N+1 API Availability Checks** | All providers checked sequentially, 10+ seconds total | Check only selected provider, cache results, parallel check with timeout | At 5+ providers without caching |
| **Diffview Large File Buffer** | Preview hangs for files >500KB | Set `previewers.builtin.limit_b`, use `cat` previewer for large files | Files >1MB with treesitter enabled |
| **Git Log for Many Commits** | `:DiffviewFileHistory` takes >5s for 100+ commits | Use `--max-count=50` default, offer range selection | At 200+ commits in history |
| **Model List Fetch Without Cache** | Every picker open triggers API calls | Cache `fetch_models` results with 5-minute expiration | When picker opened repeatedly |
| **State Subscriber Chain** | Each config change triggers N subscribers, some trigger more | Limit subscriber depth, use debounce for rapid changes | At 10+ subscribers with cascading updates |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| **API Key in Plaintext File** | Key exposed in `~/.local/state/nvim/ai_keys.lua` | Document location, suggest `chmod 600`, consider `gpg` encryption for sensitive keys |
| **Command Injection in Git Path** | `DiffviewSetGit` allows arbitrary path input | Path validation with `is_safe_path()` already exists — verify it covers all edge cases |
| **Shell Escape in Git CMD** | Unquoted paths in `io.popen` | Use `vim.fn.shellescape()` for all paths (already done in `parse_git_version`) |
| **Env Var Injection** | `${env:VAR}` could expose secrets in config display | Only show resolved values in UI, not raw env content; mask keys in status display |
| **Model ID Injection** | Provider returns malicious model ID string | Validate model IDs against expected patterns; don't execute model names |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| **Picker Frozen During Check** | User thinks plugin crashed, force-quits | Show progress indicator, use command-driven checks |
| **Empty Model List** | User confused why no models appear | Show "Loading..." placeholder, fallback to static_models with clear label |
| **Agent Config Not Applied** | User expects model switch to update agent config | Show notification: "Switched model — agent config updated" |
| **Review File Location Unclear** | User can't find `.tmp/REVIEW.md` | Show path in notification, offer `:e .tmp/REVIEW.md` command |
| **Commit Range Selection Ambiguous** | User unsure what two commits mean | Show clear labels: "From [SHA1] to [SHA2]" in diff header |
| **Backward Compat Warning Spam** | Every `_G.AI_MODEL` write shows warning | Show warning once per session, or deprecation notice only on first use |

---

## "Looks Done But Isn't" Checklist

- [ ] **Provider Management Panel:** Often missing error handling for `dofile()` — verify `pcall` wrapper exists
- [ ] **Availability Detection:** Often missing timeout handling — verify request timeout set to <10s
- [ ] **Agent Model Config:** Often missing validation for agent type — verify only known agents accepted
- [ ] **Commit Diff View:** Often missing worktree handling — test in worktree directory
- [ ] **Review Summary:** Often missing error handling for file write — verify `pcall(vim.fn.writefile)`
- [ ] **State Subscription:** Often missing unsubscribe on picker close — verify cleanup autocmd exists
- [ ] **Multi-Provider Fetch:** Often missing cancellation mechanism — verify picker close stops pending requests

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| **API Key File Corruption** | LOW | `Keys.ensure()` regenerates file; user re-enters keys |
| **Subscriber Leak** | MEDIUM | `State.clear()` removes all subscribers; restart Neovim |
| **Diffview LSP Overload** | LOW | Close diffview tab, LSP detaches automatically |
| **Git Path Invalid** | LOW | `:DiffviewSetGit` to select new path; `:DiffviewGitInfo` to check |
| **Provider Registry Collision** | HIGH | Rename provider in `providers.lua`, update all configs |
| **Config Cache Stale** | LOW | `ConfigResolver.invalidate_cache()` clears, next call rebuilds |
| **Review File Missing** | LOW | Regenerate from diff view if session still open |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| **API Key Format Breaking** | PMGR-02 (Add Provider) | Test with old and new format files |
| **Async UI Blocking** | PMGR-05 (Availability Detection) | Verify picker not frozen during check |
| **State Subscription Leak** | PMGR-01 (Management Panel) | Test picker open/close cycle, check subscriber count |
| **Diffview LSP Conflict** | CDRV-01 (Diff View Integration) | Open diffview with ccls enabled, check `:LspInfo` |
| **Git Worktree Error** | CDRV-02 (Commit Selection) | Test in worktree directory with `:DiffviewGitInfo` |
| **Provider Registry Collision** | PMGR-02 (Add Provider) | Try adding provider named "list", verify rejection |
| **Multi-Provider Race** | PMGR-16 (OpenCode Multi-Provider) | Open picker, close before all responses, check error handling |

---

## Sources

- **Existing Codebase Analysis:** `lua/ai/state.lua`, `lua/ai/providers.lua`, `lua/ai/keys.lua`, `lua/plugins/git.lua`
- **diffview.nvim Documentation:** https://github.com/sindrets/diffview.nvim — buffer lifecycle, hooks, LSP handling
- **telescope.nvim Patterns:** https://github.com/nvim-telescope/telescope.nvim — async picker limitations
- **fzf-lua Documentation:** https://github.com/ibhagwan/fzf-lua — picker state management, reload actions
- **plenary.nvim Async:** https://github.com/nvim-lua/plenary.nvim — async job patterns, channel patterns
- **Neovim Lua Development:** `:h lua-guide`, `:h develop` — best practices for plugin development
- **Community Patterns:** Neovim plugin development discussions on common state management and picker issues

---
*Pitfalls research for: LazyVim Neovim AI Plugin Enhancement*
*Researched: 2026-04-21*