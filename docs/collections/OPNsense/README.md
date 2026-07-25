# OPNsense Bruno Collection

Bruno collection for calling the OPNsense router's REST API.

## Setup

1. Open this folder (`docs/collections/OPNsense/`) as a collection in the
   [Bruno](https://www.usebruno.com/) app.
2. In Bruno, select the **default** environment from the environment dropdown
   (top right). It's the only environment defined, so this is a one-time pick
   per collection open — every request inherits its `api_url`/auth from there.
3. Open the **default** environment's settings and fill in the `api_key` and
   `api_secret` secret variables directly in the Bruno UI. Generate a
   key/secret pair in the OPNsense UI under **System → Access → Users →
   (your user) → API keys**.
4. Run any request — `core/system/status` is a good first check that the API
   is reachable.

`api_key`/`api_secret` are marked as secret variables, so Bruno stores them
in its local, encrypted secret store rather than writing them into
`environments/default.yml`. Credentials never end up in version control.

## Config notes

- `environments/default.yml` sets `api_url` to the router's LAN IP. Update it
  there if the router's address changes.
- `api_key`/`api_secret` in that same environment are defined with
  `secret: true` and an empty value, so Bruno prompts for them in the UI and
  keeps them in its local secret storage instead of the tracked `.yml` file.

## Layout

Requests are organized by OPNsense API module and controller, mirroring the
`/api/<module>/<controller>/<action>` URL structure:

- `core/system/` — core system status/info calls.
- `kea/dhcpv4/` — Kea DHCPv4 controller (subnets, reservations, options, HA peers).
- `kea/service/` — Kea service controller (status, reconfigure).
