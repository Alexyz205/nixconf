---
name: debug-k8s
description: Kubernetes debugging - pod crashes, OOM, networking, DNS, probe failures, resource issues
license: MIT
compatibility: opencode
metadata:
  audience: on-call-engineers
  workflow: kubernetes
---

## Purpose

Systematic K8s troubleshooting. Minimal steps, maximum signal.

## Triage Order

1. Pod status → Events → Logs → Resources → Networking

## Common Failures

### CrashLoopBackOff

```bash
kubectl describe pod <pod>
kubectl logs <pod> --previous
```

- Exit 1: app error → check logs
- Exit 137: OOMKilled → increase memory limits
- Exit 143: SIGTERM → graceful shutdown issue

### ImagePullBackOff

```bash
kubectl describe pod <pod> | grep -A5 Events
```

- Check: image exists, tag correct, registry auth, network

### OOMKilled

```bash
kubectl top pod <pod> --containers
kubectl describe pod <pod> | grep -A3 "Last State"
```

- Compare actual vs limits. Profile in staging first.

### Probe Failures

```bash
kubectl describe pod <pod> | grep -A10 "Liveness\|Readiness"
kubectl exec <pod> -- curl -s localhost:<port>/healthz
```

- Liveness = restart, Readiness = removed from service
- Check: endpoint exists, correct port, initialDelaySeconds

### Pending Pods

```bash
kubectl describe pod <pod>
kubectl describe node <node>
```

- Insufficient CPU/memory, affinity/taints, PVC not bound

### DNS Issues

```bash
kubectl exec <pod> -- nslookup <service>.<ns>.svc.cluster.local
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50
```

### Service Connectivity

```bash
kubectl get endpoints <service>
kubectl exec <pod> -- curl -v <service>:<port>
```

## Resource Diagnostics

```bash
kubectl top nodes
kubectl top pods --sort-by=memory
kubectl get events --sort-by='.lastTimestamp' | tail -20
```

## When to Use

- Pod not starting or crashing
- Service unreachable
- Performance degradation
- Post-deployment issues
