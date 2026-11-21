# Administrative token network policy

Cloud Controller can restrict validated administrative bearer tokens to approved
source networks. The policy runs before downstream middleware, user creation,
and API authorization, including uploads using the relaxed token-expiry decoder.
It applies to old and new tokens and all API paths. Ordinary tokens and
unauthenticated requests retain their existing behavior.

```yaml
admin_token_network_policy:
  enabled: true
  allowed_cidrs: [192.0.2.10/32, '2001:db8:1234::/48']
  trusted_proxies: [10.0.0.10/32]
  additional_protected_scopes: [clients.write]
```

These are documentation examples, not deployment values. All four fields are
operator-controlled. The policy is disabled by default; allowed networks, trusted
proxies, and additional protected scopes default to empty lists. Enabled with an
empty allowlist means deny-all for protected tokens. Invalid numeric addresses or
CIDRs fail startup, even when disabled. Restart to apply configuration changes.

Protected scopes/authorities are `cloud_controller.admin`, `cloud_controller.admin_read_only`,
`cloud_controller.global_auditor`, `uaa.admin`, and `zones.<id>.admin` (any nonempty
zone ID). Additional scope names extend this set by exact match. Checking both
`scope` and `authorities` prevents a narrowed client-credentials scope from
bypassing protection. The list is not an exhaustive defense against escalation
through other delegation privileges; review and add those explicitly.

Allowlist/trusted-proxy entries are numeric IPv4/IPv6 hosts or CIDRs with decimal
prefix lengths. Bare addresses match a single host; CIDRs mask host bits.
Hostnames, abbreviated IPv4, dotted netmasks, ports, brackets, whitespace,
interface IDs, and mapped-IPv6 CIDR notation are invalid. IPv4-mapped IPv6
requests match IPv4 networks. No DNS resolution is performed.

## Source-address contract

- TCP requests use the actual Puma socket peer (or `REMOTE_ADDR` on other Rack
  servers). Real-IP and forwarded headers from untrusted peers are ignored,
  including on loopback TCP.
- Nginx may assert `X-Real-IP` only when the actual Puma socket is Unix-domain and
  its local path matches `nginx.instance_socket` with `nginx.use_nginx` enabled.
  The BOSH Nginx templates overwrite `X-Real-IP` with `$remote_addr` on public and
  internal proxy paths, including upload forwarding, and strip `X-Real_IP` to
  prevent a Rack-normalization collision. Deploy the matching Nginx template
  changes before enabling the policy. The socket and its parents must be protected
  against untrusted local access. Loopback does not prove this transport.
- Only explicitly listed `trusted_proxies` can forward source addresses. Walk
  `X-Forwarded-For` from right to left until the first untrusted numeric address,
  which is the source. Nginx's `$proxy_add_x_forwarded_for` appends its immediate
  peer. Ignore attacker-controlled prefixes beyond the first untrusted hop;
  malformed encountered hops, missing addresses, more than 64 entries, and
  chains with no untrusted source fail closed.

List actual router/proxy addresses, **not client networks**, in `trusted_proxies`.
Never broadly trust all private addresses just because your Gorouters have private
IPs. Every ingress hop must sanitize or append forwarded headers correctly, and
direct backend access must be protected. Other Rack servers must ensure
`REMOTE_ADDR` remains an authoritative peer address.

## Denial and coordinated rollout

Denials return HTTP 403 using the existing `CF-NotAuthorized` v2/v3 error format,
clear the validated security context, and do not invoke downstream user creation
or API handling. The fixed denial log message includes no credentials or tokens.

Use matching allowed networks and protected additions in UAA's
`uaa.admin_token_network_policy` to restrict issuance, refresh, and UAA usage.
In capi-release, the properties have the `cc.admin_token_network_policy` prefix
with `enabled`, `allowed_cidrs`, `trusted_proxies`, and
`additional_protected_scopes` suffixes. Release wiring requires application
versions that implement these settings; old binaries do not gain protection
by rendering configuration. Other offline JWT consumers need their own policy.

Before enabling, inventory administrator VPN/NAT egress and internal automation,
test public/internal ingress and forged headers, and verify issuance on an allowed
network followed by use/refresh on a denied network. Keep a tested operator
configuration rollback procedure.
