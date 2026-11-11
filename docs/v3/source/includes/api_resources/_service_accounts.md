# Service accounts (experimental)

Service accounts belong to an immutable owning organization. Apps in explicitly
entitled spaces of that org can share an account; each app has zero or one desired
account. Assignment does not grant Cloud Controller roles, cloud grants or route
permissions.

## Names and identity

An Admin allocates `service_account_prefix` on the V3 organization at creation or
once later. The prefix is foundation-unique, independent of the display name,
immutable, and reserved after org deletion. No prefix is generated automatically.
Prefixes and account names are lowercase RFC 1123 labels, 3–63 characters.

For prefix `acme-payments` and name `payments-worker`:

| Identifier | Value |
| --- | --- |
| OAuth client/subject | `cf:service-account:acme-payments:payments-worker` |
| Certificate DNS SAN | `payments-worker.acme-payments.svc.identity` |
| Route source | `cf:svc:acme-payments:payments-worker` |

Names are unique within the org, including permanent deletion reservations.
Deleting records the deletion timestamp separately from account creation/audit
retention. Historical dates remain unknown. Org Managers/Admins may explicitly
create with `reuse_name: true`: fresh UUID and initial entitlement, no restored
bindings, roles or grants. Live collisions and quotas still apply. The reused
subject/SAN may inherit external grants or accept still-valid old certificates.

## APIs and permissions

Creation uses the target space to choose the org and grant the initial entitlement:

```json
{
  "name": "payments-worker",
  "relationships": { "space": { "data": { "guid": "SPACE_GUID" } } }
}
```

Optional fields: `description`, `metadata`, `reuse_name`. Identity/state and owning
org are platform controlled. Account representations expose `organization` and
`spaces` relationships. The nullable legacy `space` relationship is retained for
transitional clients; use `organization`/`spaces` for new clients.

| Method | Path | Behavior |
| --- | --- | --- |
| POST | `/v3/service_accounts` | Space Developer/Admin creates a reserved account; requires org prefix |
| GET | `/v3/service_accounts` | Entitled-space readers and Org Managers; `names`, `space_guids`, `organization_guids` filters |
| GET | `/v3/service_accounts/:guid` | Read account; Org Managers also see zero-entitlement accounts |
| GET | `/v3/service_accounts/:guid/apps` | Read assigned apps visible to caller |
| PATCH | `/v3/service_accounts/:guid` | Metadata or async enable/disable |
| DELETE | `/v3/service_accounts/:guid` | Async unused-account cleanup |
| GET | `/v3/service_accounts/:guid/relationships/spaces` | List entitled space GUIDs |
| POST | `/v3/service_accounts/:guid/relationships/spaces` | Add `{ "data": [{ "guid": "SPACE_GUID" }] }` |
| DELETE | `/v3/service_accounts/:guid/relationships/spaces/:space_guid` | Revoke entitlement |
| GET/PATCH | `/v3/apps/:app_guid/relationships/service_account` | Read/assign `{ "data": { "guid": "ACCOUNT_GUID" } }`, clear with `null` |

Lifecycle management: Org Manager/Admin or Developer in an entitled active space.
Entitlement addition: Org Manager/Admin, or Developer of both an entitled source
space and destination. Cross-org entitlements are rejected. Developers may revoke
their space unless it is the last entitlement; Org Managers/Admins can revoke the
last. Desired assignments, active process/task snapshots and identity-bearing
service bindings block revocation. App assignment requires existing app-write
permission, same-org entitlement and allocated org prefix.

Org quota `service_accounts.total_service_accounts` is a nonnegative integer or
`null` for unlimited. It counts existing accounts including disabled/reserved;
bindings/deleted names do not consume capacity. Creation checks serialize by org.
The independent optional rolling seven-day creation budget spans the foundation
per authenticated principal; Admins are exempt. Failures do not consume budget,
and deletion does not refund it. `service_account_creation_limit: -1` is unlimited.

## Provisioning, attribution and lifecycle

First bind queues UAA provisioning and returns 202 with a pollable job; ready
account binds return 200. Wait before launching; bind/unbind never restarts apps.
Instances retain launch identity through renewal; tasks capture desired assignment;
staging has no account identity. Independent instance credentials remain intact.

