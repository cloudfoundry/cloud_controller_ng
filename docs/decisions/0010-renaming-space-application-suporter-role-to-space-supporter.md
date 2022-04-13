4: Adding key prefix to annotations
================================

Date: 2021-07-08

Status
------

Accepted


Context
-------
We have received pushback from the community that the name for the new SpaceApplicationSupporter role (proposed [here](https://docs.google.com/document/d/1qkd8e7PtT0yiS3Ud1on3hSc1TKmSmDmJOCqXGuZ9qi8/edi)) is confusing and does not line up with existing naming conventions. The role is designed to meet the needs of an app support engineer, however the role space developer is designed to meet the needs of an app developer but does not include the word app explicitly. Including the word app is confusing because it might imply to a consumer of API endpoints that this role can only access the `v3/apps` endpoints, however this user will have permissions across much more resources. Since this roles is still experimental and under active development we felt that now would be the time to change it to SpaceSupporter.

However, creating a migration to rename the table causes many cloud controller endpoints in the latest CAPI release to fail, because many permissions check will check any existing role tables to see if the current user has a role in the associated space. 


Decision
--------
1. Create a new table to store new space supporter roles
1. Create a [time bomb test](https://github.com/cloudfoundry/cloud_controller_ng/blob/b6ba5196722728a221034aadad076646f43f5de3/spec/support/deprecation_helpers.rb) to tell us to consider dropping the old table. This will give users enough time to upgrade to a release that includes both tables and the lates code before upgrading again to a release that includes the latest code and only the latest table name.

We **will not** attempt to migrate existing data into this new structure because in our current state the creation of this role is still blocked by a [flag](https://github.com/cloudfoundry/cloud_controller_ng/blob/5cce873a10cdf17fa2331efa9b6c298643360710/app/messages/role_create_message.rb#L16-L21), that is undocumented and hidden from users. Additionally, as we have been updating various endpoints to allow access to this role, we have been (documenting) that this role is unsupported and not ready for use. 

Consequences
------------

### Positive Consequences
* We will end up in a state where we are able to contain all of the data we need without extra cruft or data loss.


### Negative Consequences
* Users will have to have an empty and unnecessary table for at least one upgrade version
* Some users might not upgrade frequently enough and will experience some down time

