5: Consist ordering of relationships, metadata, and links (V3-only)
================================

Date: 2020-01-31

Status
------

Proposed


Context
-------

Our API endpoints often return JSON, often return many of the same top-level
keys (e.g. `relationships`, `metadata`, and `links`).

We should, where possible, return common top-level keys in a consistent order
across endpoints. Specifically, we propose the following order for V3 endpoints:

1. `relationships`
2. `metadata`
3. `links`

These should always be the _last_ top-level keys presented. Note that whereas
`links` is almost universally present, `relationships` and `metadata` are not.
When `metadata` is not present, the final two top-level keys should be
`relationships` followed by `links`.

Decision
--------

To be determined.

Consequences
------------

### Positive Consequences

1. We will have a consistent ordering (admittedly more an æsthetic decision than
   a functional one) in our JSON responses.

### Negative Consequences

1. We will need to make changes to several presenters.
   - `app_presenter`
   - `domain_presenter`
   - `droplet_presenter`
   - `isolation_segment_presenter`
   - `organization_presenter`
   - `package_presenter`
   - `revision_presenter`
   - `service_broker_presenter`
   - `service_offering_presenter`
   - `service_plan_presenter`
1. We will need to update the sample JSON in our docs to reflect those changes.
1. We may accidentally break third-party tools which depend on ordering.
