# starter-pi-loop-guard

Local Pi package that detects repeated agent loops.

## What it guards

- Repeated high-risk tool calls with the same arguments.
- Repeated failed tool results with the same error fingerprint.
- Repeated assistant responses that do not add visible new information.

## Install

From the repository root:

```bash
pi install ./pi/packages/loop-guard
```

The main installer also installs it:

```bash
./scripts/install-pi-dev.sh
```

## Commands

```text
/loop-guard
/loop-guard reset
/loop-guard off
/loop-guard on
/loop-guard response-off
/loop-guard response-on
```

## Environment

```bash
PI_LOOP_GUARD=0
PI_LOOP_GUARD_RESPONSE=0
PI_LOOP_GUARD_REPEAT_LIMIT=2
PI_LOOP_GUARD_FAILURE_LIMIT=2
PI_LOOP_GUARD_RESPONSE_REPEAT_LIMIT=1
PI_LOOP_GUARD_RESPONSE_SIMILARITY=0.82
PI_LOOP_GUARD_WINDOW_MS=900000
```

For an intentional exact bash repeat, include:

```bash
# loop-guard: allow-repeat
```
