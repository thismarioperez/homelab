# Backblaze B2 OpenTofu State Backend

OpenTofu state for `tofu/lab` and `tofu/testlab` is stored in a single
Backblaze B2 bucket, accessed through B2's S3-compatible API.

**Note on locking:** OpenTofu 1.10+'s native S3 state locking
(`use_lockfile`, conditional `PutObject` writes) does not work against B2 —
B2 returns HTTP 501 for the `If-None-Match` header the lock relies on. State
locking is therefore not enabled. This is acceptable for a solo,
one-workstation-at-a-time workflow; if concurrent applies ever become a real
risk, revisit the backend choice.

## Bucket layout

- **Bucket:** `storage-homelab-theforce` (private)
- **Endpoint:** `s3.us-west-002.backblazeb2.com` (region `us-west-002`)
- **State objects**, one per environment, in separate top-level folders of
  the same bucket:
  - `tofu-state-lab/terraform.tfstate`
  - `tofu-state-testlab/terraform.tfstate`

## Application key

A single bucket-scoped application key covers both environments (read/write
only to `storage-homelab-theforce`, not the B2 account's other buckets).

To recreate it: **B2 Cloud Storage → Application Keys → Add a New
Application Key**

- Allow access to: this bucket only
- Capabilities: **Read and Write**
- Also explicitly enable **`listAllBucketNames`** — required for
  S3-compatible SDK calls to work correctly even with a bucket-restricted
  key; without it, OpenTofu's S3 backend client fails during init.

The `applicationKey` value is shown only once at creation — copy it
immediately into 1Password.

## Credential storage

Stored in the `Home Network` 1Password vault as item
**`Backblaze - Application Key - tofu-state`**, with fields:

| Field            | Maps to (S3 backend)                                     |
| ---------------- | -------------------------------------------------------- |
| `keyID`          | `access_key`                                             |
| `keyName`        | (not used by tofu — just the key's human-readable label) |
| `applicationKey` | `secret_key`                                             |

`tofu/{lab,testlab}/backend.hcl.tpl` reference `keyID`/`applicationKey` via
`op://` paths, rendered into a gitignored `backend.hcl` — see
[`workstation-setup.md`](workstation-setup.md).
