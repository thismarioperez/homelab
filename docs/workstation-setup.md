# Workstation Setup

How to bring a new workstation online to work with this repo (tofu + ansible), without ever hand-copying secrets between machines.

## Prerequisites

- [mise](https://mise.jdx.dev/) installed
- A 1Password service account token with access to the `Home Network` vault

## 1. Clone and install tools

```bash
git clone <this-repo>
cd homelab
mise install
```

This installs `opentofu`, the `op` CLI, `python`/`pipx`, and `ansible` (via pipx) as pinned in `mise.toml`.

## 2. Configure 1Password auth

Copy `.env.example` to `.env` and set `OP_SERVICE_ACCOUNT_TOKEN`:

```bash
cp .env.example .env
# edit .env, set OP_SERVICE_ACCOUNT_TOKEN=ops_...
mise run op:whoami   # confirms auth works
```

## 3. Render the tofu state backend config

`tofu/{lab,testlab}/backend.hcl` holds the Postgres connection string for the shared OpenTofu state backend (see [`postgres-theforce.md`](postgres-theforce.md)). It's gitignored and never committed — instead it's rendered from 1Password on demand:

```bash
mise run tofu:testlab:backend   # renders tofu/testlab/backend.hcl
mise run tofu:lab:backend       # renders tofu/lab/backend.hcl
```

In practice you don't need to run this directly — `tofu:lab:init` and `tofu:testlab:init` depend on it and will render the file automatically:

```bash
mise run tofu:testlab:init
mise run tofu:testlab:plan
```

At this point the workstation can read/write the same tofu state as every other workstation, with no secret material stored outside 1Password.

## 4. Install ansible collections

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
```

`ansible/group_vars/all.yml` resolves `ansible_user` via the `community.general.onepassword` lookup plugin, using the same `OP_SERVICE_ACCOUNT_TOKEN` from step 2 — no separate setup needed.

## 5. Inventory

Hosts are read live from `tofu/testlab`'s state (`ansible/inventory.terraform_state.yml`, the `cloud.terraform.terraform_state` plugin) — no static inventory file to keep in sync. It renders the same `tofu/testlab/backend.hcl` from step 3, so nothing further to configure once that exists.

```bash
ansible-inventory --graph   # sanity check from ansible/
```

**Known limitation:** `ansible/inventory.terraform_state.yml` and `ansible/bin/tofu` hardcode `/home/mario/Repositories/homelab` (the plugin doesn't support Jinja templating in its config — see the comments in that file). If this repo is ever cloned to a different path or by a different user, update both files' absolute paths, and keep `ansible/bin/tofu`'s `opentofu@` version pin in sync with `mise.toml`.
