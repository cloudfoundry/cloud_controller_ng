### Security Groups in V3

In V2, security groups which apply to _all_ spaces in a Cloud Foundry deployment are termed "default", as in "default for running apps" and "default for staging apps". For example, to apply a default security group to all apps in the running lifecycle, one would `PUT /v2/config/running_security_groups/:guid`

In V3, security groups which apply to _all_ spaces in a Cloud Foundry deployment are termed "global", as in "globally-enabled running apps" and "globally-enabled staging apps." For example, to apply a security group globally to all apps in the running lifecycle, one would `PATCH /v3/security_groups/:guid` with a body specifying the `globally_enabled` key. See [here](#update-a-security-group) for an example.

In V2, on creation, one can specify the spaces to which the security group applies, but not whether it applies globally (by default). To set the group globally to all spaces in the foundation one would `PUT /v2/config/running_security_groups/43e0441d-c9c1-4250-b8d5-7fb624379e02`.

In V3, on creation, one can both specify the spaces to which it applies and also whether it applies globally (to staging and/or running) by specifying the `globally_enabled` key. See [here](#create-a-security-group) for more information.

In V2, the endpoint to apply a security group to a space only includes the lifecycle ("running" or "staging") explicitly when applying to "staging" ("running" is the default lifecycle). For example, to unbind a security group from the running lifecycle, one would `DELETE /v2/security_groups/:guid/spaces/:space_guid`, from the staging lifecycle, `DELETE /v2/security_groups/:guid/staging_spaces/:space_guid`.

In V3, the endpoint to apply a security group to a space includes the lifecycle. For example to unbind a security group from the running lifecycle, one would `DELETE /v3/security_groups/:guid/relationships/running_spaces/:space_guid`.


