---
name: incident-response
description: Structured incident triage - assess severity, mitigate, communicate, and run RCA
license: MIT
compatibility: opencode
metadata:
  audience: on-call-engineers
  workflow: operations
---

## Purpose

Structured incident handling: detection → mitigation → RCA → post-mortem.

## Triage Framework

### 1. Assess

- Impact? (service down, degraded, data loss)
- Scope? (all users, subset, internal)
- Started when? (correlate with deployments/changes)
- Severity: SEV1 (total outage) → SEV4 (minor)

### 2. Mitigate

- Rollback if timing correlates
- Scale up / failover for capacity
- Feature flag toggle for feature-specific
- **Goal: restore service first, RCA later**

### 3. Communicate

- Notify stakeholders: impact, ETA, who's working
- Update status page if public
- Keep action timeline

### 4. RCA

- Gather: logs, metrics, traces, deploy history
- 5 Whys or fault tree analysis
- Identify contributing factors (not just trigger)
- Document: timeline, root cause, mitigation, action items

### 5. Follow-up

- Action items with owners and deadlines
- Classify: prevent recurrence, improve detection, improve response
- Share post-mortem (blameless)

## Diagnostic Commands

```bash
kubectl rollout history deployment/<name>
git log --oneline --since="2 hours ago"
kubectl get pods -o wide | grep -v Running
kubectl top pods --sort-by=memory
kubectl logs -l app=<name> --since=1h --tail=500
journalctl -u <service> --since "1 hour ago"
```

## When to Use

- Active incident or outage
- Post-incident review / post-mortem
- Preparing on-call runbooks
