### Service Plan Visibility in V3

`v2/service_plan_visibilities` has been replaced in v3 with a nested resource `v3/service_plans/:guid/visibility`

This new resource has a `type`, and can have a list of `organizations` a `space` or be of type `public`

Read more about the [service plan visibility resource](#service-plan-visibility).