The managed client is secretless, client_credentials-only, bearer policy explicitly
false for certificate binding, TTL 300, named CA bundle reference, exact SAN and
required owning-org claim. CN/OU mappings provide instance/app/space/org attribution.
Binding does not create a CAPI user. CAPI users and their explicit resource roles
are independently managed; the existing CAPI authentication flow can lazily create
a roleless OAuth user on its first API request. OAuth authorities alone do not
grant resource access. Any registration difference is a collision, not adopted/reconciled.

Disable removes the managed registration asynchronously, stopping new token
issuance when effective. Existing JWTs, certificate routes and external sessions
remain valid until their own expiry/revocation. Enable recreates the registration
and retains resource roles. Delete requires no desired/active/binding references.
Space deletion removes workloads/entitlement but retains the org account and
authentication. Org deletion cleans workloads, managed UAA clients and accounts
retryably; failed cleanup retains a deleting org. Service-account deletion does
not delete independently managed CAPI users or their roles; ordinary space/org
deletion still removes roles on the deleted resources. Names/prefixes persist.

This intentionally diverges from RFC Appendix D's automatic roleless-principal
creation on first bind: service-account provisioning and retirement manage UAA
clients, not CAPI user lifecycles. Existing users/roles can therefore apply to the
same client ID after explicit identity reuse; remove those grants independently.

## Broker and routes

App service bindings capture the assigned account; ready/entitled identity is
sent as platform `context.service_account {issuer,subject}`. Existing bindings
without an account snapshot and service keys carry no account identity. Remove
identity-bearing bindings before reassigning. Broker implementations own shared
grant lifetime/reference counting and cleanup across entitled spaces.

Qualified account route rules resolve to UUID references, are readable-source
authorized, and are removed on account deletion. Domain org/space restrictions
remain caller restrictions enforced by routing. The source relationship and
`include=source` return readable account data. Disabling tokens does not revoke
certificate-only route access.

## Rollout, migration and diagnostics

BOSH `cc.service_accounts` properties:

- `provisioning_enabled`, `runtime_enabled`: default false.
- `runtime_contract_version`: default 0; set 2 only when all BBS/rep/cells preserve
  prefix/name and issue qualified SANs. Qualified launches fail closed otherwise.
- `token_endpoint`: HTTPS UAA mTLS endpoint, no credentials/query/fragment.
- Worker-only `management_client_id`, `management_client_secret`, `identity_ca_ref`.
  Inline CA certificates are unsupported. Rotate named bundle contents in UAA.
- Worker-only optional `allowed_resources_ref`: requires UAA named-resource-policy
  support (#4125). Leave unset until supported; CAPI does not copy audience lists.

Existing POC accounts backfill org/initial entitlement without changing UUID,
name, client ID or SAN. Immutable `identity_prefix` snapshots distinguish new
qualified accounts from legacy accounts; allocating an org prefix does not rewrite
old clients. Global legacy reservations protect old unqualified subjects. Retire
legacy identities deliberately, removing external grants and allowing certificate
expiry. Existing client registrations need deliberate profile migration/retirement;
strict ownership checking does not overwrite old registration profiles.

Coordinate writers during schema migration: old writers cannot supply required org
ownership. Downgrade refuses populated org-local identities or duplicate org-local
reservations rather than losing isolation. Retain backups and pinned releases.
`ServiceAccountModel.reservation_statistics` provides counts, age buckets and unknown
historical dates for redacted operational collection; compare timestamped samples
for growth. No automatic reservation release is implemented.

Remaining external acceptance: qualified Diego/router rollout, UAA resource-policy
support, min(300s, remaining certificate lifetime) issuance, management namespace
confinement, provider audience interoperability and live upgrade/renewal/rotation.
Operator contract gates are explicit assertions, not automatic cell negotiation.

Ship qualified account-source support in routing-release before releasing the
CAPI producer changes, and pin/deploy that routing version first. Existing routers
skip unknown source types and deny when no recognized source matches; existing
recognized rules retain their OR semantics. No extra router-version setting is
required. cf-deployment's global `update.serial: false` permits parallel instance
group updates and does not guarantee router-before-CAPI completion within one
deployment. Verify the routing-first release/deployment sequence explicitly.
