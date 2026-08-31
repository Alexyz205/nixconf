---

## name: docker-build description: Dockerfile best practices - multi-stage builds, layer optimization, security hardening license: MIT compatibility: opencode metadata: audience: developers workflow: containers

## Purpose

Production Dockerfile standards. Multi-stage, secure, optimized, scannable.

## Build Structure

- Multi-stage: separate build and runtime stages
- Pin base image tags/digests (never `latest` in prod)
- Order layers by change frequency (least → most)
- Combine RUN commands to reduce layers

## Security

- Non-root user: `USER <uid>:<gid>`
- Minimal base: Alpine, distroless, or scratch
- No secrets in build args → use BuildKit secrets
- Scan: `docker scout` or `trivy`
- Add `HEALTHCHECK`

## Optimization

- `.dockerignore` to exclude unnecessary files
- BuildKit cache mounts:
  ```dockerfile
  RUN --mount=type=cache,target=/var/cache/apt apt-get install -y ...
  ```
- Copy manifests before source for better caching
- Minimize size → audit with `docker history`

## Validation

- Lint with `hadolint`
- Check: version pins, `apt-get --no-install-recommends`, `COPY . .` timing

## When to Use

- Writing new Dockerfiles
- Production readiness review
- Debugging slow/large builds
- Security hardening
