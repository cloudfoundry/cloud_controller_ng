### Usage Events in V3

This section covers changes in both [app usage events](#app-usage-events) and [service usage events](#service-usage-events).

The V2 `service_guid` field for service usage events is now renamed to `service_offering.guid`.

The V2 `service_label` field for service usage events is now renamed to `service_offering.label`.

The V2 `app_guid` field for app usage events is now renamed to `process.guid`.

The V2 experimental field `parent_app_guid` for app usage events was used to identify a backing V3 app if present. In V3, this field has been renamed to `app.guid` and is no longer experimental.


