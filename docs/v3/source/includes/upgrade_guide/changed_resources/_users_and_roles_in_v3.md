### Users and Roles in V3

The user resource remains largely unchanged from the v2 API. On v2, `GET /v2/users` was restricted to admins, and other users needed to use nested endpoints (`GET /v2/organizations/:guid/user` and `GET /v2/spaces/:guid/user`) to view user resources. On v3, `GET /v3/users` is now available for all users, similar to other resources. Note that this does not change what user resources are visible.

In V2, roles were modeled as associations between organization and space endpoints. In V3, roles have a dedicated resource: `/v3/roles`. This has changed the manner in which roles are assigned. For example, in V2, to assign a user the `org_manager` role, one would `PUT /v2/organizations/:org_guid/managers/:user_id`. In V3, one would `POST /v3/roles` with the role type and relationships to the user and organization.

In the v2, when an Org Manager gives a person an Org or Space role, that person automatically receives Org User status in that org. This is no longer the case in the v3 API.

Read more about [users](#users) and [roles](#roles).
