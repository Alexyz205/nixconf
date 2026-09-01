---
name: debug-cicd
description: CI/CD pipeline debugging - runner issues, caching, secrets, artifacts, stage failures
license: MIT
compatibility: opencode
metadata:
  audience: developers
  workflow: ci-cd
---

# Purpose

Systematic CI/CD pipeline debugging for GitLab CI and GitHub Actions.

## Triage Order

1. Which stage/job failed? Read the error.
1. Flaky or consistent? Retry once, check history.
1. What changed? Recent commits, config, deps.
1. Same locally? Reproduce in dev.

## Common Failures

### Runner Issues

- Tags must match registered runners
- Check: runner health, disk space, Docker socket

### Cache Issues (most common flaky cause)

```yaml
# GitLab
cache:
  key: "${CI_COMMIT_REF_SLUG}"
  paths: [node_modules/]
  policy: pull-push

# GitHub Actions
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
```

- Clear cache and retry first
- Pin dependency versions, commit lockfile

### Secrets/Auth

- 401/403, empty variables → check scope
- Not available in forks (PRs)
- OIDC preferred over long-lived tokens

### Docker Build Failures

- Check `.dockerignore` (missing = huge context)
- BuildKit cache: `--cache-from` / `--cache-to`
- Platform mismatch on multi-arch builds

### Artifact Issues

```yaml
artifacts:
  paths: [build/]
  expire_in: 1 hour
```

- Check `needs:` / `dependencies:` graph
- Path patterns must match actual output

### Timeout Failures

- Identify slow step via timestamps
- Common: deps install, Docker build, tests
- Fix: cache, parallelism, test sharding

## Debugging Techniques

1. `set -x` in shell steps, `--verbose` flags
1. SSH into self-hosted runners
1. Run locally: `act` (GitHub Actions), `gitlab-runner exec` (GitLab)
1. Compare with last green run
1. Check pipeline dependency graph

## When to Use

- Pipeline failure investigation
- Flaky test/build diagnosis
- Performance optimization
