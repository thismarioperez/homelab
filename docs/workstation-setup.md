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

## 4. Configure `ansible_user` lookup (if using ansible)

`ansible/group_vars/all.yml` resolves `ansible_user` via the `community.general.onepassword` lookup plugin — this uses the same `OP_SERVICE_ACCOUNT_TOKEN` from step 2, no separate setup needed.
