## Users

The user resource is used to manage access to organizations, spaces, and other
resources within Cloud Foundry. Cloud Controller is not the ultimate authority
on the users in the Cloud Foundry system; UAA and its configured identity
providers determine which users are able to sign in to Cloud Foundry.

To be functional, Cloud Controller users must "shadow" a corresponding user or
client in UAA. The Cloud Controller user resource's guid should match either a
UAA user or a UAA client id. However, Cloud Controller does not enforce that
a user's guid is a valid UAA user or client id.

Users can be assigned roles, which give them privileges to perform actions
within a given context. For example, the Space Developer role grants a user
permission to manage apps and services in a space (e.g. to push apps, scale
apps, delete apps).
