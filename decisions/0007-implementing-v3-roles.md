# 7. Implementing the V3 role resource

Date: 2020-06-19

## Status

Accepted

## Context

The Cloud Controller controls permission to API resources by maintaining "roles" for each user.
For example, a user who has the "space auditor" role for a given space is granted access to read
properties of the space and resources within the space, but has fewer privileges than a "space
developer" of the same space has.

In V2, these roles were modeled as associations between a user and a space (or a user and an
organization, for org-level roles). Clients could view and modify roles with endpoints like the
following:

- `PUT /v2/organizations/:org_guid/auditors/:user_guid` (to make a user an org auditor)
- `GET /v2/spaces/:space_guid/developers` (to list users who are space developers in this space)
- `DELETE /v2/spaces/:space_guid/managers/:user_guid` (to remove a user's space manager role)
- `PUT /v2/users/:user_guid/managed_spaces/:space_guid` (to make a user a space manager)

Note that it was possible to access these associations from either direction: either by going
through the user to get their list of managed spaces, or by going through the space to get
its list of users who are space managers.

This led to a large number of endpoints that all achieved very similar things. We had separate
endpoints for each role type, and separate endpoints for orgs, spaces, and users.

In V3, we aimed to redesign this model to cut down on the number of endpoints and to simplify
usage patterns. This led us to promote the concept of "role" into its own top-level resource,
so that roles could be managed with their own, smaller set of endpoints (e.g. `POST /v3/roles`,
`GET /v3/roles`).

The basic idea of a V3 role is that it has a `type` (e.g. `space_auditor`) and a relationship to
a user and either a space (for space roles) or an org (for org roles):

```json
{
  "guid": "example-space-auditor-role-guid",
  "created_at": "timestamp",
  "updated_at": "timestamp",
  "type": "space_auditor",
  "relationships": {
    "user": { "data": { "guid": "guid-of-user-with-role" } },
    "space": { "data": { "guid": "guid-of-audited-space" } } 
  }
}
```

Since V3 uses the same underlying database as V2, and since we wanted the old V2 endpoints to still be 
usable alongside the new V3 endpoints, we had to think carefully about how to implement this new resource 
on top of the existing data. This posed several challenges.

### Challenges

The way roles were modeled in the database reflected how the V2 endpoints are structured. This meant
that there were 7 simple join tables, each representing a single role type and its associations with
a user and a space/org. For example, the `spaces__auditors` table only had two columns: `user_id` and
`space_id`.

Since V3 roles are a first-class resource, they need to have their own `guid`, `created_at`, and 
`updated_at` fields (to fit with the V3 pattern). The `guid` is especially important, since it enables
endpoints like `GET /v3/roles/:role_guid` and `DELETE /v3/roles/:role_guid`.

This raised the question of how to add these three fields to the database. Since they were new, we knew 
we would need a schema migration to add them.

All CCDB migrations are complicated by a few facts:
- User environments may have several API instances talking to the same database.
  During a rolling platform upgrade, migrations are run while the first API instance updates, but the rest of
  the API instances will still have the "old" code talking to the "new" (migrated) database. This means migrations
  must always be backwards-compatible.
- We cannot control exactly when migrations are run in user environments.

### Potential approaches

We considered several different approaches, each with their own trade-offs.

#### Create a new `roles` table in the database

This would mean migrating all data from the 7 role-specific join tables into a single table. This table would
have columns including `guid`, `type`, `user_id`, `space_id`, `organization_id`, etc.

This was appealing because the data would closely match the V3 model of roles. Accessing and listing roles would then
be straightforward in V3; they would work like most other resources.

However, this meant a potentially huge, long-running migration to fill the new table, leading to API
downtime while the migration completes. Plus, there was no clear solution for rolling upgrades: the old API 
instances would continue talking to the old tables. What happens to data that is added/removed from those
tables while the migration is occurring? When the migration finishes, could we ever drop the old tables? Or
would we have to maintain the same data in two different places indefinitely? Even if this worked, we would 
have to refactor all V2 role-related endpoints to fetch from this new table.

The risks for this seemed too high, so we moved on.

#### Create a `roles` view to union the existing tables

This would mean introducing a new SQL view that was backed by a large `UNION` query. The idea was to
make a pseudo-table that combined the existing 7 tables into one, to make it easier to work with.

We quickly realized this would only work as a read-only view; inserts into views are only supported
for a small subset of simple views, and ours would not qualify. Still, we continued to explore it, figuring
we could do inserts and deletes on the underlying tables and only use the view as a convenience
when fetching/listing roles.

We got as far as [pushing the migration](https://github.com/cloudfoundry/cloud_controller_ng/commit/30bec825d9cfb2e1780e2faa80afaf672b9cfaa8),
but quickly had to [revert it](https://github.com/cloudfoundry/cloud_controller_ng/commit/d697e9684ad9e52a7dcdbf5a414ded9d7dcfd64f) 
because it did not work on MySQL. We ran into errors like `Mysql2::Error: View's SELECT contains a subquery in the FROM clause`.

It seems like later versions of MySQL may support this, but CC attempts to be compatible with old versions of MySQL
as well, so we abandoned this approach.

#### Change V3 role usage patterns so we only hit one table at a time

This would mean changing the proposed V3 roles endpoints. Instead of `GET /v3/roles/:guid`, you would use
requests like `GET /v3/roles?user_guids=<user-guid>&space_guids=<space-guid>&types=space_auditor`. The idea
was to work around the fact that roles did not have their own unique `guid` field; instead, they would be
uniquely identified by a combination of their `type`/`user_guid`/`space_guid` (for space roles).

This might have let us get away with not changing the underlying schema at all. We could structure the endpoints
such that we usually only had to talk to one of the 7 underlying tables at a time, and for listing we would
figure something else out.

We decided against this because it introduced strange, non-standard UX patterns. We did not like the idea of
negatively impacting the UX (introducing long-lasting complexity) because we could not figure out how to resolve
the short-term complexity of doing the upgrade/migration.

## Decision

In the end, we settled on a solution that enabled the originally-proposed roles endpoints and did not involve
migrating any data to different tables. The basic gist:

- Write migrations to add `guid`/`created_at`/`updated_at` columns to the 7 underlying tables and to generate
  values to populate these columns.
- Introduce a [`Role`](https://github.com/cloudfoundry/cloud_controller_ng/blob/758ea3f877108f4eb1245511c1bbeb131a8db7c8/app/models/runtime/role.rb) 
  Sequel model backed by a union query dataset (instead of a table). This lets us
  do things like `Role.where(guid: "some-guid")` and `role.type`, even though there is no single underlying
  table.
- Write a ["just-in-time migration"](https://github.com/cloudfoundry/cloud_controller_ng/commit/758ea3f877108f4eb1245511c1bbeb131a8db7c8#diff-ac970dd55811571623bb022e1337ca08R44) 
  to fill in `guid`s for any roles that don't have them. This handles the edge case where roles are added to
  the underlying tables by other API instances while the migration is occurring. On creation, these roles would not
  have been given `guid`s, so we needed to make sure we assigned one to them.

### Lessons learned while implementing

Our [first attempt](https://github.com/cloudfoundry/cloud_controller_ng/commit/714dc93e7f058adfc2ec26dc9ad1915a540da710) 
to write these migrations used two migrations: one to add the new columns to all 7 tables, and one to fill in 
those columns in all 7 tables. This occasionally led to 
[deadlocks](https://github.com/cloudfoundry/cloud_controller_ng/issues/1363) during the migration,
so we later [further split those migrations into separate migrations](https://github.com/cloudfoundry/cloud_controller_ng/commit/acc3b6f295104ab92f345320e38ada5a7910af5d)
for each table.

Also, that first attempt added a column to each table called `guid`, following the usual pattern for our tables. Unfortunately, 
this made some existing queries fail with errors like `PG::AmbiguousColumn: ERROR:  column reference "guid" is ambiguous
LINE 1: SELECT "guid" FROM "users" INNER JOIN "spaces_developers" ON...`. These `JOIN` queries could not
tell which `guid` we were referring to (since `users` had one, and so did `spaces_developers`). We noticed this
in the unit tests locally and [tried to fix it by modifying the queries](https://github.com/cloudfoundry/cloud_controller_ng/commit/714dc93e7f058adfc2ec26dc9ad1915a540da710#diff-d3ad36b06a43420958a22dc15a34090bR57).

However, this was a more serious problem: it meant that our migrations were not
backwards-compatible, since the "old" code running on non-upgraded API instances would still briefly have the 
ambiguous queries once the migrations finished. This was caught by the pipeline job that tests specifically for 
backwards compatibility. We reverted our changes and [re-attempted them](https://github.com/cloudfoundry/cloud_controller_ng/commit/a2f9a2f4d9328f98106d050522f2232702143a27#diff-4d5978c450820709830e77453d63f408), 
this time calling the new column `role_guid` on each of the 7 tables. This resolved both problems, but it left
us with a strange inconsistency in how these columns are named. If you are ever wondering why these columns are
called `role_guid` instead of `guid`, this is why!

## Consequences

### Benefits

- We achieved the simpler usage patterns that the `/v3/roles` endpoints were designed to provide.
- We did not need to move any existing data around in migrations. We only needed to do some (relatively small)
  schema migrations to add new columns, and then data migrations to fill in those columns. This has the benefit
  of being faster for customers upgrading and of being less risky. There is still only one source of truth for 
  roles data: the 7 underlying tables that already existed.
- V2 code mostly works as-is with this approach, since the underlying data is the same.

### Risks

- Long-term, it may be confusing that we have these 7 tables representing the single concept of a role. This
  may be especially true if V2 code is ever deprecated and removed, since at that point there would be no need to keep
  the data separate. However, we don't have a clear timeline for this, and the recent Kubernetes work has raised
  more questions about the implementations of roles in CC, so we don't know enough today to solve this future problem.
- Since there were a total of 14+ migrations added to achieve this, it may add some time to users' upgrades when
  they bump to the version of CC that has V3 roles. However, this is a one-time cost, and since this work was done
  in October-December (several months before writing this), we believe many operators have already upgraded.
