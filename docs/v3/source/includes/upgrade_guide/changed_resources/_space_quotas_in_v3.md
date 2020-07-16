### Space Quotas in V3

In V2, `-1` represented an unlimited value for a quota limit.

In V3, `null` is used to represent an unlimited value.

The names of the limit fields have changed from V2 to V3.

|**V2**|**V3**|
|---|---|
non_basic_services_allowed | services.paid_services_allowed
total_services | services.total_service_instances
total_service_keys | services.total_service_keys
total_routes | routes.total_routes
total_reserved_route_ports | routes.total_reserved_ports
memory_limit | apps.total_memory_in_mb
instance_memory_limit | apps.per_process_memory_in_mb
app_instance_limit | apps.total_instances
app_task_limit | apps.per_app_tasks

Read more about the [space quota resource](#space-quotas).
