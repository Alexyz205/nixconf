---
name: shell-script
description: Production shell script standards - error handling, logging, argument parsing, cleanup
license: MIT
compatibility: opencode
metadata:
  audience: developers
  workflow: automation
---

# Purpose

Production-grade shell script standards. Enforce patterns, catch anti-patterns, minimize verbosity.

## Required Patterns

```bash
#!/usr/bin/env bash
set -euo pipefail
```

- `set -e` → exit on error
- `set -u` → error on undefined vars
- `set -o pipefail` → catch pipe failures
- Trap cleanup: `trap cleanup EXIT ERR INT TERM`

## Error Handling

- Log to stderr: `echo "[ERROR] msg" >&2`
- Quote all vars: `"${var}"` not `$var`
- Trap for cleanup: `trap 'rm -f "$tmpfile"' EXIT`
- Return exit codes: 0=success, 1=error, 2=usage, 3=deps

## Arguments

- Validate required args
- Support `--help`, `--dry-run`, `--verbose`
- Use `getopts` or `case` for parsing

## Anti-patterns

- `cd dir && command` → use subshells
- Unquoted `$variables` → word splitting bugs
- `cat file | grep` → useless cat
- `eval` with user input → injection risk
- Missing error handling on critical ops

## Validation

- Run `shellcheck` — zero warnings
- Test: `bash -n script.sh`
- Cross-platform (Ubuntu, Alpine, macOS)

## When to Use

- Writing automation scripts
- Reviewing for production readiness
