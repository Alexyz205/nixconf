---
name: ansible
description: Ansible standards - idempotent playbooks, roles, dynamic inventory, Vault secrets, Molecule testing
license: MIT
compatibility: opencode
metadata:
  audience: developers
  workflow: config-management
---

## Purpose

Production config-management standards. Idempotent, modular, testable playbooks.

## Idempotency

- Prefer modules over raw `command`/`shell` (use `creates`/`removes` when you must)
- Declare desired state, not imperative steps
- Use `state: present/absent`, not `touch`/`rm`
- Handlers for restarts (fired once, at end of play)

## Structure

```
roles/<name>/
  defaults/main.yml    # lowest precedence
  vars/main.yml
  tasks/main.yml
  handlers/main.yml
  templates/
  files/
  meta/main.yml
```

- One role per concern; keep roles small and reusable
- `tags` for selective runs; `become` only where needed
- Pin role versions in `requirements.yml`

## Secrets

- `ansible-vault` for secrets; never commit plaintext
- Reference with `{{ vault_secret }}`; `no_log: true` on sensitive tasks
- Avoid `debug` printing credentials

## Validation & Testing

```bash
ansible-playbook site.yml --syntax-check
ansible-playbook site.yml --check --diff   # dry-run
ansible-lint .
molecule test                              # role tests
```

- `molecule` roles: converge, idempotence (run twice = no changes), verify
- `ansible-lint` zero errors
- Check mode + diff before real run

## Dynamic Inventory

- Cloud/CMDB dynamic inventory over static hosts files
- Group hosts semantically (`web`, `db`, `workers`) for group_vars/host_vars

## When to Use

- Writing/refactoring playbooks or roles
- Reviewing for idempotency and security
- Setting up Molecule tests or dynamic inventory
