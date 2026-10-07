# Service accounts (experimental)

Service accounts are immutable, space-owned identities shared by apps in that
space. Each app has zero or one desired account. Names are foundation-unique
lowercase DNS labels of 3–63 characters and remain reserved after deletion.
Cross-space assignment is forbidden, including within the same organization.

## Resource and permissions

Account representations include `guid`, `name`, `description`, `metadata`,
`enabled`, `status`, `client_id`, `certificate_dns_san`, timestamps and the owning
`relationships.space`. Identity fields and owning space cannot be updated.
The client ID is `cf:service-account:<name>` and DNS SAN is `<name>.svc.identity`.

Owning-space readers can show/list accounts and their apps. Space managers and
platform administrators manage accounts in writable spaces. App writers may assign
an enabled same-space account. Account management does not grant app-write access.
Account assignment does not grant any resource roles to the account principal.

| Method | Path | Behavior |
| --- | --- | --- |
| POST | `/v3/service_accounts` | Reserve an account; returns 201, initially `reserved` |
| GET | `/v3/service_accounts` | Paginated readable accounts; `names`, `space_guids`, standard pagination/order parameters |
| GET | `/v3/service_accounts/:guid` | Show readable account |
| GET | `/v3/service_accounts/:guid/apps` | Paginated apps with desired assignment |
| PATCH | `/v3/service_accounts/:guid` | Update description/metadata (200) or enabled state (202) |
| DELETE | `/v3/service_accounts/:guid` | Queue unused-account deletion; returns 202 |
| GET | `/v3/apps/:guid/relationships/service_account` | Desired relationship `{ "data": null }` or account GUID |
| PATCH | `/v3/apps/:guid/relationships/service_account` | Assign GUID or explicitly unbind with `{ "data": null }` |

Minimal creation body (permitted roles: owning-space manager or platform admin):

```json
{
  "name": "payments-worker",
  "relationships": { "space": { "data": { "guid": "SPACE_GUID" } } }
}
```

Optional creation fields are `description` and standard `metadata.labels` and
`metadata.annotations`. Metadata updates use the normal merge/removal semantics.

Operators can set `service_account_creation_limit` in API configuration to a
nonnegative maximum successful creations per authenticated principal over a rolling
seven-day window. Omitted or `-1` means unlimited; `0` disables non-admin creation.
The budget spans all spaces and includes automation clients, but platform admins
and admin automation are exempt. Exhaustion returns 429
`CF-ServiceAccountCreationLimitExceeded`. Failed creation consumes nothing;
deletion does not refund the budget. Accounting is independent of account deletion
and audit-event retention, and concurrent requests share one atomic budget.

Example account object:

```json
{
  "guid": "ACCOUNT_GUID",
  "name": "payments-worker",
  "description": "",
  "enabled": true,
  "status": "reserved",
  "client_id": "cf:service-account:payments-worker",
  "certificate_dns_san": "payments-worker.svc.identity",
  "created_at": "2026-10-05T12:00:00Z",
  "updated_at": "2026-10-05T12:00:00Z",
  "metadata": { "labels": {}, "annotations": {} },
  "relationships": { "space": { "data": { "guid": "SPACE_GUID" } } },
  "links": {
    "self": { "href": "https://api.example.org/v3/service_accounts/ACCOUNT_GUID" }
  }
}
```

Permitted roles for GET endpoints are owning-space readers and global readers.
PATCH/DELETE account endpoints require an owning-space manager or platform admin;
PATCH app relationship requires app-write permission in the owning space.

Assign an account with `{ "data": { "guid": "ACCOUNT_GUID" } }` on the app
relationship endpoint. Clear it with `{ "data": null }`. PATCH an account with
`{ "enabled": false }` or `{ "enabled": true }` to disable or enable authentication.

## Provisioning and lifecycle

First authorized bind is asynchronous when operator provisioning is enabled.
It persists the desired assignment, marks the account `reconciling`, and returns
202 with a `/v3/jobs/:guid` Location. Poll until completion before starting or
restarting the app. Concurrent binds share the active provisioning job. A ready
account bind returns 200. Replacing an account requires explicit unbind first.
Bind/unbind return restart guidance and never restart the app automatically.

Provisioning registers one canonical certificate-authenticated, secretless UAA
client and creates a roleless OAuth principal with GUID equal to the client ID.
Client collisions are rejected rather than overwritten/adopted. Transient worker
failures expose `failed` state and retry up to three attempts. A later authorized
bind can retry after the previous job has terminated. Unbind while provisioning
does not cause the worker to restore an assignment.

Use `/v3/roles` with `relationships.user.data.guid` equal to the canonical client
ID. Explicit organization membership is required before granting space roles.
Roles belong to the shared account principal and are retained with zero apps or
while authentication is disabled. An account token cannot identify which app used it.

PATCH `enabled: false` immediately prevents new assignment/launch identity and
queues UAA registration deletion. Enabling recreates the canonical registration
and preserves resource roles. The local UAA lifecycle strategy uses client deletion
because the selected UAA model has no enabled-client property. This must be verified
against the deployed UAA configuration before claiming token-issuance denial.

Deleting requires no desired app assignments, started process snapshots or active
task snapshots. The worker rechecks usage and registration trust before removing
the client, principal and account. The name reservation is retained permanently.
Concurrent lifecycle operations return 409. All asynchronous operations use the
standard job polling endpoint.
Space/org deletion cascades owned accounts: service bindings and workloads are
deleted before managed clients, principals/roles and accounts; name reservations
remain. Active account operations and cleanup failures prevent final parent
deletion and are reported by the deletion job. Retry the parent deletion after
resolving the failure; completed cleanup is not rolled back.

## Runtime and rollout

Runtime identity is enabled separately from provisioning. New process launches and
tasks capture the account at launch/creation. Later bind/unbind changes require
restart; scaling/redriving retains the captured identity. Pre-feature launches have
no account identity until explicit launch/restart. Staging excludes account identity
and discovery. Non-ready, disabled, missing or wrong-space accounts fail closed.

Runtime `VCAP_SERVICE_ACCOUNT` contains account GUID/name, canonical client ID/SAN
and the configured HTTPS mTLS token endpoint, without secrets. Workloads use their
existing instance credentials; platform-derived typed certificate properties
preserve app/space/org organizational units. Account SANs are not route names.

BOSH properties under `cc.service_accounts`:

- `provisioning_enabled` (default false): enable API lifecycle/first-bind enqueueing
  and dedicated worker provisioning configuration.
- `runtime_enabled` (default false): enable account identity only after compatible
  BBS, rep and cell versions are present throughout the foundation.
- `token_endpoint`: HTTPS UAA mTLS endpoint without credentials/query/fragment.
- Worker-only `management_client_id`, `management_client_secret`, `identity_ca`:
  dedicated UAA management credentials and the instance identity CA PEM, separate
  from the UAA server TLS CA. Configure namespace protection independently in UAA.

App-hosted local workers may receive equivalent `service_account_provisioning`
configuration separately; the API BOSH template does not render management secrets.
UAA audience/issuer, protected namespace, trusted proxy profile, leaf-expiry token
lifetime cap and the selected UAA `cnf` claim deviation require integration evidence.
Disabling/deleting clients, unbinding and restarting do not revoke already-issued
JWTs or certificates immediately. Certificate-only route grants are separate.
