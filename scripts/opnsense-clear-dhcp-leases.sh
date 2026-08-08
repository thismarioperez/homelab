#!/usr/bin/env bash
# Clears stale Kea DHCPv4 leases in OPNsense for the given IPs.
#
# Kea doesn't release a MAC's lease just because its
# opnsense_kea_dhcpv4_reservation was destroyed (see the comment on that
# resource in tofu/testlab/main.tf), so a tofu destroy + re-apply cycle can
# hand a rebuilt VM a stale leased address instead of its reserved one.
#
# The lease-delete endpoint (/api/kea/leases4/del_lease/{ip}) enforces CSRF
# protection even against correctly-authenticated API-key Basic auth (see
# the same main.tf comment for the abandoned local-exec attempt that
# confirmed this by hand). The only workaround found is to emulate a real
# GUI session: log into the web UI form to get a session cookie + CSRF
# token, then use both on the delete request.
#
# Usage: opnsense-clear-dhcp-leases.sh <ip> [ip...]
# Requires OPNSENSE_URL, OPNSENSE_USERNAME, OPNSENSE_PASSWORD in the
# environment. Never fails the caller for a missing/already-gone lease —
# only for a login/session failure or if every delete attempt errors out.

set -u

if [ "$#" -eq 0 ]; then
  echo "usage: $0 <ip> [ip...]" >&2
  exit 1
fi

: "${OPNSENSE_URL:?OPNSENSE_URL must be set}"
: "${OPNSENSE_USERNAME:?OPNSENSE_USERNAME must be set}"
: "${OPNSENSE_PASSWORD:?OPNSENSE_PASSWORD must be set}"

# The GUI (and its CSRF-protected endpoints) is only ever served over TLS —
# plain http:// just 301s to https:// with an empty body, so there's no
# login form to scrape. var.opnsense_endpoint (the source of OPNSENSE_URL)
# is http:// because that's what the REST API's Basic-auth calls use
# elsewhere in this repo; normalize to https:// here regardless of what was
# passed in.
OPNSENSE_URL="https://${OPNSENSE_URL#*://}"

COOKIE_JAR=$(mktemp)
trap 'rm -f "$COOKIE_JAR"' EXIT

curl_insecure_flag=""
if [ "${OPNSENSE_ALLOW_INSECURE:-false}" = "true" ]; then
  curl_insecure_flag="-k"
fi

# The unauthenticated login form embeds its CSRF token as a hidden <input>
# whose *name* attribute is itself the randomized token ID and whose value
# is the token, e.g. <input type="hidden" name="3y6xZx1aw6M6n-fA1JDuoQ"
# value="LlDFC-XJPJBHx-vdc6fHVQ">. Both change per request, so this is
# re-scraped fresh right before the login POST.
fetch_login_csrf_field() {
  local page_url="$1"
  curl -sS $curl_insecure_flag -b "$COOKIE_JAR" -c "$COOKIE_JAR" "$page_url" \
    | grep -o '<input type="hidden" name="[^"]*" value="[^"]*"' \
    | head -n1
}

# Once authenticated, GET / redirects (302) into the app, and authenticated
# pages carry their CSRF token differently — inlined in a $.ajaxSetup script
# as the X-CSRFToken header value (no hidden-input form on those pages) —
# so this needs -L to follow the redirect and a different scrape pattern.
# Re-scraped before every delete since OPNsense rotates the token per
# request.
fetch_authed_csrf_token() {
  curl -sS -L $curl_insecure_flag -b "$COOKIE_JAR" -c "$COOKIE_JAR" "${OPNSENSE_URL}/" \
    | grep -o 'X-CSRFToken", "[^"]*"' \
    | sed -E 's/^X-CSRFToken", "([^"]*)"$/\1/' \
    | head -n1
}

echo "Logging into OPNsense at ${OPNSENSE_URL} as ${OPNSENSE_USERNAME}..." >&2

login_field=$(fetch_login_csrf_field "${OPNSENSE_URL}/")
if [ -z "$login_field" ]; then
  echo "ERROR: could not find CSRF token field on OPNsense login page — aborting" >&2
  exit 1
fi
login_field_name=$(echo "$login_field" | sed -E 's/.*name="([^"]*)".*/\1/')
login_field_value=$(echo "$login_field" | sed -E 's/.*value="([^"]*)".*/\1/')

login_status=$(curl -sS $curl_insecure_flag -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  -o /tmp/opnsense-login-response.$$ -w '%{http_code}' \
  --data-urlencode "usernamefld=${OPNSENSE_USERNAME}" \
  --data-urlencode "passwordfld=${OPNSENSE_PASSWORD}" \
  --data-urlencode "${login_field_name}=${login_field_value}" \
  --data-urlencode "login=1" \
  "${OPNSENSE_URL}/")

# OPNsense's login form returns 302 (redirect to dashboard) on a successful
# login, and 200 (re-rendering the same login page, with an error message)
# on failure — so 200 is the failure case here, not success.
if [ "$login_status" = "200" ] || grep -qi "Wrong username or password" /tmp/opnsense-login-response.$$; then
  echo "ERROR: OPNsense login failed (HTTP ${login_status}) — aborting" >&2
  rm -f /tmp/opnsense-login-response.$$
  exit 1
fi
rm -f /tmp/opnsense-login-response.$$

fail_count=0
ok_count=0

for ip in "$@"; do
  delete_token=$(fetch_authed_csrf_token)
  if [ -z "$delete_token" ]; then
    echo "WARN: ${ip}: could not refresh CSRF token, skipping" >&2
    fail_count=$((fail_count + 1))
    continue
  fi

  response=$(curl -sS $curl_insecure_flag -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
    -w '\n%{http_code}' \
    -H "X-CSRFToken: ${delete_token}" \
    -X POST \
    "${OPNSENSE_URL}/api/kea/leases4/del_lease/${ip}")

  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')

  # Success: {"status":"ok"}, HTTP 200.
  # No lease exists for that IP (nothing to do — not an error, this is the
  # expected steady-state case): HTTP 500 with
  # {"errorMessage":"Failed to delete lease(s): <ip>: IPv4 lease not
  # found.",...}. Any other response is a real failure.
  if [ "$http_code" = "200" ] && echo "$body" | grep -q '"status"[[:space:]]*:[[:space:]]*"ok"'; then
    echo "OK: ${ip}: lease deleted" >&2
    ok_count=$((ok_count + 1))
  elif echo "$body" | grep -qi "IPv4 lease not found"; then
    echo "OK: ${ip}: no lease found (already clear)" >&2
    ok_count=$((ok_count + 1))
  else
    echo "WARN: ${ip}: lease delete failed (HTTP ${http_code}): ${body}" >&2
    fail_count=$((fail_count + 1))
  fi
done

echo "Done: ${ok_count} ok, ${fail_count} failed" >&2

if [ "$ok_count" -eq 0 ] && [ "$fail_count" -gt 0 ]; then
  echo "ERROR: every lease delete attempt failed" >&2
  exit 1
fi

exit 0
