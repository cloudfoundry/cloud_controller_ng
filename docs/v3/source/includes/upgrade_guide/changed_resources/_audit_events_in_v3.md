### Audit Events in V3

In V2, these were called "events" (e.g. `/v2/events`). In V3, we adopt the term
"audit events" to better distinguish them from usage events.

V2 audit events contained information about the "actee" (the resource that the
event affected). V3 audit events refer to the affected resource as the "target".

V2 audit events had a `timestamp` field. In V3, this field has been renamed to
`created_at` for consistency with other resources. The value is the same.

In general, V3 audit events contain all of the same information that they
contained in V2, but the JSON is structured a little differently. In particular:

- The `metadata` field has been renamed to `data`.
- Actor-related fields have been grouped into an object under the `actor` key
  (e.g. `actor.type` instead of `actor_type`).
- Actee-related fields have been grouped under the `target` key (e.g.
  `target.type` instead of `actee_type`).

At the time of this writing, V3 does not support greater-than or less-than
filtering for the `created_at` field. In V2, this was supported via
`/v2/events?q=timestamp>some_timestamp`. There are plans support this in the
future.

V3 endpoints attempt to report audit events in the same way as V2 endpoints did.
A notable case where this was not possible is for the `audit.app.restage` event.
Read more about [restaging](#restage) in V3.

Read more about the [audit event resource](#audit-events).
