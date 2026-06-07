# Pi Dev Statusbar Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Build a stable lightweight redesign of the Pi dev statusbar that merges the current global ChatGPT quota support with the template's cleaner runtime display, while adding quota caching, adaptive line layout, and clearer rendering boundaries.

**Architecture:** Keep the statusbar as a single TypeScript extension template for now, but split behavior into small pure helpers for formatting, quota caching, speed coloring, and line rendering. The project template becomes the canonical recommended version, and the global user extension is synchronized from it after verification.

**Tech Stack:** TypeScript Pi extension API (`@earendil-works/pi-coding-agent`), Pi TUI theme helpers, Node built-ins (`path`, `fs`), native `fetch`.

---

## Files

- Modify: `pi/extensions/statusbar.template.ts`
  - Canonical statusbar implementation used by this repo's Pi template.
  - Adds ChatGPT quota support, TTL cache, in-flight guard, adaptive rendering, and helper extraction.
- Modify: `/root/.pi/agent/extensions/statusbar.ts`
  - Global active statusbar extension synchronized from the project template.
- Create: `docs/superpowers/plans/2026-06-06-pi-statusbar-redesign.md`
  - This implementation plan.

## Constraints

- Do not touch unrelated existing git changes: deleted OpenSpec project skills and `shell_config/tmux.conf` are pre-existing/user changes.
- Do not introduce external dependencies.
- Do not implement a TUI config editor in this pass.
- Keep comments concise and in Chinese where new explanatory code comments are useful.
- Preserve existing command `/statusbar` behavior.

---

### Task 1: Replace project template with canonical redesigned statusbar

**Files:**
- Modify: `pi/extensions/statusbar.template.ts`

- [x] **Step 1: Rewrite the template around small helpers**

Replace the current template with a canonical implementation containing these sections:

```ts
const DEFAULT_CONFIG = {
  maxLines: 4,
  quotaCacheTtlMs: 5 * 60 * 1000,
  showChatGptQuota: true,
  adaptive: true,
};
```

Implement helpers:

```ts
fmt()
loadModelCosts()
calculateCost()
isOpenAICodexProvider()
asRecord()
normalizeWindow()
parseChatGptSnapshot()
formatPercent()
formatReset()
chatGptColor()
isQuotaFresh()
shouldFetchQuota()
requestChatGptUsage()
queueChatGptUsageUpdate()
speedColor()
contextColor()
buildRenderData()
renderPrimaryLine()
renderSessionLine()
renderContextLine()
renderCompactLines()
renderNormalLines()
renderDetailedLines()
renderLines()
```

- [x] **Step 2: Add ChatGPT quota cache behavior**

Use cache state:

```ts
type ChatGptCache = {
  snapshot?: ChatGptSnapshot;
  status: string;
  fetchedAt: number;
  inFlight: boolean;
  provider?: string;
};
```

Rules:
- `session_start`: fetch only when no fresh cache exists.
- `model_select`: force fetch.
- `turn_end`: fetch only when cache is stale.
- if provider is not `openai-codex` or `openai-codex-N`, clear quota display.
- if request fails but old snapshot exists, keep snapshot and show stale error status.
- avoid duplicate requests while `inFlight` is true.

- [x] **Step 3: Add adaptive rendering**

Render modes:
- `w < 70`: compact, one line.
- `70 <= w < 120`: normal, two lines without quota to keep the statusbar compact.
- `w >= 120`: detailed, up to four lines.

Every returned line must be passed through `truncateToWidth(line, w)`.

- [x] **Step 4: Fix turn speed accounting**

On `turn_start`, capture current context tokens:

```ts
const usage = ctx.getContextUsage?.();
turnStartTokens = usage?.tokens || 0;
```

During render, calculate a non-negative speed:

```ts
const delta = Math.max(0, curTok - turnStartTokens);
turnSpeed = turnElapsed > 0.5 ? Math.round(delta / turnElapsed) : turnSpeed;
```

- [x] **Step 5: Implement balanced speed colors**

Rules:
- idle: dim.
- running + speed `< 100`: warning.
- running + speed `100..3000`: success.
- running + speed `3000..8000`: accent.
- running + speed `> 8000`: error.

---

### Task 2: Synchronize active global extension

**Files:**
- Modify: `/root/.pi/agent/extensions/statusbar.ts`

- [x] **Step 1: Copy canonical template to active global extension**

Run:

```bash
cp pi/extensions/statusbar.template.ts /root/.pi/agent/extensions/statusbar.ts
```

- [x] **Step 2: Verify both files are identical**

Run:

```bash
diff -u pi/extensions/statusbar.template.ts /root/.pi/agent/extensions/statusbar.ts
```

Expected: no output.

---

### Task 3: Verify implementation

**Files:**
- Check: `pi/extensions/statusbar.template.ts`
- Check: `/root/.pi/agent/extensions/statusbar.ts`

- [x] **Step 1: TypeScript syntax smoke check**

Run:

```bash
npx --yes tsc --target ES2022 --module NodeNext --moduleResolution NodeNext --noEmit --skipLibCheck --types node pi/extensions/statusbar.template.ts
```

Expected: no syntax/type errors from the file itself. If package type declarations are unavailable in this environment, record the exact error and run a fallback syntax check.

- [x] **Step 2: Fallback syntax check if needed**

Run:

```bash
node - <<'NODE'
const fs = require('fs');
const path = 'pi/extensions/statusbar.template.ts';
const text = fs.readFileSync(path, 'utf8');
for (const needle of [
  'DEFAULT_CONFIG',
  'queueChatGptUsageUpdate',
  'renderCompactLines',
  'renderNormalLines',
  'renderDetailedLines',
  'turnStartTokens = usage?.tokens || 0'
]) {
  if (!text.includes(needle)) throw new Error('missing ' + needle);
}
console.log('statusbar template structure ok');
NODE
```

Expected: `statusbar template structure ok`.

- [x] **Step 3: Confirm only intended files changed**

Run:

```bash
git status --short
```

Expected includes:
- `M pi/extensions/statusbar.template.ts`
- `?? docs/superpowers/plans/2026-06-06-pi-statusbar-redesign.md`

Existing unrelated changes may remain, but must not be staged or modified further.

---

## Self-review

- Spec coverage: The plan covers quota caching, active/template sync, adaptive display, speed logic, and verification.
- Placeholder scan: No TODO/TBD placeholders remain.
- Type consistency: Helper names and state types match the implementation target.
