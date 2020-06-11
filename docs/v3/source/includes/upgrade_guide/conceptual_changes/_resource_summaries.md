### Resource Summaries

V2 provided several endpoints that returned rolled-up summaries (e.g.
`/v2/spaces/:guid/summary` for a space summary, or
`/v2/organizations/:guid/summary` for an organization summary). These endpoints
have been largely removed from V3 because they were expensive for Cloud
Controller to compute and because they often returned more information than
clients actually needed. They were convenient, so it was easy for clients to
rely on them even when they only needed a few pieces of information.

In V3, to enable better API performance overall, these usage patterns are
deliberately disallowed. Instead, clients are encouraged to think more carefully
about which information they really need and to fetch that information with
multiple API calls and/or by making use of the [`include`
parameter](#including-associated-resources) on certain endpoints.

#### Usage summary endpoints

There are still a couple of endpoints in V3 that provide a basic summary of
instance and memory usage. See the [org summary](#get-usage-summary) and
[platform summary](#get-platform-usage-summary) endpoints.
